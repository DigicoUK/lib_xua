// Copyright 2016-2025 XMOS LIMITED.
// This Software is subject to the terms of the XMOS Public Licence: Version 1.
#ifndef _XUA_CONF_H_
#define _XUA_CONF_H_

#define NUM_USB_CHAN_OUT        (0)
#define NUM_USB_CHAN_IN         (2)
#define I2S_CHANS_DAC           (0)
#define I2S_CHANS_ADC           (2)

#define EXCLUDE_USB_AUDIO_MAIN  (1)

#define MIXER                   (0)
#define MAX_MIX_COUNT           (0)

#define UAC_FORCE_FEEDBACK_EP   (0)
#define XUA_NUM_PDM_MICS        (0)

#define AUDIO_IO_TILE           (0)

/* Required so that full 32bit result of volume control is used - otherwise breaks our test ramps */
#define HS_STREAM_FORMAT_INPUT_1_RESOLUTION_BITS 32

#ifndef MCLK_441
#define MCLK_441                (512 * 44100)
#endif

#ifndef MCLK_48
#define MCLK_48                 (512 * 48000)
#endif

#define MIN_FREQ                (44100)
#define MAX_FREQ                (192000)

#ifndef DEFAULT_FREQ
#error DEFAULT_FREQ not defined
//#define DEFAULT_FREQ            (48000)
#endif

#define SPDIF_TX_INDEX          (0)
#define VENDOR_STR              "XMOS"
#define VENDOR_ID               (0x20B1)
#define PRODUCT_STR_A2          "Test device"
#define PRODUCT_STR_A1          "Test device"
#define PID_AUDIO_1             (1)
#define PID_AUDIO_2             (2)
#define AUDIO_CLASS             (2)
#define AUDIO_CLASS_FALLBACK    (0)
#define BCD_DEVICE              (0x1234)
#define XUA_DFU_EN              (0)
#define MIC_DUAL_ENABLED        (1)        //Use single thread, dual PDM mic
#define XUA_MIC_FRAME_SIZE      (240)

#endif
