;***************************************************************************
;***************************************************************************
;**									  **
;**	S e r v e r   N e t w o r k   R e c e i v e r   M o d u l e	  **
;**									  **
;***************************************************************************
;***************************************************************************

	; This must be linked with a suitable NIOS.REL
	public	qinit,recvr,rqfree,bffree
	extrn	bdos,nlock,nunlock
	extrn	NTWKIN,NTWKST,SNDMSG,RCVMSG,NWPOLL,NTWKER,NTWKDN

;***************************************************************************
;***************************************************************************
;**									  **
;**	This module performs communication operations on a server	  **
;**	equipped with a WizNET W5500 Ethernet network adaptor.  	  **
;**									  **
;***************************************************************************
;***************************************************************************
; Link: BNKNTSRV,NTWRKRCV,SERVERS,NIOS

	maclib	config
	maclib	cfgnwif
	maclib	z80

	cseg

rqtb$len equ	7	; caution when changing this:
			; init routine must also change.
; rqstr$table struct:
;	ds	1	; requester NID or 0ffh, init to 0ffh
;	ds	2	; UQCB.POINTER, init to qcb$in$X
;	ds	2	; UQCB.MSGPTR, init to $+2 (msgptr buffer)
;	ds	2	; msgptr buffer, set by readqf
; This table associates requesters with server processes (NtwrkQI)
rqstr$table:
	ds	nmb$rqstrs * rqtb$len

; Buffer Control Block:
; 000h indicates buffer is free for receiving a message,
; 0ffh indicates that the buffer is in use
buf$cb:	rept	nmb$bufs
	db	0
	endm

; Message Buffer Storage Area, allocaed via buf$cb
msg$buffers:
	ds	nmb$bufs * M$LEN

qcbname: db	'NtwrkQIX'

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
	; convert to hex digit
	adi	90h
	daa
	aci	40h
	daa
	mov	m,a	; 'X': 0..F
	inx	h	; QCB.MSGLEN
	xra	a
	mvi	m,2
	inx	h	; QCB.MSGLEN hi byte
	mov	m,a
	inx	h	; QCB.NMBMSGS
	mvi	m,1
	inx	h	; QCB.NMBMSGS hi byte
	mov	m,a
	pop	psw
	pop	d
	pop	h
	ret

; Initial message queues
; HL = qcb$in$0 (* nmb$rqstrs)
; Returns A=0 for success
qinit:
	push	h	; save qcb$in$0 for makeqf loop
	lxi	d,rqstr$table
	mvi	a,nmb$rqstrs
setup0:	xchg	; DE = qcb$in$X, HL=rqstr$table A = nmb$rqstrs-X
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
	; There are 'nmb$rqstrs' qcb$in queues
	mvi	b,nmb$rqstrs		;loop counter for making n+1 queues
	mvi	c,makeqf		;make queue function code
	pop	d	; DE = qcb$in$0
makeq:					;make all input and output queue(s)
	push	b
	push	d
	call	bdos	; create queue (last one is qcb$out$0)
	pop	h
	lxi	d,qcb$in$len
	dad	d
	xchg
	pop	b
	dcr	b
	jnz	makeq
 if polling
	; TODO: get poll$tb from XIOS, add NWPOLL at device #8...
 endif
	xra	a
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
; TODO: can we assume/assert that the entry exists?
;
;	Input:  A = source ID that just logged off
rqfree:	lxi	h,rqstr$table
	lxi	d,rqtb$len
	mvi	c,nmb$rqstrs
fr$t1:	cmp	m
	jnz	fr$t2			;RCB ID <> SID-->keep scanning
	mvi	m,0ffh			;else-->mark it as unoccupied
	ret				;  and bug out
fr$t2:	dad	d
	dcr	c
	jnz	fr$t1			;keep going--it's in there somewhere
	ret

; Free a CP/NET message BCB, given buffer address
; HL=MSGBUF
bffree:	lxi	d,msg$buffers
	xra	a
bff0:	ora	a
	dsbc	d	; compute offset in buf area
	jz	bff1	; found it...
	rc		; ran off end
	lxi	d,M$LEN
	inr	a
	jmp	bff0
