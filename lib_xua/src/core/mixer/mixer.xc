// Copyright 2011-2025 XMOS LIMITED.
// This Software is subject to the terms of the XMOS Public Licence: Version 1.
#define XASSERT_UNIT MIXER
#include "xassert.h"

#include <xs1.h>
#include "xua.h"
#include "xua_commands.h"
#include "dbcalc.h"

/* FAST_MIXER has a bit of a nasty implentation but is more efficient */
#ifndef FAST_MIXER
#define FAST_MIXER   (1)
#endif

#if defined (LEVEL_METER_HOST) || defined(LEVEL_METER_LEDS) || !FAST_MIXER
#include "xc_ptr.h"
#endif

#if (MIXER)

#if (OUT_VOLUME_IN_MIXER)
static unsigned int multOut_array[NUM_USB_CHAN_OUT + 1];
unsafe
{
    unsigned int volatile * unsafe multOut = multOut_array;
}
#endif

#if (IN_VOLUME_IN_MIXER)
static unsigned int multIn_array[NUM_USB_CHAN_IN + 1];
unsafe
{
    unsigned int volatile * unsafe multIn = multIn_array;
}
#endif

#if defined (LEVEL_METER_LEDS) || defined (LEVEL_METER_HOST)
static unsigned abs(int x)
{
#if 0
    if (x < 0)
        return x*-1;
    return x;
#else
    int const mask = x >> sizeof(int) * 8 - 1;
    return (x + mask) ^ mask;
#endif
}
#endif

static const int SOURCE_COUNT = NUM_USB_CHAN_OUT + NUM_USB_CHAN_IN + MAX_MIX_COUNT + 1;

static int samples_array[NUM_USB_CHAN_OUT + NUM_USB_CHAN_IN + MAX_MIX_COUNT + 1]; /* One larger for an "off" channel for mixer sources" */
static int samples_to_host_map_array[NUM_USB_CHAN_IN];
static int samples_to_device_map_array[NUM_USB_CHAN_OUT];

unsafe
{
    int volatile * const unsafe ptr_samples = samples_array;
    int volatile * const unsafe samples_to_host_map = samples_to_host_map_array;
    int volatile * const unsafe samples_to_device_map = samples_to_device_map_array;
}

#if (MAX_MIX_COUNT > 0)
int mix_mult_array[MAX_MIX_COUNT * MIX_INPUTS];
#if (FAST_MIXER == 0)
int mix_map_array[MAX_MIX_COUNT * MIX_INPUTS];
#endif

unsafe
{
    int volatile * const unsafe mix_mult = mix_mult_array;
#if (FAST_MIXER == 0)
    int volatile * const unsafe mix_map = mix_map_array;
#endif
}

#define slice(a, i) (a + i * MIX_INPUTS)

#endif

#if defined (LEVEL_METER_HOST) || defined(LEVEL_METER_LEDS)
/* Arrays for level data */
int samples_to_host_inputs[NUM_USB_CHAN_IN];            /* Audio transmitted to host i.e. device inputs */
xc_ptr samples_to_host_inputs_ptr;

#ifdef LEVEL_METER_LEDS
int samples_to_host_inputs_buff[NUM_USB_CHAN_IN];       /* Audio transmitted to host i.e. dev inputs */
xc_ptr samples_to_host_inputs_buff_ptr;
#endif
static int samples_from_host_streams[NUM_USB_CHAN_OUT]; /* Peak samples for audio stream from host */

static int samples_mixer_outputs[MAX_MIX_COUNT];        /* Peak samples out of the mixer */
xc_ptr samples_mixer_outputs_ptr;

static inline void ComputeMixerLevel(int sample, int i)
{
    int x;
    int y;
    xc_ptr ptr;

    x = abs(sample);

    /* y = samples_mixer_outputs[i] */
    read_via_xc_ptr_indexed(y, samples_mixer_outputs_ptr, i);

    if(x > y)
    {
        /* samples_to_host_outputs[i] = x; */
        write_via_xc_ptr_indexed(samples_mixer_outputs_ptr,i,x);
    }
}
#endif


