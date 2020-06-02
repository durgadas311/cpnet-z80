; SNIOS plug-in for INS8250 and clones
;
	maclib	z80
	maclib	config

	public	sendby,check,recvby,recvbt

	cseg

; Destroys C
sendby:
	mov	c,a
sendb0:
	in	STSPORT
	ani	SERTXR
	jz	sendb0
	mov	a,c
	out	SERPORT	; probably can't ever overrun?
	ret		; if not, should make this in-line

check:
	; initialize UART (baud)
	lxi	h,SERBAUD
	mvi	a,SERLCR+SERDLAB
	out	SERPORT+3
	mov	a,h
	out	SERPORT+1
	mov	a,l
	out	SERPORT+0
	mvi	a,SERLCR
	out	SERPORT+3
	xra	a	; interrupts off
	out	SERPORT+1
	mvi	a,SERMCR
	out	SERPORT+4	; set handshake outputs
	; do check for sane hardware...
	lxi	h,0
	mvi	e,3	; approx 4.5 sec @ 2MHz
check0:
	in	STSPORT	; 11
	ani	SERTXR	; 7, also NC
	rnz		; 5 (11)
	dcx	h	; 6
	mov	a,h	; 4
	ora	l	; 4
	jnz	check0	; 10 = 47, * 65536 = 3080192 = 1.504 sec
	dcr	e	; 4
	jnz	check0	; 10
	stc
	ret

; When using this, each byte must be coming soon...
; Destroys C
; Returns character in A, CY on timeout
recvby:
	push	b
	lxi	b,charTimeout
recvb0:
	in	STSPORT
	ani	SERRXR
	jnz	recvb1
	dcx	b
	mov	a,b
	ora	c
	jnz	recvb0
	pop	b
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
	lxi	b,startTimeout
	jr	recvb0

	end
