#include "DDStructs.h"

#ifndef __MICO_NO_INTERRUPTS__
#include "MicoInterrupts.h"

void MicoISRHandler();

void __IRQ(void) __attribute__ ((interrupt));

void __IRQ(void)
{
	MicoISRHandler();
}

void MicoISRHandler()
{

  unsigned char ip, im, Mask, IntLevel;
  do {
		MICO8_READ_IM(im);
		MICO8_READ_IP(ip);

		ip &= im;
		Mask = 0x1;
		IntLevel = 0x0;

		if ( ip!=0 ) {
				do {
        			if (Mask & ip) {
						switch(IntLevel) {
							default:
								break;
	    				}
	    				MICO8_PROGRAM_IP(Mask);
						break;
					}
					__asm__ __volatile__
					("clrc	\n\t"
					 "rolc	%0, %0\n\t"
					 : "=r" (Mask));
					++IntLevel;
				} while (1);
		} else {
            break;
		}
	} while (1);

	return;
 }
#endif