#if (FAST_MIXER)
void setPtr(int src, int dst, int mix);
int doMix0(volatile int * const unsafe samples, volatile int * const unsafe mult);
int doMix1(volatile int * const unsafe samples, volatile int * const unsafe mult);
int doMix2(volatile int * const unsafe samples, volatile int * const unsafe mult);
int doMix3(volatile int * const unsafe samples, volatile int * const unsafe mult);
int doMix4(volatile int * const unsafe samples, volatile int * const unsafe mult);
int doMix5(volatile int * const unsafe samples, volatile int * const unsafe mult);
int doMix6(volatile int * const unsafe samples, volatile int * const unsafe mult);
int doMix7(volatile int * const unsafe samples, volatile int * const unsafe mult);
#else
#pragma unsafe arrays
static inline int doMix(volatile int * unsafe samples, volatile int * unsafe const mixMap, volatile int * const unsafe mult)
{
    int h=0;
    int l=0;

#pragma loop unroll
    for (int i=0; i<MIX_INPUTS; i++)
    unsafe{
        int sample;
        int source;
        int weight;
        read_via_xc_ptr_indexed(source, mixMap, i);
        sample = samples[source];
        read_via_xc_ptr_indexed(weight, mult, i);


        {h,l} = macs(sample, weight, h, l);
    }

    /* Perform saturation */
    l = sext(h, XUA_MIXER_MULT_FRAC_BITS);

    if(l != h)
    {
        if(h>>32)
            h = (0x80000000>>7);
        else
            h = (0x7fffff00>>7);
    }
    return h<<7;
}
#endif

#pragma unsafe arrays
static inline void GiveSamplesToHost(chanend c, volatile int * unsafe hostMap)
{
#if (IN_VOLUME_IN_MIXER && IN_VOLUME_AFTER_MIX)
    int mult;
    int h;
    unsigned l;
#endif

#pragma loop unroll
    for (int i=0; i<NUM_USB_CHAN_IN; i++)
    {
        int sample;

#if (MAX_MIX_COUNT > 0)
        unsafe
        {
            sample = ptr_samples[hostMap[i]];
        }
#else
        unsafe
        {
            sample = ptr_samples[i + NUM_USB_CHAN_OUT];
        }
#endif

#if (IN_VOLUME_IN_MIXER && IN_VOLUME_AFTER_MIX)
#warning IN Vols in mixer, AFTER mix & map

        unsafe
        {
            mult = multIn[i];
        }
        {h, l} = macs(mult, sample, 0, 0);

        //h <<= 3 done on other side */

        outuint(c, h);
#else
        outuint(c,sample);
#endif
    }
}

#pragma unsafe arrays
static inline void GetSamplesFromHost(chanend c)
{
#if (NUM_USB_CHAN_OUT == 0)
    inuint(c);
#else
    {
#pragma loop unroll
        for (int i=0; i<NUM_USB_CHAN_OUT; i++)
        unsafe {
            int sample, x;
#if (OUT_VOLUME_IN_MIXER && !OUT_VOLUME_AFTER_MIX)
            int mult;
            int h;
            unsigned l;
#endif
            /* Receive sample from decouple */
            sample = inuint(c);

#if defined (LEVEL_METER_HOST) || defined(LEVEL_METER_LEDS)
            /* Compute peak level data */
            x = abs(sample);
            if(x > samples_from_host_streams[i])
            {
                samples_from_host_streams[i] = x;
            }
#endif

#if (OUT_VOLUME_IN_MIXER && !OUT_VOLUME_AFTER_MIX)
#warning OUT Vols in mixer, BEFORE mix & map
            mult = multOut[i];
            {h, l} = macs(mult, sample, 0, 0);
            h<<=3;
#if (STREAM_FORMAT_OUTPUT_RESOLUTION_32BIT_USED == 1)
            h |= (l >>29)& 0x7; // Note: This step is not required if we assume sample depth is 24bit (rather than 32bit)
                                // Note: We need all 32bits for Native DSD
#endif
            sample = h;
#endif
            ptr_samples[i] = sample;
        }
    }
#endif
}

