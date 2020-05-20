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

false	equ	0
true	equ	not false

cpnos	equ	true		; cp/nos system

DSC2	equ	false
DB82	equ	false
Altos	equ	true

always$retry	equ	true	; force continuous retries

modem	equ	false

ASCII	equ	false

debug	equ	false

	CSEG
	if	cpnos
	extrn	BDOS
	else
BDOS	equ	0005h
	endif

NIOS:
	public	NIOS
;	Jump vector for SNIOS entry points
	jmp	ntwrkinit	; network initialization
	jmp	ntwrksts	; network status
	jmp	cnfgtbladr	; return config table addr
	jmp	sendmsg		; send message on network
	jmp	receivemsg	; receive message from network
	jmp	ntwrkerror	; network error
	jmp	ntwrkwboot	; network warm boot

	if	DB82
slave$ID	equ	12h	; slave processor ID number
	endif
	if	DSC2
slave$ID	equ	34h
	endif
	if	Altos
slave$ID	equ	56h
	endif

	if	cpnos
;	Initial Slave Configuration Table
Initconfigtbl:
	db	0000$0000b	; network status byte
	db	slave$ID	; slave processor ID number
	db	84h,0		; A:  Disk device
	db	81h,0		; B:   "
	db	82h,0		; C:   "
	db	83h,0		; D:   "
	db	80h,0		; E:   "
	db	85h,0		; F:   "
	db	86h,0		; G:   "
	db	87h,0		; H:   "
	db	88h,0		; I:   "
	db	89h,0		; J:   "
	db	8ah,0		; K:   "
	db	8bh,0		; L:   "
	db	8ch,0		; M:   "
	db	8dh,0		; N:   "
	db	8eh,0		; O:   "
	db	8fh,0		; P:   "
	db	0,0		; console device
	db	0,0		; list device:
	db	0		;	buffer index
	db	0		;	FMT
	db	0		;	DID
	db	slave$ID	;	SID
	db	5		;	FNC
initcfglen equ	$-initconfigtbl
	endif

defaultmaster	equ	00h

wboot$msg:			; data for warm boot routine
	db	'<Warm Boot>'
	db	'$'

networkerrmsg:
	db	'Network Error'
	db	'$'


	page
	DSEG


;	Slave Configuration Table
configtbl:

Network$status:
	ds	1		; network status byte
	ds	1		; slave processor ID number
	ds	2		; A:  Disk device
	ds	2		; B:   "
	ds	2		; C:   "
	ds	2		; D:   "
	ds	2		; E:   "
	ds	2		; F:   "
	ds	2		; G:   "
	ds	2		; H:   "
	ds	2		; I:   "
	ds	2		; J:   "
	ds	2		; K:   "
	ds	2		; L:   "
	ds	2		; M:   "
	ds	2		; N:   "
	ds	2		; O:   "
	ds	2		; P:   "

	ds	2		; console device

	ds	2		; list device:
	ds	1		;	buffer index
	db	0		;	FMT
	db	0		;	DID
	db	Slave$ID	;	SID (CP/NOS must still initialize)
	db	5		;	FNC
	ds	1		;	SIZ
	ds	1		;	MSG(0)  List number
	ds	128		;	MSG(1) ... MSG(128)

msg$adr:
	ds	2		; message address
	if	modem
timeout$retries	equ 0		; timeout a max of 256 times
	else
timeout$retries equ 100		; timeout a max of 100 times
	endif
max$retries equ	10		; send message max of 10 times
retry$count:
	ds	1

FirstPass:
	db	0ffh

;	Network Status Byte Equates
;
active		equ	0001$0000b	; slave logged in on network
rcverr		equ	0000$0010b	; error in received message
senderr		equ	0000$0001b	; unable to send message

;	General Equates
;
SOH	equ	01h		; Start of Header
STX	equ	02h		; Start of Data
ETX	equ	03h		; End of Data
EOT	equ	04h		; End of Transmission
ENQ	equ	05h		; Enquire
ACK	equ	06h		; Acknowledge
LF	equ	0ah		; Line Feed
CR	equ	0dh		; Carriage Return
NAK	equ	15h		; Negative Acknowledge

conout	equ	2		; console output function
print	equ	9		; print string function
rcvmsg	equ	67		; receive message NDOS function
login	equ	64		; Login NDOS function

;	I/O Equates
;
	if	DB82
