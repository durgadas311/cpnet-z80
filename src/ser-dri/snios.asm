	title	'Requester Network I/O System for CP/NET 1.2'

;***************************************************************
;***************************************************************
;**                                                           **
;**  R e q u e s t e r   N e t w o r k   I / O   S y s t e m  **
;**                                                           **
;***************************************************************
;***************************************************************

;/*
;  Copyright (C) 1980, 1981, 1982
;  Digital Research
;  P.O. Box 579
;  Pacific Grove, CA 93950
;
;  Revised:  October 5, 1982
;*/

; May 24, 2020
; Modified for github/durgadas311/cpnet-z80 build environment.
	maclib	config

	public	NTWKIN,NTWKST,CNFTBL,SNDMSG,RCVMSG,NTWKER,NTWKBT,NTWKDN,CFGTBL
	extrn	sendby,check,recvby,recvbt

	CSEG
BDOS	equ	0005h

	maclib	z80

; Initial Slave Configuration Table - must be first in module
CFGTBL:
Network$status:
	db	0		; network status byte
	db	0ffh		; slave processor ID number
	dw	0		; A:  Disk device
	dw	0		; B:   "
	dw	0		; C:   "
	dw	0		; D:   "
	dw	0		; E:   "
	dw	0		; F:   "
	dw	0		; G:   "
	dw	0		; H:   "
	dw	0		; I:   "
	dw	0		; J:   "
	dw	0		; K:   "
	dw	0		; L:   "
	dw	0		; M:   "
	dw	0		; N:   "
	dw	0		; O:   "
	dw	0		; P:   "

	dw	0		; console device

	dw	0		; list device:
	db	0		;	buffer index
	db	0		;	FMT
	db	0		;	DID
	db	0ffh		;	SID (CP/NOS must still initialize)
	db	5		;	FNC
	db	0		;	SIZ
	db	0		;	MSG(0)  List number
msgbuf:	; temp message, do not disturb LST: header
	ds	128		;	MSG(1) ... MSG(128)

msg$adr:
	ds	2		; message address
retry$count:
	ds	1

;FirstPass:
;	db	0ffh

;wboot$msg:			; data for warm boot routine
;	db	'<Warm Boot>'
;	db	'$'

;networkerrmsg:
;	db	'Network Error'
;	db	'$'

;	Network Status Byte Equates
;
active		equ	0001$0000b	; slave logged in on network
rcverr		equ	0000$0010b	; error in received message
senderr		equ	0000$0001b	; unable to send message

;	General Equates
;
cSOH	equ	01h		; Start of Header
cSTX	equ	02h		; Start of Data
cETX	equ	03h		; End of Data
cEOT	equ	04h		; End of Transmission
cENQ	equ	05h		; Enquire
cACK	equ	06h		; Acknowledge
cNAK	equ	15h		; Negative Acknowledge

print	equ	9		; print string function

;	Utility Procedures
;
 if ASCII
Nib$out:			; A = nibble to be transmitted in ASCII
	adi	90h
	daa
	aci	40h
	daa
	jmp	sendby
 endif

Pre$Char$out:
	mov	a,d
	add	c
	mov	d,a		; update the checksum in D
	mov	a,c
	jmp	sendby

 if ASCII
Nib$in:				; return nibble in A register
	call	recvb0
	rc
	ani	7fh
	sui	'0'
	cpi	10
	jc	Nib$in$rtn 	; must be 0-9
	adi	('0'-'A'+10) and 0ffh
	cpi	16
	jc	Nib$in$rtn 	; must be 10-15
	lda	network$status
	ori	rcverr
	sta	network$status
	mvi	a,0
	stc			; carry set indicating err cond
	ret

Nib$in$rtn:
	ora	a		; clear carry & return
	ret
 endif

Net$out:			; C = byte to be transmitted
				; D = checksum
	mov	a,d
	add	c
	mov	d,a

 if ASCII
	mov	a,c
	mov	b,a
	rar
	rar
	rar
	rar
	ani	0FH		; mask HI-LO nibble to LO nibble
	call	Nib$out
	mov	a,b
	ani	0FH
	jmp	Nib$out
 else
	mov	a,c
	jmp	sendby
 endif