#pragma unsafe arrays
static inline void GiveSamplesToDevice(chanend c, volatile int * unsafe deviceMap)
{
#if (NUM_USB_CHAN_OUT == 0)
    outuint(c, 0);
#else
#pragma loop unroll
    for (int i=0; i<NUM_USB_CHAN_OUT; i++)
    {
        int sample, x;
#if (OUT_VOLUME_IN_MIXER && OUT_VOLUME_AFTER_MIX)
        int mult;
        int h;
        unsigned l;
#endif
        int index;

#if (MAX_MIX_COUNT > 0)
        /* If mixer turned on sort out the channel mapping */
        unsafe
        {
            /* Read index to sample from the map then Read the actual sample value */
            sample = ptr_samples[deviceMap[i]];
        }
#else
        unsafe
        {
            /* Read the actual sample value */
            sample = ptr_samples[i];
        }
#endif

#if (OUT_VOLUME_IN_MIXER && OUT_VOLUME_AFTER_MIX)
        /* Do volume control processing */
#warning OUT Vols in mixer, AFTER mix & map
        unsafe
        {
            mult = multOut[i];
        }

        {h, l} = macs(mult, sample, 0, 0);
        h<<=3;              // Shift used to be done in audio thread but now done here incase of 32bit support
#if (STREAM_FORMAT_OUTPUT_RESOLUTION_32BIT_USED == 1)
        h |= (l >>29)& 0x7; // Note: This step is not required if we assume sample depth is 24bit (rather than 32bit)
                            // Note: We need all 32bits for Native DSD
#endif
        outuint(c, h);
#else
        outuint(c, sample);
#endif
    }
#endif
}

#pragma unsafe arrays
static inline void GetSamplesFromDevice(chanend c)
{
#if (IN_VOLUME_IN_MIXER && IN_VOLUME_AFTER_MIX)
    int mult;
    int h;
    unsigned l;
#endif

#pragma loop unroll
    for (int i=0; i<NUM_USB_CHAN_IN; i++)
    {
        int sample;
        int x;
        int old_x;
        sample = inuint(c);

#if defined (LEVEL_METER_HOST) || defined(LEVEL_METER_LEDS)
        /* Compute peak level data */
        x = abs(sample);

        // old_x = samples_to_host_inputs[i]
        read_via_xc_ptr_indexed(old_x, samples_to_host_inputs_ptr, i);
        if(x > old_x)
        {
            //samples_to_host_inputs[i] = x;
            write_via_xc_ptr_indexed(samples_to_host_inputs_ptr, i, x);
        }
#endif

#if (IN_VOLUME_IN_MIXER && IN_VOLUME_AFTER_MIX)
        /* Volume processing - read relevant multiplier */
        unsafe
        {
            mult = multIn[i];
        }

        /* Do the multiply */
        {h, l} = macs(mult, sample, 0, 0);
        h <<= 3;
        sample = h;
#endif
        unsafe
        {
            assert((XUA_MIXER_OFFSET_IN + i) < (NUM_USB_CHAN_IN + NUM_USB_CHAN_OUT));
            ptr_samples[XUA_MIXER_OFFSET_IN + i] = sample;
        }
    }
}


