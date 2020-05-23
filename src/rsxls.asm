; Generic RSX list utility.
; Lists all installed RSXs
;
;	rsxls	= short listing (names only)
;	rsxls l	= long listing (details)
;
; Always lists in order "bottom to top" (LOADER3 last)
	maclib	z80

cr	equ	13
lf	equ	10

; System page-0 constants
cpm	equ	0
bdos	equ	5
deffcb	equ	5ch
defdma	equ	80h

; BDOS functions
conout	equ	2
print	equ	9

; LOADER3 is always installed at this point.

	org	100h
	lxi	sp,stack

	lda	deffcb+1
	cpi	'L'
	lxi	d,header
	mvi	c,print
	cz	bdos

	lixd	bdos+1
	; check for no RSXs
	ldx	a,+3
	cpi	0c3h	; JMP?
	jnz	none	; SID/etc?
	;might be RESBDOS3
	ldx	a,+6
	cpi	0c3h	; JMP?
	jz	none	; RESBDOS3...
dup1:
	call	show
	ldx	a,+18	; LOADER3?
	cpi	0ffh
	jz	done
	ldx	l,+4	; next RSX...
	ldx	h,+5	;
	push	h
	popix
	jmp	dup1

norsx:	db	'No RSXs loaded',cr,lf,'$'

none:	lxi	d,norsx
	mvi	c,print
	call	bdos
done:	jmp	cpm

show:	lda	deffcb+1
	cpi	'L'
	jrz	long
	call	pname
	call	crlf
	ret

header:	db	cr,lf
	db	'ADDR NAME     PREV RM BK LD'
	db	cr,lf,'$'

long:	call	rsxadr
	call	blank
	call	pname
	call	blank
	call	prev
	call	blank
	call	remove
	call	blank
	call	banked
	call	blank
	call	loader
	call	crlf
	ret

pname:	pushix
	pop	h
	lxi	d,10	; offset of name
	dad	d
	mvi	b,8
name0:	mov	a,m
	call	chrout
	inx	h
	djnz	name0
	ret

prev:	ldx	l,+6	; offset of prev
	ldx	h,+7	;
	jmp	hexadr

remove:	ldx	a,+8	; offset of remove flag
	jmp	hexout

banked:	ldx	a,+9	; offset of banked flag
	jmp	hexout

loader:	ldx	a,+18	; offset of first loader byte
	call	hexout
	mvi	a,','
	call	chrout
	ldx	a,+19	; second loader byte
	call	hexout
	mvi	a,','
	call	chrout
	ldx	a,+19	; third loader byte
	jmp	hexout

; print address of current RSX
rsxadr:	pushix
	pop	h
	;jmp	hexadr
; print HL as hex
hexadr:	mov	a,h
	call	hexout
	mov	a,l
	;jmp	hexout
; print A in hex
hexout:	push	psw
	rlc
	rlc
	rlc
	rlc
	call	hexdig
	pop	psw
	;jmp	hexdig
hexdig:	ani	0fh
	adi	90h
	daa
	aci	40h
	daa
	;jmp	chrout
chrout:	pushix
	push	h
	push	d
	push	b
	mov	e,a
	mvi	c,conout
	call	bdos
	pop	b
	pop	d
	pop	h
	popix
	ret

crlf:	mvi	a,cr
	call	chrout
	mvi	a,lf
	jr	chrout

blank:	mvi	a,' '
	jr	chrout

	ds	64
stack:	ds	0

	end
