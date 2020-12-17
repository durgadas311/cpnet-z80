; SNIOS for WizNET W5500-based devices, via parallel-SPI interface
;
	maclib	z80

	public	NTWKIN, NTWKST, CNFTBL, SNDMSG, RCVMSG, NTWKER, NTWKBT, NTWKDN, CFGTBL

	maclib	config

nsocks	equ	8

sock0	equ	000$01$000b	; base pattern for Sn_ regs
txbuf0	equ	000$10$100b	; base pattern for Tx buffer
rxbuf0	equ	000$11$000b	; base pattern for Rx buffer

; common regs
ir	equ	21
sir	equ	23
pmagic	equ	29

; socket regs, relative
sn$cr	equ	1
sn$ir	equ	2
sn$sr	equ	3
sn$prt	equ	4
sn$txwr	equ	36
sn$rxrsr equ	38
sn$rxrd	equ	40

; socket commands
OPEN	equ	01h
CONNECT	equ	04h
CLOSE	equ	08h	; DISCONNECT, actually
SEND	equ	20h
RECV	equ	40h

; socket status
CLOSED	equ	00h
INIT	equ	13h
ESTAB	equ	17h

	cseg
;	Slave Configuration Table - must be first in module
CFGTBL:
	ds	1		; network status byte
	ds	1		; slave processor ID number
	ds	2		; A:	Disk device	+2
	ds	2		; B:	"
	ds	2		; C:	"
	ds	2		; D:	"
	ds	2		; E:	"
	ds	2		; F:	"
	ds	2		; G:	"
	ds	2		; H:	"
	ds	2		; I:	"
	ds	2		; J:	"
	ds	2		; K:	"
	ds	2		; L:	"
	ds	2		; M:	"
	ds	2		; N:	"
	ds	2		; O:	"
	ds	2		; P:	"

	ds	2		; console device	+34

	ds	2		; list device:		+36...
	ds	1		;	buffer index	+2
	db	0		;	FMT		+3
	db	0		;	DID		+4
	db	0ffh		;	SID (CP/NOS must still initialize)
	db	5		;	FNC		+6
	db	0		;	SIZ		+7
	ds	1		;	MSG(0)	List number	+8
	ds	128		;	MSG(1) ... MSG(128)	+9...

;	Network Status Byte Equates
;
active		equ	0001$0000b	; slave logged in on network
rcverr		equ	0000$0010b	; error in received message
senderr 	equ	0000$0001b	; unable to send message

srvtbl:	ds	nsocks	; SID, per socket

cursok:	db	0	; current socket select patn
curptr:	dw	0	; into chip mem
msgptr:	dw	0
msglen:	dw	0
totlen:	dw	0

getwiz1:
	mvi	a,WZSCS
	out	spi$ctl
	mvi	c,spi$wr
	xra	a
	outp	a	; hi adr byte always 0
	outp	e
	res	2,d
	outp	d
if spi$rd <> spi$wr
	mvi	c,spi$rd
endif
	inp	a	; prime MISO
	inp	a
	push	psw
	xra	a
	out	spi$ctl	; clear SCS
	pop	psw
	ret

; call with data in a, offset in e, bsb in d
putwiz1:
	push	psw
	mvi	a,WZSCS
	out	spi$ctl
	mvi	c,spi$wr
	xra	a
	outp	a	; hi adr byte always 0
	outp	e
	setb	2,d
	outp	d
	pop	psw
	outp	a	; data
	xra	a
	out	spi$ctl	; clear SCS
	ret

; Get 16-bit value from chip
; Prereq: IDM_AR0 already set, auto-incr on
; Entry: A=value for IDM_AR1
; Return: HL=register pair contents
getwiz2:
	mvi	a,WZSCS
	out	spi$ctl
	mvi	c,spi$wr
	xra	a
	outp	a	; hi adr byte always 0
	outp	e
	res	2,d
	outp	d
if spi$rd <> spi$wr
	mvi	c,spi$rd
endif
	inp	h	; prime MISO
	inp	h	; data
	inp	l	; data
	; A still 00
	out	spi$ctl	; clear SCS
	ret

; Put 16-bit value to chip
; Prereq: IDM_AR0 already set, auto-incr on
; Entry: A=value for IDM_AR1
;        HL=register pair contents
putwiz2:
	mvi	a,WZSCS
	out	spi$ctl
	mvi	c,spi$wr
	xra	a
	outp	a	; hi adr byte always 0
	outp	e
	setb	2,d
	outp	d
	outp	h	; data to write
	outp	l
	; A still 00
	out	spi$ctl	; clear SCS
	ret

; Issue command, wait for complete
; D=Socket ctl byte
; Returns: A=Sn_SR
wizcmd:	mov	b,a
	mvi	e,sn$cr
	setb	2,d
	mvi	a,WZSCS
	out	spi$ctl
	mvi	c,spi$wr
	xra	a
	outp	a	; hi adr byte always 0
	outp	e
	outp	d
	outp	b	; command
	; A still 00
	out	spi$ctl	; clear SCS