#pragma unsafe arrays
static void mixer1(chanend c_host, chanend c_mix_ctl, chanend ?c_mixer2, chanend c_audio)
{
    int mixer1_mix2_flag = (DEFAULT_FREQ > 96000);
#if (MAX_MIX_COUNT > 0)
    int mixed;
#endif
#if (MAX_MIX_COUNT > 0) || (IN_VOLUME_IN_MIXER) || (OUT_VOLUME_IN_MIXER) || defined (LEVEL_METER_HOST) || defined(LEVEL_METER_LEDS)
    unsigned cmd;
    unsigned char ct;
#endif
    unsigned request = 0;

    while (1)
    {
        /* Request from audio()/mixer2() */
        request = inuint(c_audio);

        /* Forward on Request for data to decouple thread */
        outuint(c_host, request);

        /* Between request to decouple and response ~ 400nS latency for interrupt to fire */

#if (MAX_MIX_COUNT > 0) || (IN_VOLUME_IN_MIXER) || (OUT_VOLUME_IN_MIXER) || defined (LEVEL_METER_HOST) || defined(LEVEL_METER_LEDS)
        select
        {
            /* Check if EP0 intends to send us a control command */
            case inct_byref(c_mix_ctl, ct):
            {
                int mix, index, val;

                /* Handshake back to tell EP0 we are ready for an update */
                outct(c_mix_ctl, XS1_CT_END);

                /* Receive command from EP0 */
                cmd = inuint(c_mix_ctl);

                /* Interpret control command */
                switch (cmd)
                {
#if (MAX_MIX_COUNT > 0)
                    case SET_SAMPLES_TO_HOST_MAP:
                        {
                            int dst = inuint(c_mix_ctl);
                            int src = inuint(c_mix_ctl);
                            inct(c_mix_ctl);

                            assert((dst < NUM_USB_CHAN_IN) && msg("Host map destination out of range"));
                            assert((src < SOURCE_COUNT) && msg("Host map source out of range"));

                            if((dst < NUM_USB_CHAN_IN) && (src < SOURCE_COUNT))
                            {
                                unsafe
                                {
                                    samples_to_host_map[dst] = src;
                                }
                            }
                        }
                        break;

                    case SET_SAMPLES_TO_DEVICE_MAP:
                        {
                            int dst = inuint(c_mix_ctl);
                            int src = inuint(c_mix_ctl);
                            inct(c_mix_ctl);

                            assert((dst < NUM_USB_CHAN_OUT) && msg("Device map destination out of range"));
                            assert((src < SOURCE_COUNT) && msg("Device map source out of range"));

                            if((dst < NUM_USB_CHAN_OUT) && (src < SOURCE_COUNT))
                            {
                                unsafe
                                {
                                    samples_to_device_map[dst] = src;
                                }
                            }
                        }
                        break;

                    case SET_MIX_MULT:
                        mix = inuint(c_mix_ctl);
                        index = inuint(c_mix_ctl);
                        val = inuint(c_mix_ctl);
                        inct(c_mix_ctl);

                        assert((mix < MAX_MIX_COUNT) && msg("Mix mult mix out of range"));
                        assert((index < MIX_INPUTS) && msg("Mix mult index out of range"));

                        if((index < MIX_INPUTS) && (mix < MAX_MIX_COUNT))
                        {
                            unsafe
                            {
                                mix_mult[(mix * MIX_INPUTS) + index] = val;
                            }
                        }
                        break;

                    case SET_MIX_MAP:
                        {
                            unsigned mix = inuint(c_mix_ctl);
                            unsigned input = inuint(c_mix_ctl);     /* mixer input */
                            unsigned source = inuint(c_mix_ctl);    /* source */
                            inct(c_mix_ctl);

                            assert((mix < MAX_MIX_COUNT) && msg("Mix map mix out of range"));
                            assert((input < MIX_INPUTS) && msg("Mix map index out of range"));
                            assert((source < SOURCE_COUNT) && msg("Mix map source out of range"));

                            if((input < MIX_INPUTS) && (mix < MAX_MIX_COUNT) && (source < SOURCE_COUNT))
                            {
#if (FAST_MIXER)
                                setPtr(input, source, mix);
#else
                                unsafe
                                {
                                    mix_map[(mix * MIX_INPUTS) + input] = source;
                                }
#endif
                            }
                        }
                        break;
#endif /* if MAX_MIX_COUNT > 0 */

#if (IN_VOLUME_IN_MIXER)
                    case SET_MIX_IN_VOL:
                        index = inuint(c_mix_ctl);
                        val = inuint(c_mix_ctl);
                        inct(c_mix_ctl);

                        assert((index  < (NUM_USB_CHAN_IN + 1)) && msg("In volume index out of range"));

                        if(index < NUM_USB_CHAN_IN + 1)
                        {
                            unsafe
                            {
                                multIn[index] = val;
                            }
                        }
                        break;
#endif
#if (OUT_VOLUME_IN_MIXER)
                    case SET_MIX_OUT_VOL:
                        index = inuint(c_mix_ctl);
                        val = inuint(c_mix_ctl);
                        inct(c_mix_ctl);

                        assert((index  < (NUM_USB_CHAN_OUT + 1)) && msg("Out volume index out of range"));

                        if(index < NUM_USB_CHAN_OUT + 1)
                        {
                            unsafe
                            {
                                multOut[index] = val;
                            }
                        }
                        break;
#endif

#if defined (LEVEL_METER_HOST) || defined(LEVEL_METER_LEDS)
                    /* Peak samples of stream from host to device (via USB) */
                    case GET_STREAM_LEVELS:
                        index = inuint(c_mix_ctl);
                        chkct(c_mix_ctl, XS1_CT_END);
                        outuint(c_mix_ctl, samples_from_host_streams[index]);
                        outct(c_mix_ctl, XS1_CT_END);
                        samples_from_host_streams[index] = 0;
                        break;
#endif
                }
                break;
            }
            default:
                /* Select default */
                break;
        } // select
#endif

        /* Get response from decouple */
        if(testct(c_host))
        {
            int sampFreq;
            unsigned command = inct(c_host);

            switch(command)
            {
                case XUA_AUDCTL_SET_SAMPLE_FREQ:
                    sampFreq = inuint(c_host);
                    mixer1_mix2_flag = sampFreq > 96000;

                    /* Inform mixer2 (or audio()) about freq change */
                    outct(c_audio, command);
                    outuint(c_audio, sampFreq);
                    break;

                case XUA_AUD_SET_AUDIO_START:
                    /* Inform mixer2 (or audio()) about change */
                    outct(c_audio, command);
                    outuint(c_audio, inuint(c_host));
                    outuint(c_audio, inuint(c_host));
                    break;

                case XUA_AUD_SET_AUDIO_STOP:
                    /* Pass on command */
                    outct(c_audio, command);
                    break;
                    
                default:
                    break;
            }

#pragma loop unroll
            /* Reset the mix values back to 0 */
            for (int i=0; i<MAX_MIX_COUNT; i++)
            {
                unsafe
                {
                    ptr_samples[NUM_USB_CHAN_OUT + NUM_USB_CHAN_IN + i] = 0;
                }
            }

            /* Wait for handshake and pass on */
            chkct(c_audio, XS1_CT_END);
            outct(c_host, XS1_CT_END);
        }
        else
        {
#if (MAX_MIX_COUNT > 0)
            inuint(c_mixer2); // This is where we need mixer 2 to have finished
#endif
            GiveSamplesToDevice(c_audio, samples_to_device_map);
            GetSamplesFromDevice(c_audio);
            GetSamplesFromHost(c_host);
            GiveSamplesToHost(c_host, samples_to_host_map);

#if (MAX_MIX_COUNT > 0)
            /* Trigger mixer2 */
            outuint(c_mixer2, mixer1_mix2_flag);

            /* Do the mixing */
            unsafe
            {
#if (FAST_MIXER)
                mixed = doMix0(ptr_samples, slice(mix_mult, 0));
#else
                mixed = doMix(ptr_samples, slice(mix_map, 0), slice(mix_mult, 0));
#endif
                ptr_samples[NUM_USB_CHAN_OUT + NUM_USB_CHAN_IN + 0] = mixed;
            }
#if defined (LEVEL_METER_HOST) || defined(LEVEL_METER_LEDS)
            ComputeMixerLevel(mixed, 0);
#endif
#if (MAX_FREQ > 96000)
            if (!mixer1_mix2_flag)
#endif
            {

#if (MAX_MIX_COUNT > 2)
                unsafe
                {
#if (FAST_MIXER)
                    mixed = doMix2(ptr_samples, slice(mix_mult, 2));
#else
                    mixed = doMix(ptr_samples, slice(mix_map, 2), slice(mix_mult, 2));
#endif
                    ptr_samples[NUM_USB_CHAN_OUT + NUM_USB_CHAN_IN + 2] = mixed;
                }
#if defined (LEVEL_METER_HOST) || defined(LEVEL_METER_LEDS)
                ComputeMixerLevel(mixed, 2);
#endif
#endif

#if (MAX_MIX_COUNT > 4)
                unsafe
                {
#if (FAST_MIXER)
                    mixed = doMix4(ptr_samples, slice(mix_mult, 4));
#else
                    mixed = doMix(ptr_samples, slice(mix_map, 4), slice(mix_mult, 4));
#endif
                    ptr_samples[XUA_MIXER_OFFSET_MIX + 4] = mixed;
                }
#if defined (LEVEL_METER_HOST) || defined(LEVEL_METER_LEDS)
                ComputeMixerLevel(mixed, 4);
#endif
#endif

#if (MAX_MIX_COUNT > 6)
                unsafe
                {
#if (FAST_MIXER)
                    mixed = doMix6(ptr_samples, slice(mix_mult, 6));
#else
                    mixed = doMix(ptr_samples, slice(mix_map, 6), slice(mix_mult, 6));
#endif
                    ptr_samples[XUA_MIXER_OFFSET_MIX + 6] = mixed;
                }
#if defined (LEVEL_METER_HOST) || defined(LEVEL_METER_LEDS)
                ComputeMixerLevel(mixed, 6);
#endif
#endif
            }
#endif
        }
    }
}

