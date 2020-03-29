
	.section .vectors,"ax"
	.weak	__irq_save_restore2
	b	__irq_save_restore2

.globl _start
_start:
	/* Clear bss */
	movi	r0,_lo(__bss_start)
#if defined(__CMODEL_LARGE__) || defined(__CMODEL_MEDIUM__)
	movi	r13,_hi(__bss_start)
#endif
#ifdef __CMODEL_LARGE__
	movi	r14,_higher(__bss_start)
	movi	r15,_highest(__bss_start)
#endif
	movi	r1,0

3:
	cmpi	r0,_lo(__bss_end)
#if defined(__CMODEL_LARGE__) || defined(__CMODEL_MEDIUM__)
	bnz	1f
	cmpi	r13,_hi(__bss_end)
#endif
#ifdef __CMODEL_LARGE__
	bnz	1f
	cmpi	r14,_higher(__bss_end)
	cmpi	r15,_highest(__bss_end)
#endif
	bz	2f
1:	sspi	r1,r0
	addi	r0,_lo(1)
#if defined(__CMODEL_LARGE__) || defined(__CMODEL_MEDIUM__)
	addic	r13,_hi(1)
#endif
#ifdef __CMODEL_LARGE__
	addic	r14,_higher(1)
	addic	r15,_highest(1)
#endif
	b	3b

2:	/* Setup the stack */
#if defined (__CMODEL_SMALL__)
	movi	r14,__stack

	/* Mark the end-of-stack */
	movi	r15,0
#elif defined(__CMODEL_MEDIUM__)
	movi	r8,_lo(__stack)
	movi	r9,_hi(__stack)

	/* Mark the end-of-stack */
	movi	r10,_lo(0)
	movi	r11,_hi(0)
#elif defined(__CMODEL_LARGE__)
	/* -4 because main(int, char **, char **) and that third argument
	 * is passed on the stack, otherwise the compile may access things
	 * past the end of the stack space. */
	movi	r24,_lo(__stack-4)
	movi	r25,_hi(__stack-4)
	movi	r26,_higher(__stack-4)
	movi	r27,_highest(__stack-4)

	/* Mark the end-of-stack */
	movi	r28,_lo(0)
	movi	r29,_hi(0)
	movi	r30,_higher(0)
	movi	r31,_highest(0)
#endif

	seti
#ifndef __MICO_NO_INIT__ 
	call	LatticeDDInit
#else
	call	main
#endif
	clri

	/* Kill the simulation */
	movi	r31,0xde
	movi	r30,0xad
	movi	r29,0xbe
	movi	r28,0xef
	mov	r27,r0

1:	b	1b

__irq_save_restore2:
	iret