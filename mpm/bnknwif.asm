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

rqtb$len equ	7	; caution when changing this:
			; init routine must also change.
; rqstr$table struct:
;	ds	1	; requester NID or 0ffh, init to 0ffh
;	ds	2	; UQCB.POINTER, init to qcb$in$X
;	ds	2	; UQCB.MSGPTR, init to $+2 (msgptr buffer)
;	ds	2	; msgptr buffer, set by readqf
; This table associates requesters with server processes (NtwrkQI)
rqstr$table:
	rept	nmb$rqstrs
	ds	rqtb$len
	endm

; Output user queue control block (initialized, not opened)
uqcb$out$0:
	dw	$-$		; pointer to QCB (init to qcb$out$0)
	dw	out$buffer$ptr	; pointer to queue message
out$buffer$ptr:
	ds	2		; a queue read will return the message
				; buffer pointer in this location

; Buffer Control Block:
; 000h indicates buffer is free for receiving a message,
; 0ffh indicates that the buffer is in use
buf$cb:	rept	nmb$bufs
	db	0
	endm

; Message Buffer Storage Area, allocaed via buf$cb
msg$buffers:	rept	nmb$bufs
		ds	M$LEN
		endm

bdos$adr:	dw	$-$
CFGADR:		dw	$-$

qcbname:	db	'NtwrkQIX'

; NETWRKIF Utility Routines

; Operating system linkage routine
monx:	lhld	bdos$adr
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

; DE = qcb$in$X, A = nmb$rqstrs-X
; Must preserve HL, DE, A
init$iqcb:
	push	h
	push	d
	push	psw
	mov	c,a
	mvi	a,nmb$rqstrs
	sub	c
	mov	c,a
	xchg
	inx	h
	inx	h	; QCB.NAME
	lxi	d,qcbname
	mvi	b,7	; all but the 'X'
iq0:	ldax	d
	mov	m,a
	inx	d
	inx	h
	dcr	b
	jnz	iq0
	mov	a,c
	adi	90h
	daa
	aci	40h
	daa
	mov	m,a	; 'X': 0..F
	inx	h	; QCB.MSGLEN
	xra	a
	mvi	m,2
	inx	h
	mov	m,a
	inx	h	; QCB.NMBMSGS
	mvi	m,1
	inx	h
	mov	m,a
	pop	psw
	pop	d
	pop	h
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



; Initial Network I/F Receiver Process (initialize all else)
setup:		;initialize NETWRKIF
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
	push	d	; save qcb$in$0 for makeqf loop
	lxi	d,rqstr$table
	mvi	a,nmb$rqstrs
setup0:	xchg	; DE = qcb$in$X, A = nmb$rqstrs-X
	call	init$iqcb
	mvi	m,0ffh	; no requester (yet)
	inx	h
	mov	m,e
	inx	h
	mov	m,d	; set UQCB0.POINTER = qcb$in$X
	inx	h
	; get $+2... set in UQCB.MSGADR
	push	d
	mov	e,l
	mov	d,h
	inx	d
	inx	d
	mov	m,e
	inx	h
	mov	m,d
	inx	h
	pop	d
	inx	h
	inx	h	; next rqstr$table entry
	xchg
	lxi	b,qcb$in$len	; sizeof input QCB
	dad	b		; qcb$in$X = next
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
	pop	d	; DE = qcb$in$0
makeq:					;make all input and output queue(s)
	push	b
	push	d
	call	monx	; create queue (last one is qcb$out$0)
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
	mov	m,d	; this allows SERVER.RSP to continue
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
	dcx	h	; SID - our NID
	dcx	h	; DID - requester NID
	cpi	logoutf			;is it a logoff?
	jnz	output2
	mov	a,m			;load NID
	call	free$rqstr$tbl		;yes-->free up the server process
output2:
	pop	b	; BC=MSGBUF
	push	b
	call	SNDMSG
	; TODO: handle errors?
	pop	h			;retrieve message pointer
	; Must work backwards from MSGBUF to find index into buf$cb...
	; TODO: find a better way...
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
