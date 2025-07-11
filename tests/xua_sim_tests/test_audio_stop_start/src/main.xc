// Copyright 2016-2025 XMOS LIMITED.
// This Software is subject to the terms of the XMOS Public Licence: Version 1.
#include <platform.h>
#include <stdlib.h>
#include <print.h>
#include <timer.h>
#include "xua.h"
#include "xua_commands.h" // Internal header, not part of lib_xua user API

#define TOTAL_TEST_FRAMES 100

#define DEBUG_UNIT MAIN
#include "debug_print.h"

#if NO_STREAMS
#define DAC_PORT
#define ADC_PORT
#else
#define DAC_PORT  XS1_PORT_1A
#define ADC_PORT  XS1_PORT_1B
#endif

on tile[AUDIO_IO_TILE] : buffered out port:32 p_i2s_dac[I2S_WIRES_DAC] =  {DAC_PORT};
on tile[AUDIO_IO_TILE] : buffered in port:32 p_i2s_adc[I2S_WIRES_ADC] =   {ADC_PORT};


on tile[AUDIO_IO_TILE] : buffered out port:32 p_lrclk        = XS1_PORT_1C;    /* I2S Bit-clock */
on tile[AUDIO_IO_TILE] : buffered out port:32 p_bclk         = XS1_PORT_1E;     /* I2S L/R-clock */
on tile[AUDIO_IO_TILE] : in port p_mclk_in                   = XS1_PORT_1D;

/* Clock-block declarations */
clock clk_audio_bclk                = on tile[AUDIO_IO_TILE]: XS1_CLKBLK_1;   /* Bit clock */
clock clk_audio_mclk                = on tile[AUDIO_IO_TILE]: XS1_CLKBLK_2;   /* Master clock */


#ifdef SIMULATION
out port p_mclk_gen       = on tile[AUDIO_IO_TILE] : XS1_PORT_1M;
clock clk_audio_mclk_gen  = on tile[AUDIO_IO_TILE] : XS1_CLKBLK_3;
void master_mode_clk_setup(void);
#endif

const int i2s_tdm_mode = 2;


void send_audio_frames(chanend c_out, unsigned num_frames)
{
  unsigned frame_count = 0;
  int underflow_word;
  int i;

  while (1) {
    underflow_word = inuint(c_out);
    const int num_outs = NUM_USB_CHAN_OUT == 0 ? 1 : NUM_USB_CHAN_OUT;
    for (i = 0; i < num_outs; i++) {
      outuint(c_out, frame_count);
    }
    for (i = 0; i < NUM_USB_CHAN_IN; i++) {
      inuint(c_out);
    }
    if (frame_count == num_frames) {
      return;
    }

    printf("Frame %d\n", frame_count);
    frame_count++;
  }
}


void send_cmd(chanend c_out, unsigned cmd, unsigned val)
{
    inuint(c_out); // get and discard underflow word
    outct(c_out, cmd);
    switch(cmd)
    {
      case XUA_AUDCTL_SET_SAMPLE_FREQ:
        printstr("sent XUA_AUDCTL_SET_SAMPLE_FREQ "); printintln(val);
        outuint(c_out, val); // note 0x12345678 for DFU
        break;
      case XUA_AUD_SET_AUDIO_START:
        outuint(c_out, 0);
        outuint(c_out, val);
        printstr("sent XUA_AUD_SET_AUDIO_START\n");
        break;
      case XUA_AUD_SET_AUDIO_STOP:
        printstr("sent XUA_AUD_SET_AUDIO_STOP\n");
        break;
      default:
        printstr("ERROR - incorrect command in send\n");
        break;
    }
    chkct(c_out, XS1_CT_END);
}

void send_cmd_no_audio(chanend c_out, unsigned cmd, unsigned val)
{
    outct(c_out, cmd);
    switch(cmd)
    {
      case XUA_AUDCTL_SET_SAMPLE_FREQ:
        printstr("sent XUA_AUDCTL_SET_SAMPLE_FREQ "); printintln(val);
        outuint(c_out, val); // note 0x12345678 for DFU
        break;
      case XUA_AUD_SET_AUDIO_START:
        outuint(c_out, 0);
        outuint(c_out, val);
        printstr("sent XUA_AUD_SET_AUDIO_START\n");
        break;
      case XUA_AUD_SET_AUDIO_STOP:
        printstr("sent XUA_AUD_SET_AUDIO_STOP\n");
        break;
      default:
        printstr("ERROR - incorrect command in send\n");
        break;
    }
    chkct(c_out, XS1_CT_END);
}

void generator(chanend c_out)
{
#if NO_STREAMS
  send_cmd_no_audio(c_out, XUA_AUDCTL_SET_SAMPLE_FREQ, AUDIO_STOP_FOR_DFU); // We will now be in dummy deliver
  send_cmd_no_audio(c_out, XUA_AUDCTL_SET_SAMPLE_FREQ, 44100); // send second SR change to make sure it can ignore it 
  send_cmd_no_audio(c_out, XUA_AUD_SET_AUDIO_START, 24); // Send stream start to see if we ignore it
  send_cmd_no_audio(c_out, XUA_AUD_SET_AUDIO_STOP, 0); // More to ignore
#else
  send_audio_frames(c_out, 1); // Just send one frame to check we can do it in dummy_deliver
  send_cmd(c_out, XUA_AUD_SET_AUDIO_START, 16); // Exit idle mode - I2S now looping again, expect to see Init and Config
  send_audio_frames(c_out, 5); // First test normal streaming sample exchnge and SR change
  send_cmd(c_out, XUA_AUDCTL_SET_SAMPLE_FREQ, 96000);
  send_audio_frames(c_out, 5);
  send_cmd(c_out, XUA_AUD_SET_AUDIO_STOP, 0); // Now go to back to idle mode
  send_audio_frames(c_out, 1); // Just send one frame to check we can do it - looping of dummy_deliver is much slower
  send_cmd(c_out, XUA_AUDCTL_SET_SAMPLE_FREQ, 48000); // Check SR change works in idle mode - new value of 48000 should be set when we startup
  send_audio_frames(c_out, 1);
  send_cmd(c_out, XUA_AUD_SET_AUDIO_START, 24); // Exit idle mode - I2S now looping again, expect to see Init and Config
  send_audio_frames(c_out, 5);
  send_cmd(c_out, XUA_AUD_SET_AUDIO_STOP, 0); // Now go to idle mode again
  send_audio_frames(c_out, 1);
  send_cmd(c_out, XUA_AUDCTL_SET_SAMPLE_FREQ, AUDIO_STOP_FOR_DFU); // make sure we can enter DFU from idle
  send_audio_frames(c_out, 5);
  send_cmd(c_out, XUA_AUDCTL_SET_SAMPLE_FREQ, 44100); // send second SR change to make sure it can ignore it 
  send_audio_frames(c_out, 5);
  send_cmd(c_out, XUA_AUD_SET_AUDIO_STOP, 0); // Ignore this too
  send_cmd(c_out, XUA_AUD_SET_AUDIO_START, 0); // Ignore this too
#endif
  _Exit(0);
}

int main(void)
{
    chan c_out;

    par
    {
        on tile[AUDIO_IO_TILE]:
        {
            par
            {
                XUA_AudioHub(c_out, clk_audio_mclk, clk_audio_bclk, p_mclk_in, p_lrclk, p_bclk, p_i2s_dac, p_i2s_adc);
                generator(c_out);
#ifdef SIMULATION
                master_mode_clk_setup();
#endif
            }
        }
    }

    return 0;
}
