; A stress-test for WizNET W5500 SPI interfaces
;

	maclib	z80

	maclib	config

; W5500 constants
WRITE	equ	00000100b
TX0BSB	equ	0010b	; Socket BSB
TX0BUF	equ	0000h	; Tx FIFO buffer offset

CTLC	equ	3
CR	equ	13
LF	equ	10

cpm	equ	0
bdos	equ	5
cmdlin	equ	0080h

dircon	equ	6
print	equ	9
getver	equ	12

	org	00100h

	jmp	start

cpnet:	db	0
seed:	db	0
pass:	dw	0
verbos:	db	0	; also means stop on error

faterr:	db	CR,LF,'Fatal error communicating with WizNet',CR,LF,'$'

start:
	sspd	usrstk
	lxi	sp,stack
	mvi	c,getver
	call	bdos
	mov	a,h
	ani	02h
	sta	cpnet
	; parse options
	lda	cmdlin	; length
	ora	a
	jrz	begin
	lxi	h,cmdlin
	mov	b,m
	inx	h
skipb:	mov	a,m
	cpi	' '
	jrnz	noblk
	inx	h
	djnz	skipb
	; A still ' '
noblk:	cpi	'V'	; verbose
	jrnz	begin
	sta	verbos
begin:
	; all these are constant
	mvi	a,TX0BSB
	rlc
	rlc
	rlc	; into position for W5500
	sta	bsb
	lxi	h,TX0BUF
	shld	off
	lxi	h,128	; we only use 128 bytes
	shld	num
loop:
	mvi	a,CR
	call	conout
	lhld	pass
	call	wrdout

	call	setbuf
	call	wizset
	jc	fatal
	call	xxxbuf
	call	wizget
	jc	fatal
	call	chkbuf
	jz	ok
	; C=error count
	mvi	a,'!'
	call	conout
	lda	seed
	call	hexout
	mvi	a,' '
	call	conout
	mov	a,c
	call	decout
	call	crlf
	lda	verbos
	ora	a
	jnz	dump	; and exit
ok:
	lda	seed
	adi	1
	daa
	sta	seed
	lhld	pass
	inx	h
	shld	pass
	call	conbrk
	jz	loop
exit:
	call	crlf
	jmp	cpm

fatal:
	lxi	d,faterr
xitmsg:
	mvi	c,print
	call	bdos
	jmp	exit

setbuf:	lxi	h,buf
	mvi	b,128
	lda	seed
sb0:	mov	m,a
	inx	h
	adi	1
	daa
	djnz	sb0
	ret

xxxbuf:	lxi	h,buf
	mvi	b,128
	mvi	a,0ffh
xb0:	mov	m,a
	inx	h
	djnz	xb0
	ret

; Returns NZ if miscompare
; Error count in C
chkbuf:	lxi	h,buf
	mvi	b,128
	mvi	c,0
	lda	seed
cb0:	cmp	m
	jrz	cb1
	inr 	c
cb1:	inx	h
	adi	1
	daa
	djnz	cb0
	mov	a,c
	ora	a
	ret

dump:
	lxi	h,buf
	mvi	c,128/16
	lda	seed
dm2:	mvi	b,16
dm0:	push	psw
	cmp	m
	mvi	a,' '
	jrz	dm1
	mvi	a,'*'
dm1:	call	conout
	mov	a,m
	call	hexout
	inx	h
	pop	psw
	adi	1
	daa
	djnz	dm0
	push	psw
	call	crlf
	pop	psw
	dcr	c
	jrnz	dm2
	jmp	cpm

conbrk:	push	h
	push	d
	push	b
	mvi	e,0ffh
	mvi	c,dircon
	call	bdos
	pop	b
	pop	d
	pop	h
	ora	a
	rz
	cpi	CTLC
	rnz
	mvi	a,'*'
	call	conout
	call	crlf
	jmp	exit

conout:
	push	h
	push	d
	push	b
	mov	e,a
	mvi	c,dircon
	call	bdos
	pop	b
	pop	d
	pop	h
	ret

crlf:
	mvi	a,CR
	call	conout
	mvi	a,LF
	call	conout
	ret

wrdout:	mov	a,h
	call	hexout
	mov	a,l
hexout:	push	psw
	rlc
	rlc
	rlc
	rlc
	call	hex0
	pop	psw
hex0:	ani	0fh
	adi	90h
	daa
	aci	40h
	daa
	jmp	conout

; leading zeroes printed - must preserve B
decout:
	mvi	d,100
	call	divide
	mvi	d,10
	call	divide
	adi	'0'
	jmp	conout

divide:	mvi	e,0
div0:	sub	d
	inr	e
	jrnc	div0
	add	d
	dcr	e
	push	psw	; remainder
	mvi	a,'0'
	add	e
	call	conout
	pop	psw	; remainder
	ret

; Read (GET) data from chip.
; 'num', 'bsb', 'off' setup.
; Returns: 'buf' filled with 'num' bytes.
wizget:
	mvi	a,WZSCS
	out	spi$ctl
	lhld	off
	mov	a,h
	out	spi$wr
	mov	a,l
	out	spi$wr
	lda	bsb
	out	spi$wr
	in	spi$rd	; prime pump
	mvi	c,spi$rd
	lxi	h,buf
	lded	num
	mov	b,e
	mov	a,e
	ora	a
	jrz	wg0
	inir	; do partial page
	mov	a,d
	ora	a
	jrz	wg1
wg0:	inir
	dcr	d
	jrnz	wg0
wg1:	xra	a	; not SCS
	out	spi$ctl

; Write (SET) data in chip.
; 'num', 'buf', 'bsb', 'off' setup.
wizset:
	mvi	a,WZSCS
	out	spi$ctl
	lhld	off
	mov	a,h
	out	spi$wr
	mov	a,l
	out	spi$wr
	lda	bsb
	ori	WRITE
	out	spi$wr
	lda	num
	mov	b,a
	mvi	c,spi$wr
	lxi	h,buf
	outir
	xra	a	; not SCS
	out	spi$ctl
	ret

	ds	40
stack:	ds	0
usrstk:	dw	0

bsb:	db	0
off:	dw	0
num:	dw	0	; SET: one byte, GET: two bytes

buf:	ds	0

	end
