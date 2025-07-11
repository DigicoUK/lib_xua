// Copyright 2011-2025 XMOS LIMITED.
// This Software is subject to the terms of the XMOS Public Licence: Version 1.

#ifndef _XUA_ENDPOINT0_H_
#define _XUA_ENDPOINT0_H_

#include "dfu_interface.h"
#include "vendorrequests.h"
#include "xccompat.h"

#if defined(__XC__) || defined (__DOXYGEN__)

/** Endpoint 0 task for USB Audio devices
 *
 *  Function implementing Endpoint 0 for enumeration, control and configuration
 *  of USB audio devices. It uses the descriptors defined in ``xua_ep0_descriptors.h``.
 *
 *  \param c_ep0_out    Chanend connected to the XUD_Main() out endpoint array
 *  \param c_ep0_in     Chanend connected to the XUD_Main() in endpoint array
 *  \param c_aud_ctl    Chanend connected to the decouple thread for control
 *                      audio (sample rate changes etc.). Note when nulled, the
 *                      audio device only supports single sample rate/format and
 *                      DFU is not supported either since this channel is used
 *                      to carry messages about format, rate and DFU state
 *  \param c_mix_ctl    Optional chanend to be connected to the mixer core(s) if
 *                      present
 *  \param c_clk_ctl    Optional chanend to be connected to the clockgen core if
 *                      present
 *  \param dfuInterface Interface to DFU task (this task must be run on a tile
 *                      connected to boot flash.
 */
void XUA_Endpoint0(chanend c_ep0_out,
                    chanend c_ep0_in
                    , NULLABLE_RESOURCE(chanend, c_aud_ctl)
                    , NULLABLE_RESOURCE(chanend, c_mix_ctl)
                    , NULLABLE_RESOURCE(chanend, c_clk_ctl)
                    , NULLABLE_CLIENT_INTERFACE(i_dfu, dfuInterface)
#if !defined(__DOXYGEN__)
                    VENDOR_REQUESTS_PARAMS_DEC_
#endif
);

/** Function to set the Vendor ID value
 *
 *  \param vid vendor ID value to set
*/
void XUA_Endpoint0_setVendorId(unsigned short vid);

/** Function to set the Product ID value
 *
 *  \param pid Product ID value to set
*/
void XUA_Endpoint0_setProductId(unsigned short pid);


/** Function to set the Vendor string
 *
 *  \param vendor_str Vendor string to set
*/
#ifdef __XC__
void XUA_Endpoint0_setVendorStr(char * unsafe vendor_str);
#else
void XUA_Endpoint0_setVendorStr(char * vendor_str);
#endif

/** Function to set the Product string
 *
 *  \param product_str Product string to set
*/

#ifdef __XC__
void XUA_Endpoint0_setProductStr(char * unsafe product_str);
#else
void XUA_Endpoint0_setProductStr(char * product_str);
#endif

/** Function to set the Serial string
 *
 *  \param serial_str Serial string to set
*/
#ifdef __XC__
void XUA_Endpoint0_setSerialStr(char * unsafe serial_str);
#else
void XUA_Endpoint0_setSerialStr(char * serial_str);
#endif

/** Function to set the BCD device
 *
 *  \param bcdDevice BCD device to set

*/

void XUA_Endpoint0_setBcdDevice(unsigned short bcdDevice);

/** Function to get the Vendor string
 *
 *  \return vendor string
*/
#ifdef __XC__
char * unsafe XUA_Endpoint0_getVendorStr();
#else
char *  XUA_Endpoint0_getVendorStr();
#endif

/** Function to get the Product string
 *
 *  \return Product string
*/
#ifdef __XC__
char * unsafe XUA_Endpoint0_getProductStr();
#else
char *  XUA_Endpoint0_getProductStr();
#endif

/** Function to get the Serial Number string
 *
 *  \return Serial string
*/
#ifdef __XC__
char * unsafe XUA_Endpoint0_getSerialStr();
#else
char *  XUA_Endpoint0_getSerialStr();
#endif

/** Function to get the Vendor ID
 *
 *  \return Vendor ID
*/
unsigned short XUA_Endpoint0_getVendorId();

/** Function to get the Product ID
 *
 *  \return Product ID
*/
unsigned short XUA_Endpoint0_getProductId();

/** Function to get the BCD device
 *
 *  \return BCD device
*/
unsigned short XUA_Endpoint0_getBcdDevice();

#endif
#endif
