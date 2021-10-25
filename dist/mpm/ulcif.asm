	title	'NETWRKIF for Systems Running ULCnet'
	page	54

;***************************************************************************
;***************************************************************************
;**									  **
;**	S e r v e r   N e t w o r k   I n t e r f a c e   M o d u l e	  **
;**									  **
;***************************************************************************
;***************************************************************************


;***************************************************************************
;***************************************************************************
;**									  **
;**	This module performs communication operations on a server	  **
;**	equipped with Orange Compuco's ULCnet network adaptor.  	  **
;**	The actual communications protocol is proprietary to Orange 	  **
;**	Compuco.  It is included on the CP/NET release disk in REL	  **
;**	file format on a module called PBMAIN.REL.  PBMAIN and a data-	  **
;**	link interface module, DLIF, must be linked into the XIOS	  **
;**	as console I/O routines.  A sample DLIF is included with this	  **
;**	module.								  **
;**									  **
;**	This module performs the high-level transport and network 	  **
;**	processing, then calls the DLIF via a direct XIOS console I/O	  **
;**	function for data-link.  The following features are supported:	  **
;**									  **
;**		o  Queue Minimization using only 2 interface processes	  **
;**		o  Dynamic LOGIN/LOGOFF support				  **
;**									  **
;**	Very little of this routine needs to be modified to run an a	  **
;**	particular computer system.  The DLIF must be modified to 	  **
;**	support the system's particular RS-232 hardware, and the XIOS	  **
;**	must be modified to support interrupt-driven operation, if so	  **
;**	desired, and also support the pseudo-console drivers of the	  **
;**	DLIF.								  **
;**									  **
;***************************************************************************
;***************************************************************************

;	This software was developed jointly by
;
;		Digital Research, Inc.
;		P.O. Box 579
;		Pacific Grove, CA 93950
;	and
;		Keybrook Business Systems, Inc.
;		2035 National Avenue
;		Hayward, CA 94545


bdosadr:
	dw	$-$		; RSP XDOS entry point

; User-Configurable Parameters (These should be the only changes needed)

nmb$rqstrs	equ	2	; Number of requesters supported at one time
nmb$bufs	equ	3	; Number of message buffers
console$num	equ	20h	; Pseudo-console number
fmt$byte	equ	4bh	; Format byte: short format with acknowledge,
				;   153.6K baud self-clocked

; Message Buffer Offsets

fmt		equ	0		; format
did		equ	fmt+1		; destination ID
sid		equ	did+1		; source ID
fnc		equ	sid+1		; server function number
siz		equ	fnc+1		; size of message (normalized to 0)
msg		equ	siz+1		; message
buf$len		equ	msg+257		; length of total message buffer

; ULCnet Packet Offsets

ulc$fmt		equ	0		; packet format
ulc$v$circ	equ	ulc$fmt+1	; virtual circuit number
ulc$len$lo	equ	ulc$v$circ+1	; low order of length
ulc$len$hi	equ	ulc$len$lo+1	; high order of length
ulc$fnc		equ	ulc$len$hi+1	; start of message: function code
ulc$msg		equ	ulc$fnc+1	; CP/NET message

; Requester Control Block Offsets

rqstr$id	equ	0		; requester ID for this server
uqcb		equ	rqstr$id+1	; uqcb to queue to this server
buf$ptr		equ	uqcb+4		; queue message <--> msg buffer ptr
rcb$len		equ	buf$ptr+2	; length of requester control block


; NETWRKIF Process Descriptors and Stack Space

networkin:			; Receiver Process

	dw	0		; link
	db	0		; status
	db	66		; priority
	dw	netstkin+46	; stack pointer
	db	'NETWRKIN'	; name
	db	0		; console
	db	0ffh		; memseg
	ds	2		; b
	ds	2		; thread
	ds	2		; buff
	ds	1		; user code & disk slct
	ds	2		; dcnt
	ds	1		; searchl
	ds	2		; searcha
	ds	2		; active drives
	dw	0		; HL'
	dw	0		; DE'
	dw	0		; BC'
	dw	0		; AF'
	dw	0		; IY
	dw	0		; IX
	dw	0		; HL
	dw	0		; DE
	dw	0		; BC
	dw	0		; AF, A = ntwkif console dev #
	ds	2		; scratch

