/****************************************************************************
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
**  File       : MicoUtils.h
**  Description: Declarations of utility functions to support LM8
**                  MicoSleepMicroSecs: LM8 loop for microsecond delay
**                  MicoSleepMilliSecs: LM8 loop for millisecond delay
**
** --------------------------------------------------------------------------
**  Change History (Latest changes on top)
**
**  Ver    Date        Description
** --------------------------------------------------------------------------
**  3.2    03/20/2010  Initial Version
**---------------------------------------------------------------------------*/
#ifndef MICOUTILS_H_
#define MICOUTILS_H_

void MicoSleepMicroSecs(unsigned int timeInMicroSecs);
void MicoSleepMilliSecs(unsigned int timeInMilliSecs);

#endif /*MICOUTILS_H_*/