wc0:	call	getwiz1
	ora	a
	jrnz	wc0
	mvi	e,sn$sr
	call	getwiz1
	ret

; wait for socket state
; D=socket, C=bits (destroys B)
; returns A=Sn_IR - before any bits are reset
wizist:	lxi	h,32000
wst0:	push	b
	push	h
	mov	l,c
	call	wizsts
	pop	h
	pop	b
	mov	b,a
	ana	c
	jrnz	wst1
	dcx	h
	mov	a,h
	ora	l
	jrnz	wst0
	stc
	ret
wst1:	mov	a,b
	ret

; B=Server ID, preserves HL
; returns DE=socket base (if NC)
getsrv:
	mvi	c,nsocks
	lxi	d,srvtbl
gs1:
	ldax	d
	cmp	b
	jrz	gs0
	inx	d
	dcr	c
	jrnz	gs1
	stc	; not found
	ret
gs0:	; found...
	mvi	a,nsocks
	sub	c	; socket num 00000sss
	rrc		; s00000ss
	rrc		; ss00000s
	rrc		; sss00000
	sta	cursok
	ori	sock0	; sss01000
	mov	d,a
	mvi	e,sn$sr
	call	getwiz1
	cpi	ESTAB
	rz
	cpi	INIT
	jrz	gs3
	; try to open socket...
	mvi	a,OPEN
	call	wizcmd
	cpi	INIT
	jrnz	gs2
gs3:	mvi	a,CONNECT
	call	wizcmd
	mvi	c,00001011b	; CON, DISCON, or TIMEOUT
	call	wizist	; returns when one is set
	cma	; want "0" on success
	ani	00000001b	; CON
	rz
gs2:	stc	; failed to open
	ret

; HL=socket relative pointer (TX_WR)
; DE=length
; Returns: HL=msgptr, C=spi$wr
cpsetup:
	mvi	a,WZSCS
	out	spi$ctl
	mvi	c,spi$wr
	outp	h
	outp	l
	lda	cursok
	ora	b
	outp	a
	lhld	msgptr
	ret

cpyout:
	mvi	b,txbuf0
	call	cpsetup
	mov	b,e	; fraction of page
	mov	a,e
	ora	a
	jrz	co0	; exactly 256
	outir		; do partial page
	; B is now 0 (256 bytes)
	mov	a,d
	ora	a
	jrz	co1
co0:	outir	; 256 (more) bytes to xfer
co1:	shld	msgptr
	xra	a
	out	spi$ctl	; clear SCS
	ret

; HL=socket relative pointer (RX_RD)
; DE=length
; Destroys IDM_AR0, IDM_AR1
cpyin:
	mvi	b,rxbuf0
	call	cpsetup	;
if spi$rd <> spi$wr
	mvi	c,spi$rd
endif
	inp	a	; prime MISO
	mov	b,e	; fraction of page
	mov	a,e
	ora	a
	jrz	ci0	; exactly 256
	inir		; do partial page
	; B is now 0 (256 bytes)
	mov	a,d
	ora	a
	jrz	ci1
ci0:	inir	; 256 (more) bytes to xfer
ci1:	shld	msgptr
	xra	a
	out	spi$ctl	; clear SCS
	ret

; L=bits to reset
; D=socket base
; Destroys C,E
wizsts:
	mvi	e,sn$ir
	call	getwiz1	; destroys C
	push	psw
	ana	l
	jrz	ws0	; don't reset if not set (could race)
	mov	a,l
	call	putwiz1
ws0:	pop	psw
	ret

;	Utility Procedures
;
;	Network Initialization
NTWKIN:
	lxix	CFGTBL
	lxi	d,pmagic
	call	getwiz1
	ora	a
	jz	err
	stx	a,+1 ; our slave (client) ID
	mvi	a,active
	stx	a,+0 ; network status byte
	xra	a
	sta	CFGTBL+36+7
	jmp	ntwkbt0	; load data

;	Network Status
NTWKST:
	lda	CFGTBL+0
	mov	b,a
	ani	not (rcverr+senderr)
	sta	CFGTBL+0
	mov	a,b
	ret

;	Return Configuration Table Address
;	Still need this for BDOS func 69
CNFTBL:
	lxi	h,CFGTBL
	ret

;	Send Message on Network
SNDMSG:			; BC = message addr
	sbcd	msgptr	; store BC addr into msgptr
	lixd	msgptr	; put message pointer into index register
	ldx	b,+1	; SID - destination
	call	getsrv
	jrc	serr
	; D=socket patn
	lda	CFGTBL+1
	stx	a,+2	; Set Slave ID in header
	ldx	a,+4	; msg siz (-1)
	adi	5+1	; hdr, +1 for (-1)
	mov	l,a
	mvi	a,0
	aci	0
	mov	h,a	; HL=msg length
	shld	msglen
	mvi	e,sn$txwr ; 0x24, Socketn tx write pointer
	call	getwiz2	; into hl

	shld	curptr	; store hl in curptr
	lhld	msglen	; load hl with msglen
	lbcd	curptr	; load bc with curptr
	dad	b	; add hl+bc to hl
	mvi	e,sn$txwr  ;
	call	putwiz2 ; update Socketn tx write pointer

	; send data
	lhld	msglen
	xchg		; length into DE
	lhld	curptr	; chip address into HL
	call	cpyout	; msglen in DE, curptr in HL, socket in A

	lda	cursok
	ori	sock0
	mov	d,a
	mvi	a,SEND  ; send the message
	call	wizcmd
	; ignore Sn_SR?
	mvi	c,00011010b	; SEND_OK, DISCON, or TIMEOUT bit
	call	wizist
	cma	; want "0" on success
	ani	00010000b	; SEND_OK
	rz	; else TIMEOUT/DISCON
