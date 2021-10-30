;***************************************************************************
;***************************************************************************
;**									  **
;**	S e r v e r   N e t w o r k   I n t e r f a c e   M o d u l e	  **
;**		BANKED PORTION						  **
;**									  **
;***************************************************************************
;***************************************************************************

	; This must be linked with a suitable NIOS.REL
	public	CFGADR
	extrn	NTWKIN, NTWKST, SNDMSG, RCVMSG, NWPOLL, NTWKER, NTWKDN

;***************************************************************************
;***************************************************************************
;**									  **
;**	This module performs communication operations on a server	  **
;**	equipped with a WizNET W5500 Ethernet network adaptor.  	  **
;**									  **
;***************************************************************************
;***************************************************************************
	maclib cfgnwif

	cseg
resadr:	dw	$-$		; pointer to RES part
	dw	stk0		; stack pointer
	db	'NETWRKIB'	; descriptive name

; Stack area for this process:
	dw	0c7c7h,0c7c7h,0c7c7h,0c7c7h
	dw	0c7c7h,0c7c7h,0c7c7h,0c7c7h
	dw	0c7c7h,0c7c7h,0c7c7h,0c7c7h
	dw	0c7c7h,0c7c7h,0c7c7h,0c7c7h
	dw	0c7c7h,0c7c7h,0c7c7h,0c7c7h
	dw	0c7c7h,0c7c7h,0c7c7h
stk0:	dw	setup

rqstr$table:
;requester 0 control block
	db	0ffh		; requester ID (marked not in use)
	dw	$-$		; UQCB:  QCB pointer
	dw	$+2		;	 pointer to queue message
	dw	$-$		; pointer to msg buffer (loaded on receive)
rqtb$len equ	$-rqstr$table
;requester 1 control block
	db	0ffh		; requester ID (marked not in use)
	dw	$-$		; UQCB:  QCB pointer
	dw	$+2		;	 pointer to queue message
	dw	$-$		; pointer to msg buffer (loaded on receive)
;requester 2 control block
	db	0ffh		; requester ID (marked not in use)
	dw	$-$		; UQCB:  QCB pointer
	dw	$+2		;	 pointer to queue message
	dw	$-$		; pointer to msg buffer (loaded on receive)
;requester 3 control block
	db	0ffh		; requester ID (marked not in use)
	dw	$-$		; UQCB:  QCB pointer
	dw	$+2		;	 pointer to queue message
	dw	$-$		; pointer to msg buffer (loaded on receive)
;requester 4 control block
	db	0ffh		; requester ID (marked not in use)
	dw	$-$		; UQCB:  QCB pointer
	dw	$+2		;	 pointer to queue message
	dw	$-$		; pointer to msg buffer (loaded on receive)
;requester 5 control block
	db	0ffh		; requester ID (marked not in use)
	dw	$-$		; UQCB:  QCB pointer
	dw	$+2		;	 pointer to queue message
	dw	$-$		; pointer to msg buffer (loaded on receive)
;requester 6 control block
	db	0ffh		; requester ID (marked not in use)
	dw	$-$		; UQCB:  QCB pointer
	dw	$+2		;	 pointer to queue message
	dw	$-$		; pointer to msg buffer (loaded on receive)

; Output user queue control block
uqcb$out$0:
	dw	$-$		; pointer to QCB
	dw	out$buffer$ptr	; pointer to queue message

out$buffer$ptr:
	ds	2		; a queue read will return the message
				; buffer pointer in this location

; Buffer Control Block: 0 indicates buffer is free for receiving a message
; 0ffh indicates that the buffer is in use

buf$cb:		rept	nmb$bufs
		db	0
		endm

; Message Buffer Storage Area

msg$buffers:	rept	nmb$bufs
		ds	M$LEN
		endm

; NETWRKIF Utility Routines
bdos$adr:	dw	$-$
CFGADR:		dw	$-$

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
	lxi	d,rqtb$len		;size of RCB's for scanning the table
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

; This routine frees up a requester control block for somebody else who
; might want to Log In.
;
;	Input:  A = source ID that just logged off
free$rqstr$tbl:
	lxi	h,rqstr$table
	lxi	d,rqtb$len
fr$t1:
	cmp	m
	jnz	fr$t2			;RCB ID <> SID-->keep scanning
	mvi	m,0ffh			;else-->mark it as unoccupied
	ret				;  and bug out
fr$t2:
	dad	d
	jmp	fr$t1			;keep going--it's in there somewhere



; Network I/F Receiver Process


setup:					;initialize NETWRKIF
	lhld	resadr
	mov	e,m
	inx	h
	mov	d,m
	xchg
	shld	bdos$adr	; snag a copy for easier use
	; To avoid having to open all the queues, manually fixup
	; the UQCB structures to point at QCBs
	mvi	c,getpdf
	call	monx
	; HL = 'networkio' in RESNWIF.RSP
	lxi	d,P$LEN
	dad	d	; point to qcb$in$0
	push	d
	lxi	d,rqstr$table+1	; UQCB0.Q$PTR
	mvi	a,nmb$rqstrs
