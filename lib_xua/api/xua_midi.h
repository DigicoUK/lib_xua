// Copyright 2011-2025 XMOS LIMITED.
// This Software is subject to the terms of the XMOS Public Licence: Version 1.
#ifndef _XUA_MIDI_H_
#define _XUA_MIDI_H_

#include "xua.h"

#ifndef MIDI_SHIFT_TX
#define MIDI_SHIFT_TX      (0)
#endif

/** USB MIDI I/O task.
 *
 *  This function passes MIDI data between XUA_Buffer and MIDI UART I/O.
 *
 *  \param p_midi_in    1-bit input port for MIDI
 *  \param p_midi_out   1-bit output port for MIDI
 *  \param clk_midi     Clock block used for clockin the UART; should have
 *                      a rate of 100MHz
 *  \param c_midi       Chanend connected to the decouple() thread
 *  \param cable_number The cable number of the MIDI implementation.
 *                      This should be set to 0.
 **/
void usb_midi(
#if (MIDI_RX_PORT_WIDTH == 4)
    NULLABLE_RESOURCE(in_buffered_port_4_t, p_midi_in),
#else
    NULLABLE_RESOURCE(in_buffered_port_1_t, p_midi_in),
#endif
    NULLABLE_RESOURCE(port, p_midi_out),
    NULLABLE_RESOURCE(clock, clk_midi),
    NULLABLE_RESOURCE(chanend, c_midi),
    unsigned cable_number
);

#define MAX_USB_MIDI_PACKET_SIZE 1024
#define MIDI_USB_BUFFER_FROM_HOST_FIFO_SIZE (512+1024)
#define MIDI_USB_BUFFER_TO_HOST_SIZE (256)
#define MIDI_ACK 20
#define USB_MIDI_DEVICE_OUT_FIFO_SIZE (1024)

#ifdef __MIDI_IMPL
#define INLINE
#else
#define INLINE inline
#endif

#ifdef NO_INLINE_MIDI_SELECT_HANDLER
#pragma select handler
void midi_get_ack_or_data(chanend c, int &is_ack, unsigned int &datum);
#else
#pragma select handler
INLINE void midi_get_ack_or_data(chanend c, int &is_ack, unsigned int &datum) {
  if (testct(c)) {
    is_ack = 1;
    chkct(c, XS1_CT_END);
  }
  else {
    is_ack = 0;
    datum = inuint(c);
    chkct(c, XS1_CT_END);
  }
}
#endif

INLINE void midi_send_ack(chanend c) {
  outct(c, XS1_CT_END);
}

INLINE void midi_send_data(chanend c, unsigned int datum) {
  outuint(c, datum);
  outct(c, XS1_CT_END);
}

#define MIDI_RATE           (31250)
#define MIDI_BITTIME        (XS1_TIMER_MHZ * 1000000 / MIDI_RATE)
#define MIDI_BITTIME_2      (MIDI_BITTIME>>1)
#endif // _XUA_MIDI_H_
