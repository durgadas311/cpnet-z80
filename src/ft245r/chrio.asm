; SNIOS plug-in for Noberto's H89 USB/SERIAL board,
; Specifically, the FT245R chip.
; http://koyado.com/Heathkit/H-89_USB_Serial.html
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
	ani	USBTXR
	jz	sendb0
	mov	a,c
	out	USBPORT	; probably can't ever overrun?
	ret		; if not, should make this in-line

check:
	; do check for sane hardware...
	lxi	h,0
	mvi	e,3	; approx 4.5 sec @ 2MHz
check0:
	in	STSPORT	; 11
	ani	USBTXR	; 7, also NC
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
; Returns character in A
recvby:
	mvi	c,0
recvb0:
	in	STSPORT
	ani	USBRXR
	jnz	recvb1
	dcr	c
	jnz	recvb0
	stc
	ret	; CY, plus A not '-'
recvb1:
	in USBPORT
	ret

; Receive initial message bytes (e.g. "++")
; May need timeout, but must be long.
; Must preserve all regs (exc. A)
; May return CY on timeout.
recvbt:
	in	STSPORT
	ani	USBRXR
	jz	recvbt
	in	USBPORT
	ret

	end