netstkin:
	dw	0c7c7h,0c7c7h,0c7c7h,0c7c7h
	dw	0c7c7h,0c7c7h,0c7c7h,0c7c7h
	dw	0c7c7h,0c7c7h,0c7c7h,0c7c7h
	dw	0c7c7h,0c7c7h,0c7c7h,0c7c7h
	dw	0c7c7h,0c7c7h,0c7c7h,0c7c7h
	dw	0c7c7h,0c7c7h,0c7c7h
	dw	setup

networkout:			; Transmitter Process

	dw	0		; link
	db	0		; status
	db	66		; priority
	dw	netstkou+46	; stack pointer
	db	'NETWRKOU'	; name
	db	0		; console
	db	0ffh		; memseg
	ds	2		; b
	ds	2		; thread
	ds	2		; buff
	ds	1		; user code & disk slct
	ds	2		; dcnt
	ds	1		; searchl
	ds	2		; searcha
	ds	2		; active drives
	dw	0		; HL'
	dw	0		; DE'
	dw	0		; BC'
	dw	0		; AF'
	dw	0		; IY
	dw	0		; IX
	dw	0		; HL
	dw	0		; DE
	dw	0		; BC
	dw	0		; AF, A = ntwkif console dev #
	ds	2		; scratch

netstkou:
	dw	0c7c7h,0c7c7h,0c7c7h,0c7c7h
	dw	0c7c7h,0c7c7h,0c7c7h,0c7c7h
	dw	0c7c7h,0c7c7h,0c7c7h,0c7c7h
	dw	0c7c7h,0c7c7h,0c7c7h,0c7c7h
	dw	0c7c7h,0c7c7h,0c7c7h,0c7c7h
	dw	0c7c7h,0c7c7h,0c7c7h
	dw	output


; Input queue control blocks

qcb$in$0:
	ds	2		; link
	db	'NtwrkQI0'	; name
	dw	2		; msglen
	dw	1		; nmbmsgs
	ds	2		; dqph
	ds	2		; nqph
	ds	2		; msgin
	ds	2		; msgout
	ds	2		; msgcnt
	ds	2		; buffer

	if	nmb$rqstrs ge 2
qcb$in$1:
	ds	2		; link
	db	'NtwrkQI1'	; name
	dw	2		; msglen
	dw	1		; nmbmsgs
	ds	2		; dqph
	ds	2		; nqph
	ds	2		; msgin
	ds	2		; msgout
	ds	2		; msgcnt
	ds	2		; buffer
	endif

	if	nmb$rqstrs ge 3
qcb$in$2:
	ds	2		; link
	db	'NtwrkQI2'	; name
	dw	2		; msglen
	dw	1		; nmbmsgs
	ds	2		; dqph
	ds	2		; nqph
	ds	2		; msgin
	ds	2		; msgout
	ds	2		; msgcnt
	ds	2		; buffer
	endif

	if	nmb$rqstrs ge 4 
qcb$in$3:
	ds	2		; link
	db	'NtwrkQI3'	; name
	dw	2		; msglen
	dw	1		; nmbmsgs
	ds	2		; dqph
	ds	2		; nqph
	ds	2		; msgin
	ds	2		; msgout
	ds	2		; msgcnt
	ds	2		; buffer
	endif

; Output queue control blocks

qcb$out$0:
	ds	2		; link
	db	'NtwrkQO0'	; name
	dw	2		; msglen
	dw	nmb$bufs	; nmbmsgs
	ds	2		; dqph
	ds	2		; nqph
	ds	2		; msgin
	ds	2		; msgout
	ds	2		; msgcnt
	ds	2*nmb$bufs+1	; buffer

; Requester Management Table

rqstr$table:

