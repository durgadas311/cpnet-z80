; SNIOS plug-in for SC131 sio port b ,
; Notes:  The Z180  chip used on the SC131 does not have the
; CTS/RTS signals.  They simply do not exist.  So, the max 
; speed that this driver can run is 57600 baud.  Not a barn
; stormer, but fast enough for copying info/programs into and
; out of the SC131 SD card.
;
; This driver uses the RomWBW interface in leu of direct I/O due to 
; issues with the interrupt structure inside the Z180 chip.  
;
	maclib	z80
;	maclib	config

	public	sendby,check,recvby,recvbt

	cseg

; Destroys C, E, B
sendby:
	push	hl
	push	de
	push	bc
	mov	e,a	; e is the data byte
	mvi	b,1	; b is the function code
	mvi	c,1	; c is the unit number
	rst	1	; off to RomWBW  8080 syntax for rst 8
	pop	bc
	pop	de
	pop	hl
	ret		; if not, should make this in-line

check:			; check to see if the device is present....
; empty the RomWBW input buffer befor proceeding.
chklp:	mvi	b,2	; poll the input device
	mvi	c,1	; it will be unit 1
	rst	1	; off to get it.
	cpi	0
	jz	chklp1
	mvi	b,0	; function 0
	mvi	c,1	; unit number
	rst	1	; go get it
	jmp	chklp
chklp1:	stc		; since you can't unplug the sio port its always 
			; there
	cmc
	ret

; When using this, each byte must be coming soon...
; Destroys C, B, D
; Returns character in A
recvby:							;s 0
	push	bc					;s 1
	push	de					;s 2
	push	hl					;s 3
	lxi	d,0
recvb0:
	push	de					;s 4
	mvi	b,2	; poll the input device
	mvi	c,1	; it will be unit 1
	rst	1	; off to get it.
	pop	de	; prep DE for down count	;s 3
	cpi	0	; zero means no bytes
	jnz	rcvb1
	dcx	d	; count down 1
	mov	a,d	; check for wrap
	ora	e
	jnz	recvb0
	pop	hl					;-s 3
	pop	de					;-s 2
	pop	bc 					;-s 1
	stc		; carry is err			; s 0
	ret		; CY, plus A not '-'
; Receive initial message bytes (e.g. "++")
; May need timeout, but must be long.
; Must preserve all regs (exc. A)
; May return CY on timeout.
recvbt:
	push	bc
	push	de
	push	hl
rcvb1:	mvi	b,0	; function 0
	mvi	c,1	; unit number
	rst	1	; go get it
	mov	a,e	; copy to a
	pop	hl
	pop	de
	pop	bc
	stc
	cmc		; no errors
	ret
	end
