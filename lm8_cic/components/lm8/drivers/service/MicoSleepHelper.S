	.section	.text
	.global		MicoSleepMicroSecs
	.type		MicoSleepMicroSecs, @function
MicoSleepMicroSecs:
.L1:	
	cmpi	R0, 0x00
	bnz	.L2
	cmpi	R1, 0x00
	bz	.L3
.L2:
	nop
	nop
	nop
	subi	R0, _lo(1)
	subic	R1, _hi(1)
	b	.L1
.L3:
	ret
	.size		MicoSleepMicroSecs, .-MicoSleepMicroSecs

	.section	.text
	.global		MicoSleepMilliSecs
	.type		MicoSleepMilliSecs, @function
MicoSleepMilliSecs:
.L4:
	cmpi	R0, 0x00
	bnz	.L5
	cmpi	R1, 0x00
	bz	.L6
.L5:	
	movi	R2, _lo(1000)
	movi	R3, _hi(1000)
.L7:
	cmpi	r2, 0x00
	bnz	.L8
	cmpi	R3, 0x00
	bz	.L9
.L8:
	nop
	nop
	nop
	subi	R2, _lo(1)
	subic	R3, _hi(1)
	b	.L7
.L9:	
	subi	R0, _lo(1)
	subic	R1, _hi(1)
	b	.L4
.L6:
	ret
	.size		MicoSleepMilliSecs, .-MicoSleepMilliSecs
