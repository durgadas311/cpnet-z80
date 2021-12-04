; Program to signal NETSERVR RSP to shutdown network operations.

	maclib	config
	maclib	cfgnwif

CR	equ	13
LF	equ	10

cpm	equ	0
bdos	equ	5

	org	100h
	jmp	start

done:	db	'CP/NET Server stopped',CR,LF,'$'
nocpnt:	db	'Not a CP/NET Configuration',CR,LF,'$'
nompmm:	db	'Requires MP/M-II',CR,LF,'$'
did:	db	'CP/NET Server already stopped',CR,LF,'$'

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
	mov	a,m
	cpi	NWSTOP	; already stopped? need 'force' option?
	jz	alrdy
	mvi	m,NWSTOP	; should be detected soon...
	lxi	d,done
exit:	mvi	c,printf
	call	bdos
	jmp	cpm

nompm:	lxi	d,nompmm
	jmp	exit

nonet:	lxi	d,nocpnt
	jmp	exit

alrdy:	lxi	d,did
	jmp	exit

	ds	64
stack:	ds	0

	end