Msg$in:				; HL = destination address
				; E  = # bytes to input
	call	Net$in
	rc
	mov	m,a
	inx	h
	dcr	e
	jnz	Msg$in
	ret

Net$in:				; byte returned in A register
				; D  = checksum accumulator

 if ASCII
	call	Nib$in
	rc
	add	a
	add	a
	add	a
	add	a
	push	psw
	call	Nib$in
	pop	b
	rc
	ora	b

 else
	call	recvby		;receive byte in Binary mode
	rc
 endif
	mov	b,a
	add	d		; add & update checksum accum.
	mov	d,a
	ora	a		; set cond code from checksum
	mov	a,b
	ret

Msg$out:			; HL = source address
				; E  = # bytes to output
				; D  = checksum
				; C  = preamble byte
	mvi	d,0		; initialize the checksum
	call	Pre$Char$out 	; send the preamble character
Msg$out$loop:
	mov	c,m
	inx	h
	call	Net$out
	dcr	e
	jnz	Msg$out$loop
	ret

;	Network Initialization
NTWKIN:
	call	check	; also init if needed
	jc	initerr
	; Send "BDOS Func 255" message to other end,
	; Response will tell us our, and their, node ID
	lxix	msgbuf
	mvix	0,+0	; FMT
	mvix	0ffh,+3	; BDOS Func
	mvix	0,+4	; Size
	lxi	b,msgbuf
	call	sndmsg0	; avoid active check
	ora	a
	jnz	initerr
	lxi	b,msgbuf
	call	rcvmsg0	; avoid active check
	ora	a
	jnz	initerr
	lda	msgbuf+1	; our node ID
	lxix	CFGTBL
	stx	a,+1		; our slave (client) ID
	mvix	active,+0	; network status byte
	xra	a
	stx	a,+36+7	; clear SIZ - discard LST output
	ret
initerr:
	mvi	a,0ffh
	ret


;	Network Status
NTWKST:
	lda	network$status
	mov	b,a
	ani	not (rcverr+senderr)
	sta	network$status
	mov	a,b
	ret



;	Return Configuration Table Address
CNFTBL:
	lxi	h,CFGTBL
	ret


;	Send Message on Network
SNDMSG:			; BC = message addr
	; TODO: check status 'active'?
sndmsg0:
	mov	h,b
	mov	l,c		; HL = message address
	shld	msg$adr
	lda	CFGTBL+1
	inx	b
	inx	b
	stax	b	; SID
re$sendmsg:
	mvi	a,max$retries
	sta	retry$count	; initialize retry count
send:
	lhld	msg$adr
	mvi	a,cENQ
	call	sendby		; send ENQ to master
	mvi	d,timeout$retries
ENQ$response:
	call	recvby
	jnc	got$ENQ$response
	dcr	d
	jnz	ENQ$response
	jmp	Char$in$timeout
got$ENQ$response:
	call	get$ACK0
	mvi	c,cSOH
	mvi	e,5
	call	Msg$out		; send SOH FMT DID SID FNC SIZ
	xra	a
	sub	d
	mov	c,a
	call	Net$out		; send HCS (header checksum)
	call	get$ACK
	dcx	h
	mov	e,m
	inx	h
	inr	e
	mvi	c,cSTX
	call	Msg$out		; send STX DB0 DB1 ...
	mvi	c,cETX
	call	Pre$Char$out	; send ETX
	xra	a
	sub	d
	mov	c,a
	call	Net$out		; send the checksum
	mvi	a,cEOT
	call	sendby		; send EOT
	call	get$ACK		; (leave these
	ret			;              two instructions)

get$ACK:
	call	recvby
	jc	send$retry 	; jump if timeout
get$ACK0:
	ani	7fh
	sui	cACK
	rz
send$retry:
	pop	h		; discard return address
	lxi	h,retry$count
	dcr	m
	jnz	send		; send again unles max retries
