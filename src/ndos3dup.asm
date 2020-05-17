; Generic initialization code for NDOS3.
; Prevents duplicate NDOS3 loading.
;
	maclib	z80

cr	equ	13
lf	equ	10

; System page-0 constants
cpm	equ	0
bdos	equ	5

; BDOS functions
print	equ	9

; RSX is already linked-in, but might be a duplicate

	org	100h
	lxi	sp,stack

	lixd	bdos+1	; this should be our NDOS3
	sixd	us
	jmp	dup0
dup1:
	ldx	a,+18	; LOADER3?
	cpi	0ffh
	jz	ldr3
	call	chkdup
	lxi	d,dupmsg
	jz	rm$us	; duplicate NDOS3, remove "us"
dup0:
	ldx	l,+4	; next RSX...
	ldx	h,+5	;
	push	h
	popix
	jmp	dup1

; DE = message to print
rm$us:
	lixd	us
	mvix	0ffh,+8	; set remove flag
	; also short-circuit it
	ldx	l,+4	; next RSX...
	ldx	h,+5	;
	stx	l,+1	; by-pass duplicate
	stx	h,+2	;
	; report what happened
	mvi	c,print
	call	bdos
	jmp	cpm

; hit LOADER3 RSX, no dup found...
ldr3:
	jmp	cpm	; let RSX init itself

chkdup:	pushix
	pop	h
	lxi	d,10	; offset of name
	dad	d
	lxi	d,ndos3
	lxi	b,8
chk0:	ldax	d
	cmp	m
	rnz
	inx	h
	inx	d
	dcx	b
	mov	a,b
	ora	c
	jnz	chk0
	ret	; ZR = match

us:	dw	0	; our copy of NDOS3 (remove if dup)

dupmsg:	db	'NDOS3 already loaded',cr,lf,'$'
ndos3:	db	'NDOS3   '

	ds	64
stack:	ds	0

	end