stati	equ	83h
mski	equ	08h
dprti	equ	80h

stato	equ	83h
msko	equ	10h
statc	equ	81h
mskc	equ	20h
dprto	equ	86h
	endif

	if	DSC2
	if	modem
stati	equ	59h
mski	equ	02h
dprti	equ	58h

stato	equ	59h
msko	equ	01h
dprto	equ	58h
	else
stati	equ	51h
mski	equ	02h
dprti	equ	50h

stato	equ	51h
msko	equ	01h
dprto	equ	50h
	endif
	endif

	if	Altos
stati	equ	1fh
mski	equ	01h
dprti	equ	1eh

stato	equ	1fh
msko	equ	04h
dprto	equ	1eh
	endif



	page
	CSEG
;	Utility Procedures
;
delay:				; delay for c[a] * 0.5 milliseconds
	mvi	a,6
delay1:
	mvi	c,86h
delay2:
	dcr	c
	jnz	delay2
	dcr	a
	jnz	delay1
	ret

	if	ASCII
Nib$out:			; A = nibble to be transmitted in ASCII
	cpi	10
	jnc	nibAtoF		; jump if A-F
	adi	'0'
	mov	c,a
	jmp	Char$out
nibAtoF:
	adi	'A'-10
	mov	c,a
	jmp	Char$out
	endif

Pre$Char$out:
	mov	a,d
	add	c
	mov	d,a		; update the checksum in D

nChar$out:			; C = byte to be transmitted
	if	Altos
	mvi	a,10h
	out	stato
	endif
	in	stato
	ani	msko
	jz	nChar$out

	if	DB82
	in	statc
	ani	mskc
	jz	nChar$out
	endif

	if	DSC2
	nop			; these NOP's make DB8/2 & DSC2
	nop			;  versions the same length - saves
	nop			;  a second listing
	nop
	nop
	nop
	nop
	endif

	mov	a,c
	out	dprto
	ret
;
Char$out:
	call	nChar$out
	if	Altos
	xthl! xthl! xthl! xthl
	xthl! xthl! xthl! xthl
	xthl! xthl! xthl! xthl  ;delay 54 usec
	ret
	else
	jmp	delay		; delay after each Char sent to Mstr
;	ret
	endif

	if	ASCII
Nib$in:				; return nibble in A register
	call	Char$in
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

xChar$in:
	mvi	b,100		; 100 ms  corresponds to longest possible
	jmp	char$in0 	;wait between master operations

Char$in:			; return byte in A register
				;  carry set on rtn if timeout
	if	modem
	mvi	b,0		; 256 ms = 7.76 chars @ 300 baud
	else
	if	Altos
	mvi	b,3		; 3 ms = 50 chars @ 125k baud
	else
	mvi 	b,50		; 50 ms = 50 chars @ 9600 baud
	endif
	endif
Char$in0:
	mvi	c,5ah
Char$in1:
	if	Altos
	mvi	a,0
	out	stati
	endif
	in	stati
	ani	mski
	jnz	Char$in2
	dcr	c
	jnz	Char$in1
	dcr	b
	jnz	Char$in0
	stc			; carry set for err cond = timeout
	ret
Char$in2:
	in	dprti
	ret			; rtn with raw char and carry cleared

Net$out:			; C = byte to be transmitted
				; D = checksum
	mov	a,d
	add	c
	mov	d,a

	if	ASCII
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
	jmp	Char$out
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

	if	ASCII
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
	call	Char$in		;receive byte in Binary mode
	rc
	endif

chks$in:
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

	page
;	Network Initialization
ntwrkinit:

	if	cpnos		; copy down network assignments
	lxi	h,Initconfigtbl
	lxi	d,configtbl
	mvi	c,initcfglen
initloop:
	mov	a,m
	stax	d
	inx	h
	inx	d
	dcr	c
	jnz	initloop		; initialize config tbl from ROM

	else
	mvi	a,slave$ID		;initialize slave ID byte
	sta	configtbl+1		;  in the configuration tablee
	endif

;	device initialization, as required

	if	Altos
	mvi	a,047h
	out	0eh
	mvi	a,1
	out	0eh
	endif

	if	DSC2 and modem
	mvi	a,0ceh
	out	stato
	mvi	a,027h
	out	stato
	endif

	if	cpnos
	call	loginpr			; login to a master
	endif