;requester 0 control block

	db	0ffh		; requester ID (marked not in use)
	dw	qcb$in$0	; UQCB:  QCB pointer
	dw	$+2		;	 pointer to queue message
	dw	$-$		; pointer to msg buffer (loaded on receive)

	if	nmb$rqstrs ge 2
;requester 1 control block

	db	0ffh		; requester ID (marked not in use)
	dw	qcb$in$1	; UQCB:  QCB pointer
	dw	$+2		;	 pointer to queue message
	dw	$-$		; pointer to msg buffer (loaded on receive)
	endif

	if	nmb$rqstrs ge 3
;requester 2 control block

	db	0ffh		; requester ID (marked not in use)
	dw	qcb$in$2	; UQCB:  QCB pointer
	dw	$+2		;	 pointer to queue message
	dw	$-$		; pointer to msg buffer (loaded on receive)
	endif

	if	nmb$rqstrs ge 4
;requester 3 control block

	db	0ffh		; requester ID (marked not in use)
	dw	qcb$in$3	; UQCB:  QCB pointer
	dw	$+2		;	 pointer to queue message
	dw	$-$		; pointer to msg buffer (loaded on receive)
	endif

; Output user queue control block

uqcb$out$0:
	dw	qcb$out$0	; pointer
	dw	out$buffer$ptr	; pointer to queue message

out$buffer$ptr:
	ds	2		; a queue read will return the message
				; buffer pointer in this location

; UQCB for flagging errors from receive process to send process

uqcb$in$out$0:
	dw	qcb$out$0	; pointer
	dw	in$out$buffer$ptr
				; pointer to queue message

in$out$buffer$ptr:
	ds	2		; this pointer used by input process to
				;  to output "server not logged in" errors

; Server Configuration Table

configtbl:
	db	0		; Server status byte
	db	0		; Server processor ID
	db	nmb$rqstrs	; Max number of requesters supported at once
	db	0		; Number of currently logged in requesters
	dw	0000h		; 16 bit vector of logged in requesters
	ds	16		; Logged In Requester processor ID's
	db	'PASSWORD' 	; login password

; Stacks for server processes.  A pointer to the associated process 
; descriptor area must reside on the top of each stack.  The stack for
; SERVR0PR is internal to SERVER.RSP, and is consequently omitted from the
; NETWRKIF module.

srvr$stk$len	equ	96h	; server process stack size

		if	nmb$rqstrs ge 2
srvr$stk$1:	ds	srvr$stk$len-2
		dw	srvr$1$pd
		endif

		if	nmb$rqstrs ge 3
srvr$stk$2:	ds	srvr$stk$len-2
		dw	srvr$2$pd
		endif

		if	nmb$rqstrs ge 4
srvr$stk$3:	ds	srvr$stk$len-2
		dw	srvr$3$pd
		endif

; Memory allocation for server process descriptor copydown
; All server process descriptor allocation must be contiguous

		if	nmb$rqstrs ge 2
srvr$1$pd:	ds	52
		endif

		if	nmb$rqstrs ge 3
srvr$2$pd:	ds	52
		endif

		if	nmb$rqstrs ge 4
srvr$3$pd:	ds	52
		endif


; Buffer Control Block: 0 indicates buffer is free for receiving a message
; 0ffh indicates that the buffer is in use

buf$cb:		rept	nmb$bufs
		db	0
		endm

; Message Buffer Storage Area

msg$buffers:	rept	nmb$bufs
		ds	buf$len
		endm

; save area for XIOS routine addresses

conin$jmp:
	db	jmp
conin:	dw	$-$

conout$jmp:
	db	jmp	
conout:	dw	$-$

constat$jmp:
	db	jmp	
constat:
	dw	$-$




; NETWRKIF Utility Routines

; Operating system linkage routine

monx:

	lhld	bdos$adr
	pchl


; Double word subtract: DE = HL - DE

dw$sub:
	mov	a,l
	sub	e
	mov	e,a
	mov	a,h
	sbb	d
	mov	d,a
	ret

