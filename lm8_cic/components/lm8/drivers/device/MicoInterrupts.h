/****************************************************************************
**
**  Name: MicoInterrupts.h
**
**  Description:
**        declares functions for manipulating LatticeMico8 processor
**        interrupts (such as registering interrupt handler,
**        enabling/disabling interrupts)
**
**  $Revision: $
**
** Disclaimer:
**
**   This source code is intended as a design reference which
**   illustrates how these types of functions can be implemented.  It
**   is the user's responsibility to verify their design for
**   consistency and functionality through the use of formal
**   verification methods.  Lattice Semiconductor provides no warranty
**   regarding the use or functionality of this code.
**
** --------------------------------------------------------------------
**
**                     Lattice Semiconductor Corporation
**                     5555 NE Moore Court
**                     Hillsboro, OR 97214
**                     U.S.A
**
**                     TEL: 1-800-Lattice (USA and Canada)
**                          (503)268-8001 (other locations)
**
**                     web:   http://www.latticesemi.com
**                     email: techsupport@latticesemi.com
**
** --------------------------------------------------------------------------
**
**  Change History (Latest changes on top)
**
**  Ver    Date        Description
** --------------------------------------------------------------------------
**
**  3.2    03/20/2010  Initial Version
**
**---------------------------------------------------------------------------
*****************************************************************************/

#include "MicoTypes.h"

#ifndef MAX_MICO8_ISR_LEVEL
#define MAX_MICO8_ISR_LEVEL 7
#endif

/***********************************************************************
 * Disable Global Interrupt 
 *
 * Arguments:
 * 
 * Return Values:
 ***********************************************************************/
#define MICO8_DISABLE_GLOBAL_IRQ() __asm__ volatile ("clri")

/***********************************************************************
 * Enable Global Interrupt
 *
 * Arguments:
 * 
 * Return Values:
 ***********************************************************************/
#define MICO8_ENABLE_GLOBAL_IRQ()  __asm__ volatile ("seti")

/***********************************************************************
 * Read IE (Global IRQ) register
 *
 * Arguments:
 *  X: char in which value of IE register is returned. Bit 0 indicates 
 *     whether interrupts are enabled or disabled.
 *
 * Return Values:
 ***********************************************************************/
#define MICO8_READ_IE(X)           __asm__ volatile ("rcsr %0, ie" : "=r" (X))

/***********************************************************************
 * Program IM register with an input value
 *
 * Arguments:
 *  X: char to enable/disable each of the 8 LatticeMico8 interrupt lines
 *     individually. For each bit: 0 - disable, 1 - enable
 * 
 * Return Values:
 ***********************************************************************/
#define MICO8_PROGRAM_IM(X)        __asm__ volatile ("wcsr im, %0" : : "r" (X))

/***********************************************************************
 * Read IM register
 *
 * Arguments:
 *  X: char in which value of IM register is returned. Each bit indicates
 *     whether that interrupt line is enabled (1) or disabled (0).
 * 
 * Return Values:
 ***********************************************************************/
#define MICO8_READ_IM(X)           __asm__ volatile ("rcsr %0, im" : "=r" (X))

/***********************************************************************
 * Program IP register with an input value
 *
 * Arguments:
 *  X: char to individually release a pending LatticeMico8 interrupt. A 
 *     pending interrupt is release by writing a 1 to corresponding bit 
 *     (multiple pending interrupts can be released by writing 1 to 
 *     multiple bits).
 * 
 * Return Values:
 ***********************************************************************/
#define MICO8_PROGRAM_IP(X)        __asm__ volatile ("wcsr ip, %0" : : "r" (X))

/***********************************************************************
 * Read IP register
 *
 * Arguments:
 *  X: char in which value of IP register is returned. Each bit indicates 
 *     whether that interrupt is pending (1) or not (0).
 * 
 * Return Values:
 ***********************************************************************/
#define MICO8_READ_IP(X)           __asm__ volatile ("rcsr %0, ip" : "=r" (X))

#ifndef __MICO_NO_INTERRUPTS__
/***********************************************************************
 * Disables a specific interrupt
 *
 * Arguments:
 *  char IntLevel: interrupt 0 through 7 that needs to be disabled.
 * 
 * Return Values:
 *  MICO_STATIS_OK if successful.
 ***********************************************************************/
mico_status MicoDisableInterrupt (char IntLevel);

/***********************************************************************
 * Enables a specific interrupt
 *
 * Arguments:
 *  char IntLevel: interrupt 0 through 7 that needs to be disabled.
 * 
 * Return Values:
 *  MICO_STATIS_OK if successful.
 ***********************************************************************/
mico_status MicoEnableInterrupt (char IntLevel);
#endif

