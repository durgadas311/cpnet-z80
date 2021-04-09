; Basic WIZNET routines

	public	wizcfg,wizcf0,wizcmd,wizget,wizset,wizclose,setsok,settcp
	public	gkeep,skeep

	maclib	config

	; Caller must supply 'nvbuf'
	extrn	nvbuf
if NVRAM
	; Requires linking with NVRAM.REL, for 'wizcfg'...
	extrn	nvget, vcksum
endif

	maclib	z80

; WIZNET CTRL bit for writing
WRITE	equ	00000100b

GAR	equ	1	; offset of GAR, etc.
SUBR	equ	5
SHAR	equ	9
SIPR	equ	15
PMAGIC	equ	29	; used for node ID

nsock	equ	8
SOCK0	equ	000$01$000b
SOCK1	equ	001$01$000b
SOCK2	equ	010$01$000b
SOCK3	equ	011$01$000b
SOCK4	equ	100$01$000b
SOCK5	equ	101$01$000b
SOCK6	equ	110$01$000b
SOCK7	equ	111$01$000b

SnMR	equ	0
SnCR	equ	1
SnIR	equ	2
SnSR	equ	3
SnPORT	equ	4
SnDIPR	equ	12
SnDPORT	equ	16
SnRESV1	equ	20	; 0x14 reserved
SnRESV2	equ	23	; 0x17 reserved
SnRESV3	equ	24	; 0x18 reserved
SnRESV4	equ	25	; 0x19 reserved
SnRESV5	equ	26	; 0x1a reserved
SnRESV6	equ	27	; 0x1b reserved
SnRESV7	equ	28	; 0x1c reserved
SnRESV8	equ	29	; 0x1d reserved
SnTXBUF	equ	31	; TXBUF_SIZE

NvKPALVTR equ	SnRESV8	; where to stash keepalive in NVRAM
SnKPALVTR equ	47	; Keep alive timeout, 5s units

; Socket SR values
CLOSED	equ	00h

; Socket CR commands
DISCON	equ	08h

	cseg

; Send socket command to WIZNET chip, wait for done.
; A = command, D = socket BSB
; Destroys A
wizcmd:
	push	psw
	mvi	a,WZSCS
	out	spi$ctl
	xra	a
	out	spi$wr
	mvi	a,SnCR
	out	spi$wr
	mov	a,d
	ori	WRITE
	out	spi$wr
	pop	psw
	out	spi$wr	; start command
	xra	a	;
	out	spi$ctl
wc0:
	mvi	a,WZSCS
	out	spi$ctl
	xra	a
	out	spi$wr
	mvi	a,SnCR
	out	spi$wr
	mov	a,d
	out	spi$wr
	in	spi$rd	; prime pump
	in	spi$rd
	push	psw
	xra	a	;
	out	spi$ctl
	pop	psw
	ora	a
	jnz	wc0
	ret

; E = BSB, D = CTL, HL = data, B = length
wizget:
	mvi	a,WZSCS
	out	spi$ctl
	xra	a	; hi adr always 0
	out	spi$wr
	mov	a,e
	out	spi$wr
	mov	a,d
	out	spi$wr
	in	spi$rd	; prime pump
	mvi	c,spi$rd
	inir
	xra	a	; not SCS
	out	spi$ctl
	ret

; HL = data to send, E = offset, D = BSB, B = length
; destroys HL, B, C, A
wizset:
	mvi	a,WZSCS
	out	spi$ctl
	xra	a	; hi adr always 0
	out	spi$wr
	mov	a,e
	out	spi$wr
	mov	a,d
	ori	WRITE
	out	spi$wr
	mvi	c,spi$wr
	outir
	xra	a	; not SCS
	out	spi$ctl
	ret

; Close socket if active (SR <> CLOSED)
; D = socket BSB
; Destroys HL, E, B, C, A
wizclose:
	lxi	h,tmp
	mvi	e,SnSR
	mvi	b,1
	call	wizget
	lda	tmp
	cpi	CLOSED
	rz
	mvi	a,DISCON
	call	wizcmd
	; don't care about results?
	ret

; IX = base data buffer for socket, D = socket BSB, E = offset, B = length
; destroys HL, B, C
setsok:
	pushix
	pop	h
	push	d
	mvi	d,0
	dad	d	; HL points to data in 'buf'
	pop	d
	call	wizset
	ret

; Set socket MR to TCP.
; D = socket BSB (result of "getsokn")
; Destroys all registers except D.
settcp:
	lxi	h,tmp
	mvi	m,1	; TCP/IP mode
	mvi	e,SnMR
	mvi	b,1
	call	wizset	; force TCP/IP mode
	ret

; Get KEEP-ALIVE value
; D=socket BSB
; Return: A=keep-alive value
gkeep:
	mvi	e,SnKPALVTR
	lxi	h,tmp
	mvi	b,1
	call	wizget
	lda	tmp
	ret

; Set KEEP-ALIVE value - only for DIRECT mode
; A=keep-alive time, x5-seconds
; D=socket BSB
skeep:	ora	a
	rz	; do not set, rather than "disable"...
	sta	tmp
	mvi	e,SnKPALVTR
	lxi	h,tmp
	mvi	b,1
	call	wizset
	ret

; restore config from NVRAM
; Buffer is 'nvbuf' (512 bytes)
; Return: CY if no config
wizcfg:
if NVRAM
	lxix	nvbuf
	lxi	h,0
	lxi	d,512
	call	nvget
	lxix	nvbuf
	call	vcksum
	stc
	rnz
else
	stc
	ret
endif
wizcf0:
	lxix	nvbuf
	lxi	h,nvbuf+GAR
	mvi	d,0
	mvi	e,GAR
	mvi	b,18	; GAR, SUBR, SHAR, SIPR
	call	wizset
	lxi	h,nvbuf+PMAGIC
	mvi	d,0
	mvi	e,PMAGIC
	mvi	b,1
	call	wizset
	lxix	nvbuf+32
	mvi	d,SOCK0
	mvi	b,8
rest0:	push	b
	ldx	a,SnPORT
	cpi	31h
	jnz	rest1	; skip unconfigured sockets
	call	wizclose
	call	settcp	; ensure MR is set to TCP/IP
	ldx	a,NvKPALVTR
	call	skeep
	mvi	e,SnPORT
	mvi	b,2
	call	setsok
	mvi	e,SnDIPR
	mvi	b,6	; DIPR and DPORT
	call	setsok
rest1:	lxi	b,32
	dadx	b
	mvi	a,001$00$000b	; socket BSB incr value
	add	d
	mov	d,a
	pop	b
	djnz	rest0
	xra	a
	ret

	dseg
tmp:	db	0

	end