; Routine to scan requester control blocks for a match with the received 
; source ID.
;
; Input:  A = Source ID to Match
;
; Output: 
;	success:  HL = pointer to requester control block
;		  A <> 0FFh
;	no match, but a free control block found:
;		  HL = pointer to RCB
;		   A = 0FFh
;		  CY = 0
;	no match and no available RCB's:
;		   A = 0FFh
;		  CY = 1

scan$table:

	lxi	h,rqstr$table		;point to the start of the RCB table
	mvi	b,nmb$rqstrs
	lxi	d,rcb$len		;size of RCB's for scanning the table

sc$t1:

	cmp	m			;RCB ID = SID?
	rz				;yes--> a match--> return

	dad	d			;else-->check next entry
	dcr	b
	jnz	sc$t1

	lxi	h,rqstr$table		;no match-->look for a free entry
	mvi	b,nmb$rqstrs

sc$t2:

	mov	a,m
	inr	a
	jz	sc$t3			;an unoccupied entry has been found

	dad	d			;else-->keep looking
	dcr	b
	jnz	sc$t2

	mvi	a,0ffh			;outa luck-->set the big error
	stc
	ret	

sc$t3:					;no match, but found a free entry

	dcr	a			;A=0FFh
	ora	a			;CY=0
	ret


; This routine free up a requester control block for somebody else who
; might want to Log In.
;
;	Input:  A = source ID that just logged off

free$rqstr$tbl:

	lxi	h,rqstr$table
	lxi	d,rcb$len

fr$t1:

	cmp	m
	jnz	fr$t2			;RCB ID <> SID-->keep scanning

	mvi	m,0ffh			;else-->mark it as unoccupied
	ret				;  and bug out

fr$t2:

	dad	d
	jmp	fr$t1			;keep going--it's in there somewhere



; Routine to send a message on the network
; Input:  HL = pointer to message buffer

send$msg:

	push	h
	mvi	m,fmt$byte		;set ulc$net format byte

	inx	h			;virtual circuit = requester ID

	inx	h
	inx	h

	mov	b,m			;save function number

	inx	h			;get SIZ
	mov	e,m

	mvi	d,0			;normalize CP/NET to ULCnet length
	inx	d
	inx	d

	mov	m,b			;put FNC in first message byte

	dcx	h			;store length
	mov	m,d
	dcx	h
	mov	m,e

	pop	b			;restore buffer pointer
	mvi	d,console$num		;set up fake console number for xios
	jmp	conout$jmp		;blast that packet


; Routine to receive a message on the network
; Input:  DE = pointer to buffer

rcv$message:

	mov	b,d
	mov	c,e
	push	b			;save buffer pointer
	mvi	d,console$num
	call	conin$jmp		;receive the message

	pop	h
	mvi	m,0			;FMT = 0 (requester to server)

	inx	h
	mov	b,m			;save rqstr ID = virtual circuit

	lda	configtbl+1
	mov	m,a			;DID = server ID

	inx	h
	mov	e,m			;get low order length

	mov	m,b			;SID = requester ID

	inx	h
	mov	d,m			;get hi order length

	dcx	d
	dcx	d			;normalize ULCnet to CP/NET SIZ

	inx	h
	mov	b,m			;get FNC

	mov	m,e			;store SIZ

	dcx	h
	mov	m,b			;store FNC	
	
	ret				;ULCnet message formatted





; Network I/F Receiver Process


setup:					;initialize NETWRKIF

	mvi	b,nmb$rqstrs+1		;loop counter for making n+1 queues
	mvi	c,134			;make queue function code
	lxi	d,qcb$in$0

makeq:					;make all input and output queue(s)

	push	b
	push	d
	call	monx

	pop	h
	lxi	d,26
	dad	d
	xchg

	pop	b
	dcr	b
	jnz	makeq
			
	mvi	c,154
	call	monx

	lxi	d,9			;write configuration table address
	dad	d			; into system data page, allowing
	lxi	d,configtbl		;  server initialization to proceed
	di
	mov	m,e
	inx	h
	mov	m,d
	ei

	dcx	h			;point to XIOS jump table page
	dcx	h
	dcx	h
	mov	h,m
	mvi	l,0

	lxi	d,6
	dad	d			;point to constat
	shld	constat

	inx	h
	inx	h
	inx	h			;point to conin
	shld	conin

	inx	h
	inx	h
	inx	h
	shld	conout			;point to conout

	mvi	d,console$num
	call	constat$jmp		;use constat to initialize ulcnet

	lxi	d,networkout		;create network I/F output process
	mvi 	c,144
	call	monx

