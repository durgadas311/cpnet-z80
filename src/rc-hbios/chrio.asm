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
; Uses direct I/O calls in RomWBW, which requires that callers
; be switched to the ROM bank.
;
	maclib	z80
	maclib	config

	public	sendby,check,recvby,recvbt
	public	HBSER

@siz	equ	4		; offset of SIZ field
@dat	equ	5		; offset of payload, length of header
maxmsg	equ	256+@dat	; max len CP/NET format 0 msg

	cseg

bbuf:	ds	maxmsg
ubufp:	dw	0

	ds	48
STACK:	ds	0

; BC = callers msgbuf
; A = 0 if recv, 1 if send
fixbuf:
	bit	7,b	; check if msgbuf in high memory
	rnz		; in high mem, nothing to do
	ora	a
	jrz	fixrcv
	; send assumed
	mov	l,c
	mov	h,b
	lxi	d,bbuf
	lxi	b,maxmsg	; should not always copy this much
	ldir
	jr	fix0

fixrcv:	sbcd	ubufp
fix0:	lxi	b,bbuf
	ret

; copy recv msgbuf back, if required
unfixb:
	lhld	ubufp
	mov	a,h
	ora	l
	rz
	xchg
	lxi	h,bbuf
	lda	bbuf+@siz
	adi	1+@dat	; +1 bias plus header length
	mov	c,a
	mvi	a,0
	aci	0
	mov	b,a
	ldir
	lxi	h,0
	shld	ubufp
	ret

hbinit:
	lxi	b,0f8f2h	; HBIOS SYSGET, Bank Info
	rst	1
	jnz	api$err		; handle API error
	mov	a,d		; BIOS bank id to A
	sta	HBBID+1		; Plug in bank id

	; Patch SENDR with FastPath addresses
	lxi	b,0f801h	; Get CIO func/data adr
	mvi	d,01h		; Func=CIO OUT
	mvi	e,HBUNIT
	rst	1
	jnz	api$err		; handle API error
	sded	HBUDAT+2	; Plug in data adr
	shld	HBSCFN+1	; Plug in func adr

	; Patch GETCHR with FastPath addresses
	lxi	b,0f801h	; Get CIO func/data adr
	mvi	d,00h		; Func=CIO IN
	mvi	e,HBUNIT
	rst	1
	jnz	api$err		; handle API error
	shld	HB1GC+1		; Plug in func adr 1
	shld	HB2GC+1		; Plug in func adr 2

	; Patch RCVRDY with FastPath addresses
	lxi	b,0f801h	; Get CIO func/data adr
	mvi	d,02h		; Func=CIO IST
	mvi	e,HBUNIT
	rst	1
	jnz	api$err		; handle API error
	shld	HB1RR+1		; Plug in func adr 1
	shld	HB2RR+1		; Plug in func adr 2

	; Patch SNDRDY with FastPath addresses
	; not used
	;lxi	b,0f801h	; Get CIO func/data adr
	;mvi	d,03h		; Func=CIO OST
	;mvi	e,HBUNIT
	;rst	1
	;jnz	api$err		; handle API error
	;shld	HBSRFN		; Plug in func adr

	xra	a
	ret

api$err:	; API returned unexpected failure
	lxi	d,ERRAPI	; API error message
	mvi	c,9		; BDOS string display function
	call	5		; Do it
	stc			; fail NTWKIN call
	ret
ERRAPI:	db	'HBIOS API ERROR',13,10,'$'


; <tos> = code to call from ROM bank
; A = context (send,recv,...)
; BC = msgbuf
HBSER:
	xtix			; save IX and get function to call
	sspd	STACKS+1	;
	lxi	sp,STACK	; use temporary stack in upper memory
	call	fixbuf		; may alter BC
	pushiy
HBUDAT:	lxiy	0		; filled in at init time
	push	b		; save msgbuf over ROM call
HBBID:	lxi	b,0f200h	; function: system set bank
	rst	1		; do it
	mov	a,c		; prior bank id
	sta	USRBID+1	; save it for later
	pop	b		; restore msgbuf
	call	JPIX		; call function in IX
	push	psw		; save result code
USRBID:	mvi	a,0		; restore prior bank id
	call	0fff3h		; call HBIOS select bank
	call	unfixb		; copy out msgbuf as required
	pop	psw		; result code
	popiy
STACKS:	lxi	sp,0		; filled in on entry - restore callers stack
	popix			; restore callers IX
	ret

JPIX:	pcix

; Destroys C, E, B
sendby:
	push	hl
	push	de
	push	bc
	mov	e,a	; e is the data byte
HBSCFN:	call	0	; filled at init time
	pop	bc
	pop	de
	pop	hl
	ret		; if not, should make this in-line

drain:	lxi	b,bbuf	; any adr in high memory
	xra	a	; doesnt really matter
	call	HBSER	; perform the rest with ROM bank
drain0:
HB1RR:	call	0	; filled in at init time
	cpi	0
	rz
HB1GC:	call	0	; filled in at init time
	jmp	drain0

check:			; check to see if the device is present....
	call	hbinit	; initialize direct RomWBW calls
	rc		; fail if errors
	call	drain	; empty the RomWBW input buffer befor proceeding.
	stc		; since you cant unplug the sio port its always there
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
HB2RR:	call	0	; filled in at init time
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
rcvb1:
HB2GC:	call	0	; filled in at init time
	mov	a,e	; copy to a
	pop	hl
	pop	de
	pop	bc
	stc
	cmc		; no errors
	ret
	end
