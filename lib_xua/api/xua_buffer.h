// Copyright 2011-2021 XMOS LIMITED.
// This Software is subject to the terms of the XMOS Public Licence: Version 1.
#ifndef __XUA_BUFFER_H__
#define __XUA_BUFFER_H__

#if __XC__

#include "xua.h"

/** USB Audio Buffering Core.
 *
 *  This function buffers USB audio data between the XUD layer and the decouple
 *  thread. Most of the chanend parameters to the function should be connected to
 *  XUD_Manager()
 *
 *  \param c_aud_out Audio OUT endpoint channel connected to the XUD
 *  \param c_aud_in  Audio IN endpoint channel connected to the XUD
 *  \param c_aud_fb  Audio feedback endpoint channel connected to the XUD
 *  \param c_midi_from_host  MIDI OUT endpoint channel connected to the XUD
 *  \param c_midi_to_host  MIDI IN endpoint channel connected to the XUD
 *  \param c_int  Audio clocking interrupt endpoint channel connected to the XUD
 *  \param c_clk_int Optional chanend connected to the clockGen() thread if present
 *  \param c_sof  Start of frame channel connected to the XUD
 *  \param c_aud_ctl Audio control channel connected to  Endpoint0()
 *  \param p_off_mclk A port that is clocked of the MCLK input (not the MCLK input itself)
 */

void XUA_Buffer(
            chanend c_aud_out,
#if (NUM_USB_CHAN_IN > 0)
            chanend c_aud_in,
#endif
#if (NUM_USB_CHAN_IN == 0) || defined (UAC_FORCE_FEEDBACK_EP)
            chanend c_aud_fb,
#endif
#ifdef MIDI
            chanend c_midi_from_host,
            chanend c_midi_to_host,
			chanend c_midi,
#endif
#ifdef IAP
            chanend c_iap_from_host,
            chanend c_iap_to_host,
#ifdef IAP_INT_EP
            chanend c_iap_to_host_int,
#endif
            chanend c_iap,
#ifdef IAP_EA_NATIVE_TRANS
            chanend c_iap_ea_native_out,
            chanend c_iap_ea_native_in,
            chanend c_iap_ea_native_ctrl,
            chanend c_iap_ea_native_data,
#endif
#endif
#if (SPDIF_RX) || (ADAT_RX)
            chanend ?c_int,
            chanend ?c_clk_int,
#endif
            chanend c_sof,
            chanend c_aud_ctl,
            in port p_off_mclk
#if( 0 < HID_CONTROLS )
            , chanend c_hid
#endif
            , chanend c_aud
        );

void XUA_Buffer_Ep(chanend c_aud_out,
#if (NUM_USB_CHAN_IN > 0)
            chanend c_aud_in,
#endif
#if (NUM_USB_CHAN_IN == 0) || defined (UAC_FORCE_FEEDBACK_EP)
            chanend c_aud_fb,
#endif
#ifdef MIDI
            chanend c_midi_from_host,
            chanend c_midi_to_host,
			chanend c_midi,
#endif
#ifdef IAP
            chanend c_iap_from_host,
            chanend c_iap_to_host,
#ifdef IAP_INT_EP
            chanend c_iap_to_host_int,
#endif
            chanend c_iap,
#ifdef IAP_EA_NATIVE_TRANS
            chanend c_iap_ea_native_out,
            chanend c_iap_ea_native_in,
            chanend c_iap_ea_native_ctrl,
            chanend c_iap_ea_native_data,
#endif
#endif
#if (SPDIF_RX) || (ADAT_RX)
            chanend ?c_int,
            chanend ?c_clk_int,
#endif
            chanend c_sof,
            chanend c_aud_ctl,
            in port p_off_mclk
#if( 0 < HID_CONTROLS )
            , chanend c_hid
#endif
#ifdef CHAN_BUFF_CTRL
            , chanend c_buff_ctrl
#endif
        );

/** Manage the data transfer between the USB audio buffer and the
 *  Audio I/O driver.
 *
 * \param c_audio_out Channel connected to the audio() or mixer() threads
 */
void XUA_Buffer_Decouple(chanend c_audio_out
#ifdef CHAN_BUFF_CTRL
     , chanend c_buff_ctrl
#endif
);

#endif

#endif