Char$in$timeout:
	mvi	a,senderr

 if always$retry
	call	error$return
	jmp	re$sendmsg
 else
	jmp	error$return
 endif

;	Receive Message from Network
RCVMSG:			; BC = message addr
	; TODO: check status 'active'?
rcvmsg0:
	mov	h,b
	mov	l,c		; HL = message address
	shld	msg$adr
re$receivemsg:
	mvi	a,max$retries
	sta	retry$count	; initialize retry count
re$call:
	call	receive		; rtn from receive is receive error

receive$retry:
	lxi	h,retry$count
	dcr	m
	jnz	re$call
receive$timeout:
	mvi	a,rcverr

 if always$retry
	call	error$return
	jmp	re$receivemsg
 else
	jmp	error$return
 endif

receive:
	lhld	msg$adr
	mvi	d,timeout$retries
receive$firstchar:
	call	recvbt
	jnc	got$firstchar
	dcr	d
	jnz	receive$firstchar
	pop	h		; discard receive$retry rtn adr
	jmp	receive$timeout
got$firstchar:
	ani	7fh
	cpi	cENQ		; Enquire?
	jnz	receive

	mvi	a,cACK
	call	sendby	 	; acknowledge ENQ with an ACK

	call	recvby
	rc			; return to receive$retry
	ani	7fh
	cpi	cSOH		; Start of Header ?
	rnz			; return to receive$retry
	mov	d,a		; initialize the HCS
	mvi	e,5
	call	Msg$in
	rc			; return to receive$retry
	call	Net$in
	rc			; return to receive$retry
	jnz	bad$checksum
	call	send$ACK
	call	recvby
	rc			; return to receive$retry
	ani	7fh
	cpi	cSTX		; Start of Data ?
	rnz			; return to receive$retry
	mov	d,a		; initialize the CKS
	dcx	h
	mov	e,m
	inx	h
	inr	e
	call	Msg$in		; get DB0 DB1 ...
	rc			; return to receive$retry
	call	recvby		; get the ETX
	rc			; return to receive$retry
	ani	7fh
	cpi	cETX
	rnz			; return to receive$retry
	add	d
	mov	d,a		; update CKS with ETX
	call	Net$in		; get CKS
	rc			; return to receive$retry
	call	recvby		; get EOT
	rc			; return to receive$retry
	ani	7fh
	cpi	cEOT
	rnz			; return to receive$retry
	mov	a,d
	ora	a		; test CKS
	jnz	bad$checksum
	pop	h		; discard receive$retry rtn adr
	lhld	msg$adr
	inx	h
	lda	CFGTBL+1
	inr	a	; FF => 00
	jz	send$ACK
	dcr	a	; restore value
	sub	m
	jz	send$ACK 	; jump with A=0 if DID ok
	mvi	a,0ffh		; return code shows bad DID
send$ACK:
	push	psw		; save return code
	mvi	a,cACK
	call	sendby	  	; send ACK if checksum ok
	pop	psw		; restore return code
	ret

bad$checksum:
	mvi	a,cNAK
	jmp	sendby	  	; send NAK on bad chksm & not max retries
;	ret

error$return:
	lxi	h,network$status
	ora	m
	mov	m,a
	call	ntwrkerror 	; perform any required device re-init.
	mvi	a,0ffh
	ret

NTWKER:
ntwrkerror:
				;  perform any required device 
	ret			;     re-initialization

;
NTWKBT:

;	This procedure is called each time the CCP is
;  	reloaded from disk.  This version prints "<WARM BOOT>"
;  	on the console and then returns, but anything necessary 
;       for restart can be put here.

; 	mvi	c,print
;	lxi	d,wboot$msg
;	jmp	BDOS
	xra	a
	ret

NTWKDN:	; shutdown server - FNC=254 (no response)
	lxix	msgbuf
	mvix	0,+0	; FMT
	mvix	0feh,+3	; BDOS Func
	mvix	0,+4	; Size
	lxi	b,msgbuf
	call	sndmsg0	; avoid active check
	xra	a
	ret

	end
