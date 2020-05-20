; diskless BDOS for CP/NOS - functions 0-12 only.
; may be ROMable

	extrn	ndosrl
	public	bdos,bdosds

reboot	equ	0000h
ioloc	equ	0003h
bdosa	equ	0006h

; TODO: how do we know BIOS is at ndosrl+0x300?
; Offsets are for ndosrl
wbootf	equ	0303h
constf	equ	0306h
coninf	equ	0309h
conoutf equ	030ch
listf	equ	030fh

cr	equ	13
lf	equ	10
tab	equ	9
bs	equ	8
xoff	equ	13h
ctlc	equ	3
ctle	equ	5
ctlp	equ	10h
ctlr	equ	12h
ctlu	equ	15h
ctlx	equ	18h
rubout	equ	7fh


	cseg
	db	0,0,0,0,0,0	; serial number
bdos:	jmp	bdose

	db	'COPR. ''78-''82 DRI'

bdose:	xchg
	shld	info
	xchg
	lxi	h,0
	shld	aret
	dad	sp
	shld	entsp
	lxi	sp,lstack
	lxi	h,goback
	push	h
	mov	a,c
	cpi	nfuncs
	rnc
	mov	c,e
	lxi	h,functab
	mov	e,a
	mvi	d,0
	dad	d
	dad	d
	mov	e,m
	inx	h
	mov	d,m
	lhld	info
	xchg
	pchl

functab:
	dw	ndosrl+wbootf
	dw	func1
	dw	tabout
	dw	func3
	dw	ndosrl+conoutf
	dw	ndosrl+listf
	dw	func6
	dw	func7
	dw	func8
	dw	func9
	dw	read
	dw	func11
	dw	func12
nfuncs	equ	($-functab)/2

conin:	lxi	h,kbchar
	mov	a,m
	mvi	m,0
	ora	a
	rnz
	jmp	ndosrl+coninf

conech:	call	conin
	call	echoc
	rc
	push	psw
	mov	c,a
	call	tabout
	pop	psw
	ret

echoc:	cpi	cr
	rz
	cpi	lf
	rz
	cpi	tab
	rz
	cpi	bs
	rz
	cpi	' '
	ret

conbrk:	lda	kbchar
	ora	a
	jnz	conb1
	call	ndosrl+constf
	ani	1
	rz
	call	ndosrl+coninf
	cpi	xoff
	jnz	conb0
	call	ndosrl+coninf
	cpi	ctlc
	jz	reboot
	xra	a
	ret

conb0:	sta	kbchar
conb1:	mvi	a,1
	ret

conout:	lda	compcol
	ora	a
	jnz	compout
	push	b
	call	conbrk
	pop	b
	push	b
	call	ndosrl+conoutf
	pop	b
	push	b
	lda	listcp
	ora	a
	cnz	ndosrl+listf
	pop	b
compout:
	mov	a,c
	lxi	h,column
	cpi	rubout
	rz
	inr	m
	cpi	' '
	rnc
	dcr	m
	mov	a,m
	ora	a
	rz
	mov	a,c
	cpi	bs
	jnz	notbacksp
	dcr	m
	ret
notbacksp:
	cpi	lf
	rnz
	mvi	m,0
	ret

ctlout:
	mov	a,c
	call	echoc
	jnc	tabout
	push	psw
	mvi	c,'^'
	call	conout
	pop	psw
	ori	'@'
	mov	c,a
tabout:
	mov	a,c
	cpi	tab
	jnz	conout
tab0:	mvi	c,' '
	call	conout
	lda	column
	ani	111b
	jnz	tab0
	ret

backup:	call	pctlh
	mvi	c,' '
	call	ndosrl+conoutf
pctlh:	mvi	c,bs
	jmp	ndosrl+conoutf

crlfp:	mvi	c,'#'
	call	conout
	call	crlf
crlfp0:	lda	column
	lxi	h,strtcol
	cmp	m
	rnc
	mvi	c,' '
	call	conout
	jmp	crlfp0