input:					;input process loop

; Find a free buffer

	lxi	h,buf$cb		;point to buffer control block
	lxi	d,msg$buffers		;point to base of buffer area
	mvi	b,nmb$bufs		;get total number of buffers

input2:

	mov	a,m
	inr	a
	jnz	input3			;we found a free buffer-->use it

	push	h			;point to next buffer
	lxi	h,buf$len
	dad	d
	xchg

	pop	h			;point to next buffer control field
	inx	h

	dcr	b			;have we scanned all the buffers?
	jnz	input2

	mvi	c,142			;uh oh, we're all clogged up
	call	monx			;dispatch and go sleepy bye for a bit
	jmp	input			;try again

input3:

	mvi	m,0ffh			;found a buffer-->mark it used

	push	d

; Receive the message

	call	rcv$message

	pop	h
	push	h

	inx	h			;check requester table to see 
	inx	h			;  whether the source requester
	mov	a,m			;    is logged-in
	call	scan$table

	inr	a
	jz	input4			;not logged-in-->go check for login

input6:

	lxi	d,buf$ptr		;else-->update message buffer pointer
	dad	d

	pop	d
	mov	m,e
	inx	h
	mov	m,d

	lxi	d,uqcb-buf$ptr-1	;point to the uqcb for this requester
	dad	d
	xchg

	mvi	c,139			;write the message to the queue
	call	monx

	jmp	input			;round and round we go

input4:					;else-->requester not logged-in

	pop	d
	inx	d
	inx	d
	inx	d
	jc	input5			;bomb the message if there's no
					; table entries left

	ldax	d	
	cpi	64			;is it a login?
	jnz	input5

	dcx	d			;yes-->mark the control block with
	ldax	d			;  the source ID
	mov	m,a

	dcx	d			;go do the queue write
	dcx	d
	push	d
	jmp	input6

input5:					;flag a "not logged in" extended error

	xchg
	inx	h
	mvi	m,1			;set SIZ=1
	inx	h
	mvi	m,0ffh			;set return code to error
	inx	h
	mvi	m,0ch			;flag extended error 12

	lxi	d,fmt-msg-1
	dad	d			;point back at message start
	mvi	m,1			;format = 1

	inx	h			;swap DID and SID
	mov	a,m
	inx	h
	mov	b,m
	mov	m,a
	dcx	h
	mov	m,b
	dcx	h

	shld	in$out$buffer$ptr	;write buffer pointer to queue msg buf

	lxi	d,uqcb$in$out$0		;write to the queue
	mvi	c,139
	call	monx
	jmp	input			;try again



;  Network I/F transmitter process

output:

	lxi	d,uqcb$out$0		;read the output queue-->go sleepy
	mvi	c,137			;  bye until some server process
	call	monx			;    sends a response

	lhld	out$buffer$ptr	
	xchg
	push	d			;save message pointer

	lxi	h,fnc			;get message function code
	dad	d
	mov	a,m
	dcx	h

	cpi	65			;is it a logoff?
	jnz	output2

	mov	a,m			;load SID
	cz	free$rqstr$tbl		;yes-->free up the server process

output2:

	pop	h
	push	h
	call	send$msg		;send the message

	pop	h			;retrieve message pointer

	lxi	d,msg$buffers		;DE = pointer - message buffer base
	call	dw$sub

	lxi	b,buf$cb		;BC = DE/buf$len + buf$cb

output3:

	mov	a,e
	ora	d
	jz	output4

	xchg
	lxi	d,buf$len
	call	dw$sub
	inr	c
	jmp	output3

output4:

	xra	a
	stax	b			;free the buffer for re-use

	jmp	output			;transmission without end, amen

	end
