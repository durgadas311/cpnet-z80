; Program to signal NETSERVR RSP to start network operations.
; This command is run once the network hardware is fully
; configured.

CR	equ	13
LF	equ	10

cpm	equ	0
bdos	equ	5

printf	equ	9
openqf	equ	135
writqf	equ	139

	org	100h
	jmp	start

done:	db	'CP/NET Server started',CR,LF,'$'
qnfmsg:	db	'No mutex: MXNetwrk',CR,LF,'$'

mx$UQCB:
	dw	0	; QCB filled by openqf
	dw	0	; no message, no buffer
	db	'MXNetwrk'

start:
	lxi	sp,stack
	lxi	d,mx$UQCB
	mvi	c,openqf
	call	bdos
	ora	a
	jnz	noque
	lxi	d,mx$UQCB
	mvi	c,writqf
	call	bdos
	; no return value
	lxi	d,done
exit:	mvi	c,printf
	call	bdos
	jmp	cpm

noque:	lxi	d,qnfmsg
	jmp	exit

	ds	64
stack:	ds	0

	end
