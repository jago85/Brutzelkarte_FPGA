/****************************************************************************
**
**  Name: MicoInterrupts.c
**
**  Description:
**        implements functions for enabling/disabling LatticeMico8 interrupts.
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


#include "MicoInterrupts.h"

#ifndef __MICO_NO_INTERRUPTS__

volatile static unsigned int s_uiInterruptContext = 0;

/***********************************************************************
 * Disables a specific interrupt
 *
 * Arguments:
 *  char IntLevel: interrupt 0 through 7 that needs to be disabled.
 * 
 * Return Values:
 *  MICO_STATIS_OK if successful.
 ***********************************************************************/
mico_status MicoDisableInterrupt (char intNum) {
  
  char im;
  
  if (intNum > MAX_MICO8_ISR_LEVEL)
    return (MICO_STATUS_E_INVALID_PARAM);
  
  // Disable global interrupt
  MICO8_DISABLE_GLOBAL_IRQ();
  // Disable mask bit in IM register
  MICO8_READ_IM(im);
  im &= ~(0x1 << intNum);
  MICO8_PROGRAM_IM(im);
  // Enable global intterupt if we are not in an interrupt-context
  if (s_uiInterruptContext == 0)
    MICO8_ENABLE_GLOBAL_IRQ();
  
  return (MICO_STATUS_OK);
}

/***********************************************************************
 * Enables a specific interrupt
 *
 * Arguments:
 *  char IntLevel: interrupt 0 through 7 that needs to be disabled.
 * 
 * Return Values:
 *  MICO_STATIS_OK if successful.
 ***********************************************************************/
mico_status MicoEnableInterrupt (char intNum) {
  
  char im;
  
  if (intNum > MAX_MICO8_ISR_LEVEL)
    return (MICO_STATUS_E_INVALID_PARAM);
  
  // Disable global interrupt
  MICO8_DISABLE_GLOBAL_IRQ();
  // Disable mask bit in IM register
  MICO8_READ_IM(im);
  im |= (0x1 << intNum);
  MICO8_PROGRAM_IM(im);
  // Enable global interrupt if we are not in an interrupt-context
  if (s_uiInterruptContext == 0)
    MICO8_ENABLE_GLOBAL_IRQ();
  
  return (MICO_STATUS_OK);
}

#endif
