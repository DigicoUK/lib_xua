#########################################
AN00247: Using lib_xua with lib_mic_array
#########################################

********
Overview
********

The XMOS USB Audio (XUA) library provides an implementation of USB Audio Class versions 1.0 and 2.0.

This application note demonstrates the implementation of a basic USB Audio Device with
record functionality from PDM microphones on the `XK-EVK-XU316 <https://www.xmos.com/xk-evk-xu316>`_ board.

Core PDM microphone functionality is contained in ``lib_mic_array``. This library includes both the physical
interfacing to the PDM microphones as well as efficient decimation to user configurable output
sample rates - essentially providing PDM to PCM conversion.

I2S is also enabled as an output and the on board DAC is configured to play out the mic signals.

Readers are encouraged to read application note AN00246 in conjunction with this application note.

**********************************
lib_xua with lib_mic_array example
**********************************

The CMakeLists.txt file
=======================

To start you need to add ``lib_xua`` to the dependent module list in the CMakeLists.txt
file as well as ``lib_board_support`` which contains code to setup the audio hardware::

  set(APP_DEPENDENT_MODULES "lib_xua",
                            "lib_board_support(1.1.1))

The dependencies for this example are specified by ``deps.cmake`` in the ``examples`` directory
and are included in the application ``CMakeLists.txt`` file.

The ``lib_xud`` library requires some flags for correct operation. Namely the
tile on which ``lib_xud`` will be executed. In addition ``lib_board_support`` needs to be told which
board is being used. For example::

  set(APP_COMPILER_FLAGS = .. -DUSB_TILE=tile[0]
                              -DBOARD_SUPPORT_BOARD=XK_EVK_XU316
                              ..)


Declarations
============

Allocating hardware resources for lib_xua
-----------------------------------------

This implementation of a USB Audio device using ``lib_xua`` requires the following I/O pins:

    - Audio Master clock (generated by the xCORE)
    - Bit clock (generated by the xCORE)
    - Word clock (generated by the xCORE)
    - I2S data output pin (generated by the xCORE)


On an xcore the pins are controlled by ``ports``. The main application therefore declares a
port for the master clock input signal.
The ``main()`` function that is provided within `lib_xua <https://github.com/xmos/lib_xua/blob/develop/lib_xua/src/core/main.xc>`_ itself
has these ports defined. Look for ``p_i2s_dac``, ``p_lrclk``, ``p_bclk`` and ``p_mclk_in`` in
`lib_xua main.xc <https://github.com/xmos/lib_xua/blob/develop/lib_xua/src/core/main.xc>`_


``lib_xua`` also requires two ports for internally calculating USB feedback. Please refer to
the ``lib_xua`` library documentation for further details.  In this example ``XUA_Buffer()`` and ``XUA_AudioHub()``
reside on the same tile and can therefore make use of the same master-clock port.
These are defined as ``p_for_mclk_count`` and ``p_mclk_in_usb`` in the ``main()`` function in `lib_xua`.

In addition to ``port`` resources, some clock-block resources (``clk_audio_bclk``, ``clk_audio_mclk`` and ``clk_audio_mclk_usb``),
also defined in the ``main()`` function in `lib_xua`, are required.


Allocating hardware resources for lib_mic_array
-----------------------------------------------

In this example ``lib_mic_array`` requires a single 1-bit port for PDM data from two microphones. Each microphone is configured
to produce a PDM sample on an opposite clock edge from the other. This means the the data is effectively double
data rate (DDR) with respect to the PDM clock.

The microphones must be clocked by a clock synchronous to the audio application clock - typically 3.072MHz for 16, 32 or 48 kHz.

These ports, along with other ``mic_array`` required resources must be declared in ``xua_conf.h``:

.. literalinclude:: ../../src/xua_conf.h
   :start-at: #define XUA_NUM_PDM_MICS
   :end-at: #define MIC_ARRAY_CONFIG_CLOCK_BLOCK_B


The ``XK-EVK-XU316`` Board expects the xCORE to divide down the audio master clock (24.576MHz)
and output the result to the microphones. This is done internally by ``lib_mic_array`` from the definitions
``MIC_ARRAY_CONFIG_MCLK_FREQ`` and ``MIC_ARRAY_CONFIG_PDM_FREQ`` which are left as defaults in ``mic_array_conf.h`` to
generate the nominal 3.072 MHz PDM clock.

Please see the ``lib_mic_array`` library documentation for full details.


Configuring lib_xua
===================

``lib_xua`` must be configured to enable support for PDM microphones.

``lib_xua`` has many parameters than can be configured at build time, some examples include:

    - Supported sample-rates

    .. note::

      ``lib_mic_array`` does not currently support sample rate change after initialisation

    - Channel counts
    - Audio Class version
    - Product/Vendor IDs
    - Various product strings
    - Master clock frequency

To enable PDM microphone support  ``XUA_NUM_PDM_MICS`` must be set to a non-zero value.  Setting this will cause the ``XUA_AudioHub``
task to forward sample rate information and receive samples from the relevant microphone related tasks.

These parameters are set via defines in the ``xua_conf.h`` header file. For this simple application the
complete contents of this file are as follows:

.. literalinclude:: ../../src/xua_conf.h
   :start-at: // Copyright
   :end-at: #endif

You can try changing ``XUA_PDM_MIC_FREQ`` to 32000 or 16000 to reconfigure the system to lower sample rates than the default 48 kHz.


The application ``main()`` function
===================================

The ``main()`` function is provided within `lib_xua <https://github.com/xmos/lib_xua/blob/develop/lib_xua/src/core/main.xc>`_ itself
and it starts all of the tasks in parallel using the xC ``par`` construct.

Firstly the standard ``lib_xua`` USB side tasks are run on tile 0. This code starts the low-level USB task and an Endpoint 0 task. The Audio buffering task and a task to handle
the audio I/O (``XUA_AudioHub``) is started on tile 1 where the I2S bus exists.

The microphone task ``mic_array_task`` spawns a single thread which handles PDM receive on the ports and the decimation filters to produce PCM.
This is placed on tile 1 where the microphone hardware is connected.
It connects directly to ``XUA_AudioHub`` and provides samples which are at the same rate as the audio I/O.

User callbacks
--------------

While the ``main()`` function is provided within ``lib_xua`` itself, there are a number of callbacks which allow
for customisation of the application.

The DAC is configured by ``AudioHwInit()`` function in `hwsupport.xc`, which calls Audio hardware initialisation
functions for the relevant hardware from ``lib_board_support``

.. literalinclude:: ../../src/hwsupport.xc
   :start-at: #include "xua.h"
   :end-before: /* Configures the external

Callback functions ``UserBufferManagement()`` and ``user_pdm_process()`` are defined in `user_callbacks.xc`.
Both these functions are called from the main loop in ``XUA_AudioHub()``.
``user_pdm_process()`` implements the PCM sample post processing, which for this example is a simple scaling by a factor of 64
to allow the mic captured audio to be heard easily. ``UserBufferManagement()`` routes the mic samples to the DAC.

.. literalinclude:: ../../src/user_callbacks.xc


|newpage|

Demo Hardware Setup
===================

To run the demo, connect a USB cable to power the ``XK-EVK-XU316`` board, ensure the pair of PDM microphones are connected via the ribbon cables and
and plug the xTAG to the board and connect the xTAG USB cable to your development machine.

.. figure:: images/hw_setup.*
   :width: 80%

   Hardware setup

|newpage|

Building the Application
========================

The following section assumes you have downloaded and installed the `XMOS XTC tools <https://www.xmos.com/software-tools/>`_
(see `README` for required version). Installation instructions can be found `here <https://xmos.com/xtc-install-guide>`_.
Be sure to pay attention to the section `Installation of required third-party tools
<https://www.xmos.com/documentation/XM-014363-PC-10/html/installation/install-configure/install-tools/install_prerequisites.html>`_.

The application uses the `xcommon-cmake <https://www.xmos.com/file/xcommon-cmake-documentation/?version=latest>`_
build system as bundled with the XTC tools.

The ``AN00248_xua_example_pdm_mics`` software zip-file should be downloaded and unzipped to a chosen directory.


To configure the build run the following from an XTC command prompt::

    cd examples
    cd AN00248_xua_example_pdm_mics
    cmake -G "Unix Makefiles" -B build

All required dependencies are included in the software download, however, if any are missing it is
at this configure step that they will be downloaded by the build system.

Finally, the application binaries can be built using ``xmake``::

    xmake -j -C build

The application uses approximately 49 kB on tile 0 and 17 kB on tile 1 (of 512 kB on each).

Launching the demo application
==============================

To run the application return to the ``/examples/AN00248_xua_example_pdm_mics`` directory and run the following command::

    xrun bin/app_xua_pdm_mics.xe

You should now see an audio device called ``XUA PDM Example`` and be able hear the stereo microphone audio
by recording the stream on the host or connecting to the analog output jacks.

|newpage|

***************
Further Reading
***************

   * XMOS XTC Tools Installation Guide

     https://xmos.com/xtc-install-guide

      * XMOS XTC Tools User Guide

        https://www.xmos.com/view/Tools-15-Documentation

      * XMOS application build and dependency management system; xcommon-cmake

        https://www.xmos.com/file/xcommon-cmake-documentation/?version=latest

