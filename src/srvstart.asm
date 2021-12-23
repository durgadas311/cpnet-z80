; Program to signal NETSERVR RSP to start network operations.
; This command is run once the network hardware is fully
; configured.

	maclib	config
	maclib	cfgnwif

CR	equ	13
LF	equ	10

cpm	equ	0
bdos	equ	5

	org	100h
	jmp	start

done:	db	'CP/NET Server started',CR,LF,'$'
qnfmsg:	db	'No mutex: MXNetwrk',CR,LF,'$'
nocpnt:	db	'Not a CP/NET Configuration',CR,LF,'$'
nompmm:	db	'Requires MP/M-II',CR,LF,'$'
did:	db	'CP/NET Server already started',CR,LF,'$'

mx$UQCB:
	dw	0	; QCB filled by openqf
	dw	0	; no message, no buffer
	db	'MXServer'

cmdadr:	dw	0

start:
	lxi	sp,stack
	mvi	c,versf
	call	bdos
	mov	a,h
	ani	00000001b
	jz	nompm
	mvi	c,sysdatf
	call	bdos
	mvi	l,S$CPNET
	mov	e,m
	inx	h
	mov	d,m
	mov	a,e
	ora	d
	jz	nonet
	lxi	h,G$CMD
	dad	d
	shld	cmdadr
	mov	a,m
	cpi	NWSTART	; already started? need 'force' option?
	jz	alrdy
	lxi	d,mx$UQCB
	mvi	c,openqf
	call	bdos
	ora	a
	jnz	noque
	lhld	cmdadr
	mvi	m,NWSTART
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

nompm:	lxi	d,nompmm
	jmp	exit

nonet:	lxi	d,nocpnt
	jmp	exit

alrdy:	lxi	d,did
	jmp	exit

	ds	64
stack:	ds	0

	end