initok:
	xra	a			; return code is 0=success
	ret


	page
;	Network Status
ntwrksts:
	lda	network$status
	mov	b,a
	ani	not (rcverr+senderr)
	sta	network$status
	mov	a,b
	ret



;	Return Configuration Table Address
cnfgtbladr:
	lxi	h,configtbl
	ret


	page
;	Send Message on Network
sendmsg:			; BC = message addr
	mov	h,b
	mov	l,c		; HL = message address
	shld	msg$adr
re$sendmsg:
	mvi	a,max$retries
	sta	retry$count	; initialize retry count
send:
	lhld	msg$adr
	mvi	c,ENQ
	call	Char$out	; send ENQ to master
	mvi	d,timeout$retries
ENQ$response:
	call	Char$in
	jnc	got$ENQ$response
	dcr	d
	jnz	ENQ$response
	jmp	Char$in$timeout
got$ENQ$response:
	call	get$ACK0
	mvi	c,SOH
	mvi	e,5
	call	Msg$out		; send SOH FMT DID SID FNC SIZ
	xra	a
	sub	d
	mov	c,a
	call	net$out		; send HCS (header checksum)
	call	get$ACK
	dcx	h
	mov	e,m
	inx	h
	inr	e
	mvi	c,STX
	call	Msg$out		; send STX DB0 DB1 ...
	mvi	c,ETX
	call	Pre$Char$out	; send ETX
	xra	a
	sub	d
	mov	c,a
	call	Net$out		; send the checksum
	mvi	c,EOT
	call	nChar$out	; send EOT
	call	get$ACK		; (leave these
	ret			;              two instructions)

get$ACK:
	call	Char$in
	jc	send$retry 	; jump if timeout
get$ACK0:
	ani	7fh
	sui	ACK
	rz
send$retry:
	pop	h		; discard return address
	lxi	h,retry$count
	dcr	m
	jnz	send		; send again unles max retries
Char$in$timeout:
	mvi	a,senderr

	if	always$retry
	call	error$return
	jmp	re$sendmsg
	else
	jmp	error$return
	endif

	page
;	Receive Message from Network
receivemsg:			; BC = message addr
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

	if	always$retry
	call	error$return
	jmp	re$receivemsg
	else
	jmp	error$return
	endif

receive:
	lhld	msg$adr
	mvi	d,timeout$retries
receive$firstchar:
	call	xcharin
	jnc	got$firstchar
	dcr	d
	jnz	receive$firstchar
	pop	h		; discard receive$retry rtn adr
	jmp	receive$timeout
got$firstchar:
	ani	7fh
	cpi	ENQ		; Enquire?
	jnz	receive

	mvi	c,ACK
	call	nChar$out 	; acknowledge ENQ with an ACK

	call	Char$in
	rc			; return to receive$retry
	ani	7fh
	cpi	SOH		; Start of Header ?
	rnz			; return to receive$retry
	mov	d,a		; initialize the HCS
	mvi	e,5
	call	Msg$in
	rc			; return to receive$retry
	call	Net$in
	rc			; return to receive$retry
	jnz	bad$checksum
	call	send$ACK
	call	Char$in
	rc			; return to receive$retry
	ani	7fh
	cpi	STX		; Start of Data ?
	rnz			; return to receive$retry
	mov	d,a		; initialize the CKS
	dcx	h
	mov	e,m
	inx	h
	inr	e
	call	msg$in		; get DB0 DB1 ...
	rc			; return to receive$retry
	call	Char$in		; get the ETX
	rc			; return to receive$retry
	ani	7fh
	cpi	ETX
	rnz			; return to receive$retry
	add	d
	mov	d,a		; update CKS with ETX
	call	Net$in		; get CKS
	rc			; return to receive$retry
	call	Char$in		; get EOT
	rc			; return to receive$retry
	ani	7fh
	cpi	EOT
	rnz			; return to receive$retry
	mov	a,d
	ora	a		; test CKS
	jnz	bad$checksum
	pop	h		; discard receive$retry rtn adr
	lhld	msg$adr
	inx	h
	lda	configtbl+1
	sub	m
	jz	send$ACK 	; jump with A=0 if DID ok
	mvi	a,0ffh		; return code shows bad DID
send$ACK:
	push	psw		; save return code
	mvi	c,ACK
	call	nChar$out  	; send ACK if checksum ok
	pop	psw		; restore return code
	ret