#if (MAX_MIX_COUNT > 0)
#pragma unsafe arrays
static void mixer2(chanend c_mixer1)
{
    int mixed;
    outuint(c_mixer1, 0); // To get mixer1 started
    int mixer2_mix2_flag;
    while (1)
    {
        mixer2_mix2_flag = inuint(c_mixer1);

        /* Do the mixing */
#if (MAX_MIX_COUNT > 1)
        unsafe
        {
#if (FAST_MIXER)
            mixed = doMix1(ptr_samples, slice(mix_mult, 1));
#else
            mixed = doMix(ptr_samples, slice(mix_map, 1), slice(mix_mult, 1));
#endif
            ptr_samples[NUM_USB_CHAN_OUT + NUM_USB_CHAN_IN + 1] = mixed;
        }
#if defined (LEVEL_METER_HOST) || defined(LEVEL_METER_LEDS)
        ComputeMixerLevel(mixed, 1);
#endif
#endif

#if (MAX_FREQ > 96000)
        /* Fewer mixes when running higher than 96kHz */
        if (!mixer2_mix2_flag)
#endif
        {
#if (MAX_MIX_COUNT > 3)
            unsafe
            {
#if (FAST_MIXER)
                mixed = doMix3(ptr_samples, slice(mix_mult, 3));
#else
                mixed = doMix(ptr_samples, slice(mix_map, 3), slice(mix_mult, 3));
#endif
                ptr_samples[NUM_USB_CHAN_OUT + NUM_USB_CHAN_IN + 3] = mixed;
            }
#if defined (LEVEL_METER_HOST) || defined(LEVEL_METER_LEDS)
            ComputeMixerLevel(mixed, 3);
#endif
#endif

#if (MAX_MIX_COUNT > 5)
            unsafe
            {
#if (FAST_MIXER)
                mixed = doMix5(ptr_samples, slice(mix_mult, 5));
#else
                mixed = doMix(ptr_samples, slice(mix_map, 5), slice(mix_mult, 5));
#endif
                ptr_samples[NUM_USB_CHAN_OUT + NUM_USB_CHAN_IN + 5] = mixed;

            }
#if defined (LEVEL_METER_HOST) || defined(LEVEL_METER_LEDS)
            ComputeMixerLevel(mixed, 5);
#endif
#endif

#if (MAX_MIX_COUNT > 7)
            unsafe
            {
#if (FAST_MIXER)
                mixed = doMix7(ptr_samples, slice(mix_mult, 7));
#else
                mixed = doMix(ptr_samples, slice(mix_map, 7), slice(mix_mult, 7));
#endif
                ptr_samples[NUM_USB_CHAN_OUT + NUM_USB_CHAN_IN + 7] = mixed;
            }
#if defined (LEVEL_METER_HOST) || defined(LEVEL_METER_LEDS)
            ComputeMixerLevel(mixed, 7);
#endif
#endif
        }
        outuint(c_mixer1, 0);
    }
}
#endif