setup0:	xchg
	mov	m,e
	inx	h
	mov	m,d	; set UQCB0.Q$PTR = qcb$in$0 ...
	lxi	b,rqtb$len-1	; sizeof rqstr$table[]-1
	dad	b
	xchg
	lxi	b,qcb$in$len	; sizeof input QCB
	dad	b
	dcr	a
	jnz	setup0
	; HL = qcb$out$0
	shld	uqcb$out$0
	lxi	d,qcb$in$len+qcb$out$buf-2
	dad	d	; HL = CFGTBL
	shld	CFGADR

	; There are 'nmb$rqstrs' qcb$in queues plus 1 qcb$out.
	mvi	b,nmb$rqstrs+1		;loop counter for making n+1 queues
	mvi	c,makeqf		;make queue function code
	pop	d	;qcb$in$0
makeq:					;make all input and output queue(s)
	push	b
	push	d
	call	monx
	pop	h
	lxi	d,qcb$in$len
	dad	d
	xchg
	pop	b
	dcr	b
	jnz	makeq
	mvi	c,sysdatf
	call	monx
	lxi	d,S$CPNET		;write configuration table address
	dad	d			; into system data page, allowing
	xchg				;  server initialization to proceed
	lhld	CFGADR
	xchg
	di
	mov	m,e
	inx	h
	mov	m,d
	ei
	call	NTWKIN
;	ora	a
;	jnz	error	; TODO: how? what?
	jmp	poll0	; start polling everything...

poll:	; main I/O polling loop
	mvi	c,dispatf
	call	monx			;dispatch and go sleepy bye for a bit
poll0:
	lxi	d,uqcb$out$0		;read the output queue...
	mvi	c,crdqf			; non-blocking read queue
	call	monx			;
	ora	a	; NZ = no message
	jnz	input
	; we have output to process...
	lhld	out$buffer$ptr	
	xchg
	push	d			;save message pointer
	lxi	h,fnc			;get message function code
	dad	d
	mov	a,m
	dcx	h
	cpi	logoutf			;is it a logoff?
	jnz	output2
	; BUG? This is a *response* to a LOGOFF... need DID not SID?
	mov	a,m			;load SID
	call	free$rqstr$tbl		;yes-->free up the server process
output2:
	pop	b
	push	b
	call	SNDMSG
	; TODO: handle errors?
	pop	h			;retrieve message pointer
	lxi	d,msg$buffers		;DE = pointer - message buffer base
	call	dw$sub
	lxi	b,buf$cb		;BC = DE/buf$len + buf$cb
output3:
	mov	a,e
	ora	d
	jz	output4
	xchg
	lxi	d,M$LEN
	call	dw$sub
	inr	c
	jmp	output3
output4:
	xra	a
	stax	b			;free the buffer for re-use
	jmp	poll	; TODO: flush all output before handling input?

input:
	call	NWPOLL
	ora	a
	jz	poll	; nothing to receive...
	; TODO: process all? or just one?
input0:
	; find a free buffer...
	lxi	h,buf$cb		;point to buffer control block
	lxi	d,msg$buffers		;point to base of buffer area
	mvi	b,nmb$bufs		;get total number of buffers
input2:
	mov	a,m
	inr	a
	jnz	input3			;we found a free buffer-->use it
	push	h			;point to next buffer
	lxi	h,M$LEN
	dad	d
	xchg
	pop	h			;point to next buffer control field
	inx	h
	dcr	b			;have we scanned all the buffers?
	jnz	input2
	; no free buffers - can't receive anything...
	jmp	poll
input3:
	mvi	m,0ffh			;found a buffer-->mark it used
	push	h	; BCB ptr
	push	d	; MSGBUF
; Receive the message
	mov	b,d
	mov	c,e
	call	RCVMSG
	; if error, we don't have a message to process.
	; free buffer and move on...
	ora	a
	pop	h	; MSGBUF
	jnz	input8
	push	h
	inx	h			;check requester table to see 
	inx	h			;  whether the source requester
	mov	a,m			;    is logged-in
	call	scan$table		; get rqstr$table entry
	inr	a
	jz	input4			;not logged-in-->go check for login
	; stack: MSGBUF, BCB ptr
input6:
	; stack: MSGBUF, BCB ptr
	; HL = rqstr$table
	lxi	d,rqtb$len-2		;else-->update message buffer pointer
	dad	d
	pop	d	; MSGBUF
	mov	m,e
	inx	h
	mov	m,d
	lxi	d,-(rqtb$len-2+1)	;back to the uqcb for this requester
	dad	d
	xchg
	mvi	c,writqf		;write the message to the queue
	call	monx
	pop	h	; BCB ptr
	jmp	poll

input4:					;else-->requester not logged-in
	; stack: MSGBUF, BCB ptr
	pop	d	; MSGBUF
	inx	d
	inx	d
	inx	d
	jc	input5			;bomb the message if there's no space
	ldax	d	; FNC
	cpi	loginf			;is it a login?
	jnz	input5
	dcx	d			;yes-->mark the control block with
	ldax	d			;  the source ID
	mov	m,a
	dcx	d			;go do the queue write
	dcx	d
	push	d	; MSGBUF back on stack
	jmp	input6

input5:					;flag a "not logged in" extended error
	; stack: BCB ptr
	; DE = MSGBUF
	xchg
	inx	h
	mvi	m,1			;set SIZ=1
	inx	h
	mvi	m,0ffh			;set return code to error
	inx	h
	mvi	m,0ch			;flag extended error 12
	lxi	d,-(DAT+1)
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
	; TODO: just send it now? why not?
	mov	b,h
	mov	c,l
	call	SNDMSG
	; TODO: error handling?
input8:
	pop	h	; BCB ptr
	; free buffer - we're done with it.
	mvi	m,0	; mark buffer free
	jmp	poll	;try again

	end
