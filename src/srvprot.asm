; Program to show/change NETSERVR RSP R/O vector (drive write protect).

	maclib	z80
	maclib	config
	maclib	cfgnwif

CR	equ	13
LF	equ	10

cpm	equ	0
bdos	equ	5
cmdlin	equ	0080h

	org	100h
	jmp	start

help:	db	'Use "D:" or "-D:" separated by space',CR,LF,'$'
done:	db	'CP/NET Server drives protected:',CR,LF,'$'
nocpnt:	db	'Not a CP/NET Configuration',CR,LF,'$'
nompmm:	db	'Requires MP/M-II'
crlf:	db	CR,LF,'$'
drive:	db	'?: $'

rovadr:	dw	0
andvec:	dw	0ffffh	; modified by "-A:" expressions
orvec:	dw	00000h	; modified by "A:" expressions
change:	db	0

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
	lxi	h,G$ROV
	dad	d
	shld	rovadr
	;
	; now parse commandline...
	;
	lda	cmdlin
	ora	a
	jz	show
	lxi	h,cmdlin
	mov	b,m
	inx	h
pars0:	mov	a,m
	cpi	' '
	jnz	pars1
	inx	h
	djnz	pars0
	jmp	fini
pars1:	cpi	'-'	; un-protect?
	mvi	c,0
	jrnz	pars2
	mvi	c,1	; flag as un-protect
	inx	h
	dcr	b
	jz	error
	mov	a,m
pars2:	sui	'A'
	jc	error
	cpi	16
	jnc	error
	; TODO: is colon optional? is space?
	mov	d,a
	inx	h
	dcr	b
	jz	error
	mov	a,m
	cpi	':'
	jnz	error
	inx	h
	dcr	b
	jrz	ok	; FIXME: B will go negative
	mov	a,m
	cpi	' '
	jnz	error	; TODO: allow comma?
ok:	; have drive in D, C flags add/remove
	lda	change
	ori	0ffh
	sta	change
	push	h
	push	b
	mov	a,d
	dcr	c
	jrz	rmv
	; add
	call	adddrv
	jr	join
rmv:	call	rmvdrv
join:	pop	b
	pop	h
	inx	h
	dcr	b
	jm	fini
	jnz	pars0
fini:
	lda	change
	ora	a
	jz	show	; if no changes...
	lhld	rovadr
	lded	andvec
	call	bitand
	lded	orvec
	call	bitor

show:	lxi	d,done
	mvi	c,printf
	call	bdos
	lhld	rovadr
	mov	e,m
	inx	h
	mov	d,m
	mvi	b,16
	mvi	c,'A'
sh0:	bit	0,e
	cnz	shdrv
	srlr	d
	rarr	e
	inr	c
	djnz	sh0
	lxi	d,crlf
exit:	mvi	c,printf
	call	bdos
	jmp	cpm

error:	lxi	d,help
	jr	exit

; C=drive letter
shdrv:	mov	a,c
	sta	drive
	push	d
	push	b
	lxi	d,drive
	mvi	c,printf
	call	bdos
	pop	b
	pop	d
	ret

; add (set bit) drive A to orvec
; orvec |= vector(drive)
adddrv:	call	drvvec	; get bit vec in HL
	xchg
	lhld	orvec
	mov	a,l
	ora	e
	mov	l,a
	mov	a,h
	ora	d
	mov	h,a
	shld	orvec
	ret

; remove (clear bit) drive A from andvec
; andvec &= ~vector(drive)
rmvdrv:	call	drvvec	; get bit vec in HL
	xchg
	lhld	andvec
	mov	a,e
	cma
	ana	l
	mov	l,a
	mov	a,d
	cma
	ana	h
	mov	h,a
	shld	andvec
	ret

; convert drive A (0-15) to bitvec in HL
drvvec:	lxi	h,1
	ora	a
	rz
dv0:	dad	h
	dcr	a
	jrnz	dv0
	ret

; (HL) &= DE
bitand:
	mov	a,m
	ana	e
	mov	m,a
	inx	h
	mov	a,m
	ana	d
	mov	m,a
	dcx	h
	ret

; (HL) |= DE
bitor:
	mov	a,m
	ora	e
	mov	m,a
	inx	h
	mov	a,m
	ora	d
	mov	m,a
	dcx	h
	ret

nompm:	lxi	d,nompmm
	jmp	exit

nonet:	lxi	d,nocpnt
	jmp	exit

	ds	64
stack:	ds	0

	end