void mixer(chanend c_mix_in, chanend c_mix_out, chanend c_mix_ctl)
{
#if (MAX_MIX_COUNT > 0)
    chan c;
#endif

#if defined (LEVEL_METER_HOST) || defined(LEVEL_METER_LEDS)
    samples_to_host_inputs_ptr = array_to_xc_ptr((samples_to_host_inputs, unsigned[]));
#ifdef LEVEL_METER_LEDS
    samples_to_host_inputs_buff_ptr = array_to_xc_ptr((samples_to_host_inputs, unsigned[]));
#endif
    samples_mixer_outputs_ptr = array_to_xc_ptr((samples_mixer_outputs, unsigned[]));
#endif

    for (int i=0;i<NUM_USB_CHAN_OUT + NUM_USB_CHAN_IN + MAX_MIX_COUNT;i++)
    unsafe {
        ptr_samples[i] = 0;
    }

    for (int i=0; i<NUM_USB_CHAN_OUT; i++)
    {
        samples_to_device_map_array[i] = i;
    }

#if (OUT_VOLUME_IN_MIXER)
    for (int i=0; i<NUM_USB_CHAN_OUT; i++)
    unsafe{
        multOut[i] = MAX_VOLUME_MULT;
    }
#endif

#if (IN_VOLUME_IN_MIXER)
    for (int i=0; i<NUM_USB_CHAN_IN; i++)
    unsafe{
        multIn[i] = MAX_VOLUME_MULT;
    }
#endif

    for (int i=0; i<NUM_USB_CHAN_IN; i++)
    unsafe{
        samples_to_host_map[i] = XUA_MIXER_OFFSET_IN + i;
    }

#if (MAX_MIX_COUNT> 0)
    for (int i=0;i<MAX_MIX_COUNT;i++)
        for (int j=0;j<MIX_INPUTS;j++)
        unsafe{
#if (FAST_MIXER == 0)
            mix_map[i * MIX_INPUTS + j] = (j < 16 ? j : j + 2);
#endif
            mix_mult[i * MIX_INPUTS + j] = (i==j ? db_to_mult(0, XUA_MIXER_DB_FRAC_BITS, XUA_MIXER_MULT_FRAC_BITS) : 0);
        }
#endif

    par
    {
#if (MAX_MIX_COUNT > 0)
        mixer1(c_mix_in, c_mix_ctl, c, c_mix_out);
        mixer2(c);
#else
        mixer1(c_mix_in, c_mix_ctl, null, c_mix_out);
#endif
    }
}

#endif