crlf:	mvi	c,cr
	call	conout
	mvi	c,lf
	jmp	conout

print:	ldax	b
	cpi	'$'
	rz
	inx	b
	push	b
	mov	c,a
	call	tabout
	pop	b
	jmp	print

read:	lda	column
	sta	strtcol
	lhld	info
	mov	c,m
	inx	h
	push	h
	mvi	b,0
readnx:	push	b
	push	h
readn0:	call	conin
	ani	7fh
	pop	h
	pop	b
	cpi	cr
	jz	readen
	cpi	lf
	jz	readen
	cpi	bs
	jnz	noth
	mov	a,b
	ora	a
	jz	readnx
	dcr	b
	lda	column
	sta	compcol
	jmp	linelen

noth:	cpi	rubout
	jnz	notrub
	mov	a,b
	ora	a
	jz	readnx
	mov	a,m
	dcr	b
	dcx	h
	jmp	rdech1

notrub:	cpi	ctle
	jnz	note
	push	b
	push	h
	call	crlf
	xra	a
	sta	strtcol
	jmp	readn0
note:	cpi	ctlp
	jnz	notp
	push	h
	lxi	h,listcp
	mvi	a,1
	sub	m
	mov	m,a
	pop	h
	jmp	readnx

notp:	cpi	ctlx
	jnz	notx
	pop	h
backx:	lda	strtcol
	lxi	h,column
	cmp	m
	jnc	read
	dcr	m
	call	backup
	jmp	backx
notx:	cpi	ctlu
	jnz	notu
	call	crlfp
	pop	h
	jmp	read
notu:	cpi	ctlr
	jnz	notr
linelen:
	push	b
	call	crlfp
	pop	b
	pop	h
	push	h
	push	b
rep0:	mov	a,b
	ora	a
	jz	rep1
	inx	h
	mov	c,m
	dcr	b
	push	b
	push	h
	call	ctlout
	pop	h
	pop	b
	jmp	rep0

rep1:	push	h
	lda	compcol
	ora	a
	jz	readn0
	lxi	h,column
	sub	m
	sta	compcol
backsp:	call	backup
	lxi	h,compcol
	dcr	m
	jnz	backsp
	jmp	readn0

notr:
	;not a ctlr, place into buffer
rdecho:
	inx	h
	mov	m,a
	inr	b
rdech1:	push	b
	push	h
	mov	c,a
	call	ctlout
	pop	h
	pop	b
	mov	a,m
	cpi	ctlc
	mov	a,b
	jnz	notc
	cpi	1
	jz	reboot
notc:	cmp	c
	jc	readnx
readen:	pop	h
	mov	m,b
	mvi	c,cr
	jmp	conout

func1:	call	conech
	jmp	sta$ret

func3:	call	ndosrl+coninf
	jmp	sta$ret

func6:	mov	a,c
	inr	a
	jz	dirinp
	inr	a
	jz	ndosrl+constf
	jmp	ndosrl+conoutf

dirinp:	call	ndosrl+constf
	ora	a
	jz	goback
	call	ndosrl+coninf
	jmp	sta$ret

func7:	lda	ioloc
	jmp	sta$ret

func8:	lxi	h,ioloc
	mov	m,c
	ret

func9:	xchg
	mov	c,l
	mov	b,h
	jmp	print

func11:	call	conbrk
sta$ret:
	sta	aret
	ret

setlret1:
	mvi	a,1
	jmp	sta$ret

	dseg
bdosds:	; area to be zeroed by CPNDOS - must be 61 bytes...
compcol:	db	0
strtcol:	db	0
column:	db	0
listcp:	db	0
kbchar:	db	0
entsp:	ds	2
	ds	48
lstack:	dw	0
info:	ds	2
aret:	ds	2

	cseg
func12:	mvi	a,22h	; CP/M v2.2
	jmp	sta$ret

goback:	lhld	entsp
	sphl
	lhld	aret
	mov	a,l
	mov	b,h
	ret

	end
