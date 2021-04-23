; Implementation of the Network Boot protocol

	maclib	z80

	public	netboot,unboot
	; from caller
	extrn	ldmsg,srvid
	; from linked SNIOS
	extrn	NTWKIN,NTWKST,CNFTBL,SNDMSG,RCVMSG,NTWKER,NTWKBT,NTWKDN,CFGTBL

false	equ	0
true	equ	not false

	$*MACRO

; offsets in msgbuf
FMT	equ	0
DID	equ	1
SID	equ	2
FNC	equ	3
SIZ	equ	4
DAT	equ	5

	cseg

error:	stc
	ret

unboot:	lda	init
	ora	a
	rz
	jmp	NTWKDN

; Called with HL=msgbuf, filled out for first message (boot request)
; FNC, SIZ, and DAT... must be valid
; Return CY on error, else HL=start address
netboot:
	push	h
	call	NTWKIN
	popix
	ora	a
	jrnz	error
	cma
	sta	init
loop:
	lda	srvid
	stx	a,DID
	lda	CFGTBL+1
	stx	a,SID
	mvix	0b0h,FMT
	call	netsr	; send request, receive response
	rc		; network error
	ldx	a,FMT
	cpi	0b1h
	jrnz	error	; invalid response
	ldx	a,FNC
	ora	a
	jrz	error	; NAK
	dcr	a
	jrz	ldtxt
	dcr	a
	jrz	stdma
	dcr	a
	jrz	load
	dcr	a
	jrnz	error	; unsupported function
	; done - execute boot code
	ldx	l,DAT
	ldx	h,DAT+1
	xra	a
	ret
load:	lhld	dma
	xchg
	pushix
	pop	h
	lxi	b,DAT
	dad	b
	lxi	b,128
	ldir
	xchg
	shld	dma
netack:
	mvix	0,FNC	; ACK, get next
	mvix	0,SIZ
	jr	loop
stdma:
	ldx	l,DAT
	ldx	h,DAT+1
	shld	dma
	jr	netack
ldtxt:
	pushix
	pop	h
	push	h
	lxi	b,DAT
	dad	b
	call	ldmsg
	popix
	jr	netack

; Returns CY on error
netsr:	; must preserve IX
	pushix
	pop	b
	push	b
	call	SNDMSG
	pop	b
	ora	a
	push	b
	cz	RCVMSG
	popix
	ora	a
	rz
	stc
	ret

	dseg
dma:	dw	0
init:	db	0

	end