serr:	lda	CFGTBL
	ori	senderr
	sta	CFGTBL
	mvi	a,0ffh
	ret

; TODO: also check/OPEN sockets?
; That would result in all sockets always being open...
; At least check all, if none are ESTAB then error immediately
check:
	lxiy	srvtbl
	lxi	d,(sock0 shl 8) + sn$sr
	mvi	b,nsocks
chk2:
	ldy	a,+0
	cpi	0ffh
	jrz	chk5
	call	getwiz1
	cpi	ESTAB
	jrz	chk3
chk5:	mvi	a,001$00$000b
	add	d	; next socket
	mov	d,a
	inxiy
	djnz	chk2
	stc
	ret
chk3:	lxi	h,32000	; do check for sane receive time...
chk0:	mvi	d,sock0
	mvi	b,nsocks
	lxiy	srvtbl
	push	h
	mvi	l,00000100b	; RECV data available bit
chk1:
	ldy	a,+0
	cpi	0ffh
	jrz	chk6
	call	wizsts
	ana	l	; RECV data available
	jrnz	chk4	; D=socket
chk6:	mvi	a,001$00$000b
	add	d	; next socket
	mov	d,a
	inxiy
	djnz	chk1
	pop	h
	dcx	h
	mov	a,h
	ora	l
	jrnz	chk0
	stc
	ret
chk4:	pop	h
	ret

;	Receive Message from Network
RCVMSG:			; BC = message addr
	sbcd	msgptr
	lixd	msgptr
	call	check	; locates socket that is ready
	; D=socket
	jrc	rerr
	lxi	h,0
	shld	totlen
rm0:	; D must be socket base...
	mvi	e,sn$rxrsr	; length
	call	getwiz2
	mov	a,h
	ora	l
	jrz	rm0
	shld	msglen		; not CP/NET msg len
	mvi	e,sn$rxrd	; pointer
	call	getwiz2	; get rxrd addr
	shld	curptr
	lbcd	msglen	; BC=Sn_RX_RSR
	lhld	totlen
	ora	a
	dsbc	b
	shld	totlen	; might be negative...
	lbcd	curptr
	lhld	msglen	; BC=Sn_RX_RD, HL=Sn_RX_RSR
	dad	b	; HL=nxt RD
	mvi	e,sn$rxrd
	call	putwiz2	; write addr to rxrd
	; DE destroyed...
	lded	msglen
	lhld	curptr
	call	cpyin	; get payload
	lda	cursok
	ori	sock0
	mov	d,a
	mvi	a,RECV
	call	wizcmd
	; ignore Sn_SR?
	lhld	totlen	; might be neg (first pass)
	mov	a,h
	ora	a
	jp	rm1
	; can we guarantee at least msg hdr?
	ldx	a,+4	; msg siz (-1)
	adi	5+1	; header, +1 for (-1)
	mov	e,a
	mvi	a,0
	adc	a
	mov	d,a	; true msg len
	dad	d	; subtract what we already have
	jrnc	rerr	; something is wrong, if still neg
	shld	totlen
	mov	a,h
rm1:	ora	l
	jnz	rm0
	ret	; success (A=0)

rerr:	lda	CFGTBL
	ori	rcverr
	sta	CFGTBL
err:	mvi	a,0ffh
NTWKER:	ret

NTWKBT:	; NETWORK WARM START
	lda	CFGTBL
	ani	active
	jz	NTWKIN	; will end up back here, on success
ntwkbt0:
	; load socket server IDs based on WIZ550io current config
	mvi	b,nsocks
	lxi	d,(sock0 shl 8) + sn$prt
	lxi	h,srvtbl
nb1:
	push	h
	call	getwiz2	; destroys C,HL
	mov	a,h
	cpi	31h
	mvi	a,0ffh
	jrnz	nb0
	mov	a,l	; server ID
nb0:	pop	h
	mov	m,a
	inx	h
	mvi	a,001$00$000b
	add	d	; next socket
	mov	d,a
	djnz	nb1
	xra	a
	ret

NTWKDN:	; close all sockets
	mvi	b,nsocks
	mvi	d,sock0
nd0:	mvi	e,sn$sr
	call	getwiz1
	cpi	CLOSED
	jz	nd1
	mvi	a,CLOSE
	push	b
	call	wizcmd	; destroys B
	pop	b
	; TODO: can these overlap?
nd1:	mvi	a,001$00$000b
	add	d	; next socket
	mov	d,a
	djnz	nd0
	xra	a
	ret

	end
