; SNIOS plug-in for Z80-SIO
;
	maclib	z80
	maclib	config

	public	sendby,check,recvby,recvbt

	cseg

; Destroys C
sendby:
	mov	c,a
sendb0:
	xra	a
	out	CMDPORT
	in	CMDPORT
	ani	SERTXR
	jz	sendb0
	mov	a,c
	out	SERPORT	; probably can't ever overrun?
	ret		; if not, should make this in-line

sioprg:	db	1,0		; WR1, all off
	db	3,SIOWR3	; WR3 Rx
	db	4,SIOWR4	; WR4 UART
	db	5,SIOWR5	; WR5 Tx
prglen	equ	$-sioprg

check:
	; initialize UART (baud)
	mvi	a,SERBAUD
	out	BAUDPRT
	mvi	c,CMDPORT
	lxi	h,sioprg
	mvi	b,prglen
	outir
	; do check for sane hardware...
	lxi	h,6452	; approx 0.1 sec
check0:
	xra	a	; 4
	out	CMDPORT ; 11
	in	CMDPORT	; 11
	ani	SERTXR	; 7, also NC
	rnz		; 5 (11)
	dcx	h	; 6
	mov	a,h	; 4
	ora	l	; 4
	jnz	check0	; 10 = 62, * 6452 = 40000 = 0.1 sec
	stc
	ret

; When using this, each byte must be coming soon...
; Destroys C
; Returns character in A, CY on timeout
recvby:
	push	b
	lxi	b,charTimeout*2	; adjust to 4MHz
recvb0:
	xra	a
	out	CMDPORT
	in	CMDPORT
	ani	SERRXR
	jnz	recvb1
	dcx	b
	mov	a,b
	ora	c
	jnz	recvb0
	pop	b
	mvi	a,4	; BEEP on timeout
	out	05h
	stc
	ret	; CY, timeout
recvb1:
	in	SERPORT
	pop	b
	ret

; Receive initial message bytes (e.g. "++" or ENQ)
; Must preserve all regs (exc. A)
; Destroys C
; Returns character in A
; May return CY on timeout.
recvbt:
	push	b
	lxi	b,startTimeout*2	; adjust to 4MHz
	jr	recvb0

	end
