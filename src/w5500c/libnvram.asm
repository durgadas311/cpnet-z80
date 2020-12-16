; NVRAM library
	public	cksum32, vcksum, scksum, nvget

	maclib	z80

spi	equ	40h

spi?dat	equ	spi+0
spi?ctl	equ	spi+1
spi?sts	equ	spi+1

NVSCS	equ	10b	; SCS for NVRAM

; NVRAM/SEEPROM commands
NVRD	equ	00000011b
NVWR	equ	00000010b
RDSR	equ	00000101b
WREN	equ	00000110b
; NVRAM/SEEPROM status bits
WIP	equ	00000001b

	cseg

; IX = buffer, BC = length
; return: HL = cksum hi, DE = cksum lo
cksum32:
	lxi	h,0
	lxi	d,0
cks0:	ldx	a,+0
	inxix
	add	e
	mov	e,a
	jrnc	cks1
	inr	d
	jrnz	cks1
	inr	l
	jrnz	cks1
	inr	h
cks1:	dcx	b
	mov	a,b
	ora	c
	jrnz	cks0
	ret

; Validates checksum in buffer IX
; return: NZ on checksum error
; a checksum of 00 00 00 00 means the buffer was all 00,
; which is invalid.
vcksum:
	pushix
	lxi	b,508
	call	cksum32	; HL:DE is checksum
	popix
	lxi	b,500	; get IX displacement in range...
	dadx	b
	ldx	c,+10
	ldx	b,+11
	mov	a,b	;
	ora	c	; check first half zero
	dsbc	b
	rnz
	ldx	c,+08
	ldx	b,+09
	ora	b	;
	ora	c	; check second half zero
	xchg
	dsbc	b	; CY is clear
	rnz
	ora	a	; was checksum all zero?
	jrz	vcksm0
	xra	a	; ZR
	ret
vcksm0:	inr	a	; NZ
	ret

; Sets checksum in buffer IX
; Destroys (all)
scksum:
	pushix
	lxi	b,508
	call	cksum32
	popix
	lxi	b,500	; get IX displacement in range...
	dadx	b
	stx	l,+10
	stx	h,+11
	stx	e,+08
	stx	d,+09
	ret

; IX=buffer, HL = nvram address, DE = length
nvget:
	mvi	a,NVSCS
	out	spi?ctl
	mvi	a,NVRD
	out	spi?dat
	mov	a,h
	out	spi?dat
	mov	a,l
	out	spi?dat
	in	spi?dat	; prime pump
	mvi	c,spi?dat
	mov	a,e
	ora	a
	jz	nvget1
	inr	d	; TODO: handle 64K... and overflow of 'buf'...
nvget1:	pushix
	pop	h
	mov	b,e
nvget0:	inir	; B = 0 after
	dcr	d
	jrnz	nvget0
	xra	a	; not SCS
	out	spi?ctl
	ret

	end