bad$DID:
bad$checksum:
	mvi	c,NAK
	jmp	Char$out  	; send NAK on bad chksm & not max retries
;	ret

error$return:
	lxi	h,network$status
	ora	m
	mov	m,a
	call	ntwrkerror 	; perform any required device re-init.
	mvi	a,0ffh
	ret

ntwrkerror:
				;  perform any required device 
	ret			;     re-initialization

	page
;
ntwrkwboot:

;	This procedure is called each time the CCP is
;  	reloaded from disk.  This version prints "<WARM BOOT>"
;  	on the console and then returns, but anything necessary 
;       for restart can be put here.

 	mvi	c,9
	lxi	d,wboot$msg
	jmp	BDOS

	page
	if	cpnos
;
;	LOGIN to a Master
;
; Equates
;
buff	equ	0080h

readbf	equ	10

active	equ	0001$0000b

loginpr:
	mvi	c,initpasswordmsglen
	lxi	h,initpasswordmsg
	lxi	d,passwordmsg
copypassword:
	mov	a,m
	stax	d
	inx	h
	inx	d
	dcr	c
	jnz	copypassword
	mvi	c,print
	lxi	d,loginmsg
	call	BDOS
	mvi	c,readbf
	lxi	d,buff-1
	mvi	a,50h
	stax	d
	call	BDOS
	lxi	h,buff
	mov	a,m	; get # chars in the command tail
	ora	a
	jz	dologin ; default login if empty command tail
	mov	c,a	; A = # chars in command tail
	xra	a
	mov	b,a	; B will accumulate master ID
scanblnks:
	inx	h
	mov	a,m
	cpi	' '
	jnz	pastblnks ; skip past leading blanks
	dcr	c
	jnz	scanblnks
	jmp	prelogin ; jump if command tail exhausted
pastblnks:
	cpi	'['
	jz	scanMstrID
	mvi	a,8
	lxi	d,passwordmsg+5+8-1
	xchg
spacefill:
	mvi	m,' '
	dcx	h
	dcr	a
	jnz	spacefill
	xchg
scanLftBrkt:
	mov	a,m
	cpi	'['
	jz	scanMstrID
	inx	d
	stax	d	;update the password
	inx	h
	dcr	c
	jnz	scanLftBrkt
	jmp	prelogin
scanMstrID:
	inx	h
	dcr	c
	jz	loginerr
	mov	a,m
	cpi	']'
	jz	prelogin
	sui	'0'
	cpi	10
	jc	updateID
	adi	('0'-'A'+10) and 0ffh
	cpi	16
	jnc	loginerr
updateID:
	push	psw
	mov	a,b
	add	a
	add	a
	add	a
	add	a
	mov	b,a	; accum * 16
	pop	psw
	add	b
	mov	b,a
	jmp	scanMstrID

prelogin:
	mov	a,b

dologin:
	lxi	b,passwordmsg+1
	stax	b
	dcx	b
	call	sendmsg
	inr	a
	lxi	d,loginfailedmsg
	jz	printmsg
	lxi	b,passwordmsg
	call	receivemsg
	inr	a
	lxi	d,loginfailedmsg
	jz	printmsg
	lda	passwordmsg+5
	inr	a
	jnz	loginOK
	jmp	printmsg

loginerr:
	lxi	d,loginerrmsg
printmsg:
	mvi	c,print
	call	BDOS
	jmp	loginpr		; try login again

loginOK:
	lxi	h,network$status ; HL = status byte addr
	mov	a,m
	ori	active	; set active bit true
	mov	m,a
	ret

;
; Local Data Segment
;
loginmsg:
	db	cr,lf
	db	'LOGIN='
	db	'$'

initpasswordmsg:
	db	00h	; FMT
	db	00h	; DID Master ID #
	db	slave$ID ;SID
	db	40h	; FNC
	db	7	; SIZ
	db	'PASSWORD' ; password
initpasswordmsglen equ	$-initpasswordmsg


loginerrmsg:
	db	lf
	db	'Invalid LOGIN'
	db	'$'

loginfailedmsg:
	db	lf
	db	'LOGIN Failed'
	db	'$'

	DSEG
passwordmsg:
	ds	1	; FMT
	ds	1	; DID
	ds	1	; SID
	ds	1	; FNC
	ds	1	; SIZ
	ds	8	; DAT = password
	endif

	end
