;***************************************************************************
;***************************************************************************
;**									  **
;**	S e r v e r   N e t w o r k   M a i n   M o d u l e		  **
;**		BANKED PORTION						  **
;**									  **
;***************************************************************************
;***************************************************************************
; Link: BNKNTSRV,NTWRKRCV,SERVERS,NIOS
;
; The mutex 'nmutex' must be "owned" in order to call the NIOS.
; The 'NtWrkRcv' process monitors for incoming network messages,
; receives them, and dispatches them to the appropriate server process
; via the matching server process message queue. Server processes
; perform the requested function and then acquire 'nmutex' and send
; the response back over network.

	public	bdos,cfgadr,nlock,nunlock,nwq0p
	extrn	recvr	; The network receiver loop entry
	extrn	qinit	; QCB/UQCB setup for message queues
	extrn	pinit	; (Server) process(es) setup
	extrn	NTWKIN,NTWKST,SNDMSG,RCVMSG,NWPOLL,NTWKER,NTWKDN

;***************************************************************************
;***************************************************************************
;**									  **
;**	This module performs initialization of the processes and 	  **
;**	provides shared resources.                              	  **
;**									  **
;***************************************************************************
;***************************************************************************
	maclib	config
	maclib	cfgnwif
	maclib	z80

	cseg
resadr:	dw	$-$		; pointer to RES part
	dw	stk0		; initial stack pointer
	db	'NETSERVR'	; descriptive name - must match BRS filename?

; Stack area for the initial process:
	dw	0c7c7h,0c7c7h,0c7c7h,0c7c7h
	dw	0c7c7h,0c7c7h,0c7c7h,0c7c7h
	dw	0c7c7h,0c7c7h,0c7c7h,0c7c7h
	dw	0c7c7h,0c7c7h,0c7c7h,0c7c7h
	dw	0c7c7h,0c7c7h,0c7c7h,0c7c7h
	dw	0c7c7h,0c7c7h,0c7c7h
stk0:	dw	setup

bdos$adr:	dw	$-$
cfgadr:		dw	$-$
nwq0p:		dw	$-$

; UQCB for 'MXNetwrk' - pre-filled (no open)
nmutex:	dw	0	; filled in by 'setup'
;	ds	2	; no MSGADR
;	ds	8	; no NAME - not opened

qcbname:	db	'NtwrkQIX'

; NETWRKIF Utility Routines

; Operating system linkage routine
bdos:	lhld	bdos$adr
	pchl

nlock:	lxi	d,nmutex
	mvi	c,readqf
	jmp	bdos

nunlock: lxi	d,nmutex
	mvi	c,writqf
	jmp	bdos

; Initialize Network Processes and resources
; Runs in the context of 'NtWrkRcv' process.
setup:
	lhld	resadr
	mov	e,m
	inx	h
	mov	d,m
	xchg
	shld	bdos$adr	; snag a copy for easier use
	; To avoid having to open all the queues, manually fixup
	; the UQCB structures to point at QCBs
	mvi	c,getpdf
	call	bdos
	; HL = 'networkio' in RESNTSRV.RSP
	lxi	d,P$LEN
	dad	d	; HL = mx$netwrk
	shld	nmutex	; setup UQCB
	push	h
	xchg	; DE=mx$netwrk
	mvi	c,makeqf
	call	bdos
	; we own the mutex now, don't release until we've called NTWKIN
	pop	h
	lxi	d,26	; length of mutex
	dad	d	; HL = SERVR0PR
	push	h	; save SERVR0PR for proc create loop
	lxi	d,nmb$rqstrs * P$LEN
	dad	d	; HL = qcb$in$0
	push	h
	shld	nwq0p
	call	qinit
	ora	a
	jnz	failed
	; messages queues are ready now
	pop	h
	lxi	d,nmb$rqstrs * qcb$in$len
	dad	d	; HL = CFGTBL
	shld	cfgadr
	; set CFGTBL into system data page
	mvi	c,sysdatf
	call	bdos
	mvi	l,S$CPNET		; CP/NET config table address
	lded	cfgadr
	mov	m,e
	inx	h
	mov	m,d	; no one looking for this, yet
	pop	h	; HL = SERVR0PR
	call	pinit	; server procs start running now...
	ora	a	; (each should be sleeping on input Q)
	jnz	failed
	; now wait for start signal...
	call	nlock	; sleeps until SRVSTART
	; ...sysadmin has released us
	call	NTWKIN
	ora	a
	jnz	failed
	call	nunlock
	jmp	recvr	; now perform our designated function...

failed:
	mvi	c,attconf
	call	bdos
	lxi	d,errmsg
	mvi	c,printf
	call	bdos
	mvi	c,detconf
	call	bdos
fail0:	; do nothing, softly...
	mvi	e,60
	mvi	c,delayf
	call	bdos
	jmp	fail0

errmsg:	db	CR,LF,'Network Init Error',CR,LF,'$'

	end