bff1:	mov	c,a
	mvi	b,0
	lxi	h,buf$cb
	mvi	m,0	; free buffer
	ret

recvr:	; main receive polling loop
 if polling
	mvi	e,8	; TODO: do not hard-code?
	mvi	c,poll
	call	bdos
	call	nlock	; might sleep
 else
	lxi	d,1	; TODO: best number here?
	mvi	c,delayf
	call	bdos	;dispatch and go sleepy bye for a bit
	; NWPOLL must be atomic with RCVMSG, if "ready"
	call	nlock	; might sleep
	call	NWPOLL
	ora	a
	jz	input1	; nothing - unlock and try again
 endif
	; TODO: process all? or just one?
	; mutex is (must be) held at entry.
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
	xchg		; DE=msg$buffers[x++]
	pop	h	;point to next buffer control field
	inx	h	; HL=buf$cb[x++]
	dcr	b	;have we scanned all the buffers?
	jnz	input2
	; no free buffers - can't receive anything...
input1:
	call	nunlock
	jmp	recvr
input3:
	mvi	m,0ffh			;found a buffer-->mark it used
	push	h	; stack: BCB ptr
	push	d	; stack: MSGBUF, BCB ptr
	; Receive the message
	mov	b,d
	mov	c,e
	call	RCVMSG
	; we no longer need the mutex
	push	psw
	call	nunlock
	pop	psw
	; if RCVMSG error, we don't have a message to process.
	; free buffer and move on...
	ora	a
	pop	h	; HL=MSGBUF, stack: BCB ptr
	jnz	input8
	push	h	; stack: MSGBUF, BCB ptr
	inx	h			;check requester table to see 
	inx	h			;  whether the source requester
	mov	a,m	; SID		;    is logged-in
	call	scan$table		; get rqstr$table entry
	inr	a	; test FF, preserve CY
	jz	input4			;not logged-in-->go check for login
	; stack: MSGBUF, BCB ptr
input6:
	; stack: MSGBUF, BCB ptr
	; HL = rqstr$table
	lxi	d,rqtb$len-2		;else-->update message buffer pointer
	dad	d
	pop	d	; MSGBUF
	mov	m,e
	inx	h	; rqtb$len-1
	mov	m,d
	lxi	d,-(rqtb$len-2)	;back to the uqcb for this requester
	dad	d
	xchg
	mvi	c,writqf		;write the message to the queue
	call	bdos
	pop	h	; BCB ptr
	jmp	recvr

input4:					;else-->requester not logged-in
	; stack: MSGBUF, BCB ptr
	pop	d	; DE=MSGBUF, stack: BCB ptr
	inx	d	; DID
	inx	d	; SID
	inx	d	; FNC
	jc	input5			;bomb the message if there's no space
	ldax	d	; FNC
	cpi	loginf			;is it a login?
	jnz	input5
	dcx	d			;yes-->mark the control block with
	ldax	d			;  the source ID
	mov	m,a
	dcx	d			;go do the queue write
	dcx	d
	push	d	; MSGBUF back on stack (stack: MSGBUF, BCB ptr)
	jmp	input6

input5:			;flag a "not logged in" extended error
	; stack: BCB ptr
	; DE = MSGBUF.FNC
	xchg
	inx	h
	mvi	m,2-1		;set SIZ
	inx	h
	mvi	m,0ffh		;set return code to error
	inx	h
	mvi	m,0ch		;flag extended error 12
	lxi	d,-(DAT+1)
	dad	d		;point back at message start
	mvi	m,1		;format = 1
	inx	h		;swap DID and SID
	mov	a,m
	inx	h	; SID
	mov	b,m
	mov	m,a
	dcx	h	; DID
	mov	m,b
	dcx	h	; FMT
	; TODO: just send it now? why not?
	push	h	; stack: MSGBUF, BCB ptr
	call	nlock	; TODO: issues with sleeping here?
	pop	b	; BC=MSGBUF, stack: BCB ptr
	call	SNDMSG
	; TODO: error handling?
	call	nunlock
input8:
	pop	h	; BCB ptr (stack: EMPTY)
	; free buffer - we're done with it.
	mvi	m,0	; mark buffer free
	jmp	recvr	; try again

	end
