; Basic CP/NET routines

	public	cpnsetup

	maclib	z80

bdos	equ	5

print	equ	9

cr	equ	13
lf	equ	10

	cseg

; HL=network config table
; DE=template (0FFH=skip)
; Reports any valid settings, assumes starting on newline
cpnsetup:
	mvi	b,16	; 16 drives
cpns0:	inx	h	; skip status/node ID
	inx	h
	inx	d
	inx	d
	ldax	d	;
	cpi	0ffh
	cnz	netdrv
	djnz	cpns0
	; drives done, skip CON:
	inx	h
	inx	h
	inx	d
	inx	d
	; check LST:
	ldax	d
	cpi	0ffh
	rz
	mov	m,a
	sta	b0
	inx	h
	inx	d
	ldax	d
	mov	m,a
	sta	b1
	lda	b0
	ani	080h
	jrz	loclst
	; networked LST:
	ani	0fh
	lxi	h,nl1
	call	hexdig
	lda	b1
	lxi	h,nl2
	call	hexout
	lxi	d,nlst
	mvi	c,print
	call	bdos
	ret
loclst:	lxi	d,llst
	mvi	c,print
	call	bdos
	ret

netdrv:	push	h
	push	d
	ldax	d
	mov	m,a
	sta	b0
	inx	h
	inx	d
	ldax	d
	mov	m,a
	sta	b1
	; report drive setting
	push	b
	mvi	a,16
	sub	b	; local drive number
	adi	'A'
	sta	n0
	sta	l0
	lda	b0
	ani	080h
	jrz	locdrv
; networked drive
	lda	b0
	ani	0fh
	adi	'A'
	sta	n1
	lda	b1
	lxi	h,n2
	call	hexout
	lxi	d,netwk
	mvi	c,print
	call	bdos
	jr	retdrv

locdrv:	lxi	d,ldrv
	mvi	c,print
	call	bdos
retdrv:
	pop	b
	pop	d
	pop	h
	ret

hexout:	push	psw
	rrc
	rrc
	rrc
	rrc
	call	hexdig
	pop	psw
hexdig:	ani	0fh
	adi	90h
	daa
	aci	40h
	daa
	mov	m,a
	inx	h
	ret

	dseg
b0:	db	0
b1:	db	0

ldrv:	db	'Local '
l0:	db	'_:',cr,lf,'$'
netwk:	db	'Network '
n0:	db	'_: = '
n1:	db	'_:['
n2:	db	'__]',cr,lf,'$'

llst:	db	'Local LST:',cr,lf,'$'
nlst:	db	'Network LST: = '
nl1:	db	'_['
nl2:	db	'__]',cr,lf,'$'

	end
