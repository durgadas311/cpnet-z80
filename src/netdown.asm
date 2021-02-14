; NETDOWN - shutdown CP/NET 1.2 SNIOS and prepare for RESET

	maclib	z80

cr	equ	13
lf	equ	10

cpm	equ	0
bdos	equ	5

; BDOS functions
conin	equ	1
print	equ	9
getver	equ	12
; NDOS functions
netcfg	equ	69

	org	0100h
	jmp	start

nocpn	db	'Requires CP/NET 1.2',cr,lf,'$'
rdymsg:	db	'Ready for RESET/power-off',cr,lf
	db	'(press any key to resume CP/NET)$'
xsnios:	db	'Not a recognized SNIOS',cr,lf,'$'

xconp:	dw	0	; CON: word in network config table
xcon:	db	0	; saved CON: byte

start:	lxi	sp,stack
	mvi	c,getver
	call	bdos
	mov	a,h
	ani	02h
	jz	notnet
	mov	a,l
	cpi	30h
	jnc	notnet
	mvi	c,netcfg
	call	bdos
	push	h
	lxi	d,34	; CON: word offset
	dad	d
	shld	xconp
	popix
	; check for at least 6 JMPs...
	ldx	c,-3
	ldx	b,-6
	ldx	e,-9
	ldx	d,-12
	ldx	l,-15
	ldx	h,-18
	mov	a,c
	ana	b
	ana	e
	ana	d
	ana	l
	ana	h
	cpi	0c3h	;JMP?
	jnz	notcom
	mov	a,c
	ora	b
	ora	e
	ora	d
	ora	l
	ora	h
	cpi	0c3h	;JMP?
	jnz	notcom
	; looks OK, call NTWKDN...
	; but first, make sure CON: is local...
	lhld	xconp	;
	mov	a,m	;
	sta	xcon	;
	ani	01111111b
	mov	m,a	;
	ldx	l,-2
	ldx	h,-1
	call	callhl
	lxi	d,rdymsg
	mvi	c,print
	call	bdos
	mvi	c,conin
	call	bdos
	; if we return here, just resume...
	lhld	xconp	; restore CON:
	lda	xcon	;
	mov	m,a	;
	jmp	cpm

callhl:	pchl

notnet:	lxi	d,nocpn
	mvi	c,print
	call	bdos
	jmp	cpm

; Not a recognized SNIOS
notcom:	lxi	d,xsnios
	mvi	c,print
	call	bdos
	jmp	cpm

	ds	64
stack:	ds	0

	end
