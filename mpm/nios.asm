; Server NIOS for WizNET W5500-based devices, via parallel-SPI interface
;
; In addition to the standard IP, MASK, MAC, and GATEWAY, requires:
; PMAGIC - server node ID (00-FE)
; PDMAC - (first 2 bytes) listening port number

	maclib	z80

	; Server interface
	public	NTWKIN, NTWKST, SNDMSG, RCVMSG, NWPOLL, NTWKER, NTWKDN
	extrn	CFGADR	; Server Config Table, from NetWrkIF
	; Caller(s) of SNDMSG, RCVMSG, NWPOLL must mutex.

; TODO: set all "idle" sockets to LISTEN... each one going
; to ESTABLISHED indicates a connection.
; TODO: how to configure IP/PORT???

	maclib	config

nsocks	equ	8
; W5500 supports only 8 sockets. One is the LISTENer.
; That leaves 7 for requesters. But, if we need to be able to
; service an attach when full, then only 6 requesters can be
; active.
; That means the maximum number of logged-in requesters is 6.
; TODO: provide this information to NetWrkIF.

sock0	equ	000$01$000b	; base pattern for Sn_ regs
txbuf0	equ	000$10$100b	; base pattern for Tx buffer
rxbuf0	equ	000$11$000b	; base pattern for Rx buffer

; common regs
ir	equ	21
sir	equ	23
pmagic	equ	29
pdmac	equ	30	; 2-byte port number for listening

; socket regs, relative
sn$mr	equ	0
sn$cr	equ	1
sn$ir	equ	2
sn$sr	equ	3
sn$prt	equ	4
sn$txwr	equ	36
sn$rxrsr equ	38
sn$rxrd	equ	40

; socket commands
OPEN	equ	01h
LISTEN	equ	02h
CONNECT	equ	04h
CLOSE	equ	08h	; DISCONNECT, actually
SEND	equ	20h
RECV	equ	40h

; socket status
CLOSED	equ	00h
INIT	equ	13h
ESTAB	equ	17h
LISTN	equ	14h

	cseg

;	Network Status Byte Equates
;
active		equ	0001$0000b	; slave logged in on network
rcverr		equ	0000$0010b	; error in received message
senderr 	equ	0000$0001b	; unable to send message

srvtbl:	ds	nsocks

lport:	dw	0	; port to listen on
srvid:	db	0	; this server's NID
cursok:	db	0	; current socket select patn
curskp:	dw	0	; current socket srvtbl[x]
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
gs0:	; found... DE=srvtbl[x]
	push	d
	mvi	a,nsocks
	sub	c	; socket num 00000sss
	rrc		; s00000ss
	rrc		; ss00000s
	rrc		; sss00000
	sta	cursok
	sded	curskp
	ori	sock0	; sss01000
	mov	d,a
	mvi	e,sn$sr
	call	getwiz1
	pop	h	; HL=srvtbl[x]
	cpi	ESTAB
	rz	; D=socket
	; lost connection, reset things
	mvi	m,0ffh
	; polling should set back to LISTEN
	stc	; failed
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

; Setup socket for LISTENing, unless already LISTN or ESTAB.
; A=Sn_SR, D=socket, HL=srvtbl[socket]
; Destroys B, C, E (D r/w bit)
do$listen:
	mvi	m,0ffh	; flag "no connection"
	cpi	CLOSED
	jrz	dl0
	mvi	a,CLOSE
	call	wizcmd	; destroys B
dl0:
	; try to open socket...
	mvi	a,OPEN
	call	wizcmd	; destroys B
	cpi	INIT
	rnz	; flag error?
	mvi	a,LISTEN
	call	wizcmd	; destroys B
	cpi	LISTN
	ret	; NZ indicates error

;	Utility Procedures
;
;	Network Initialization
NTWKIN:
	lixd	CFGADR
	lxi	d,pmagic
	call	getwiz1
	cpi	0ffh	; the only illegal value for servers
	jz	err
	stx	a,+1 ; our server ID
	sta	srvid
	mvi	e,pdmac
	call	getwiz2
	shld	lport	; listening port
	mvi	a,active
	stx	a,+0 ; network status byte
	; initialize all sockets for listening...
	mvi	c,nsocks
	lxi	h,srvtbl
	mvi	d,sock0
nwin0:
	push	b
	mvi	e,sn$mr
	mvi	a,1	; TCP/IP mode
	call	putwiz1
	push	h
	lhld	lport
	mvi	e,sn$prt
	call	putwiz2	; set port
	mvi	e,sn$sr
	call	getwiz1	; A=Sn_SR
	pop	h	; HL=srvtbl[x]
	call	do$listen
	; TODO: errors?
	pop	b
	inx	h
	mvi	a,001$00$000b
	add	d	; next socket
	mov	d,a
	dcr	c
	jrnz	nwin0
	xra	a
	ret

;	Network Status
NTWKST:
	lhld	CFGADR
	mov	a,m
	mov	b,a
	ani	not (rcverr+senderr)
	mov	m,a
	mov	a,b
	ret

;	Send Message on Network
;	BC = message addr
SNDMSG:
	sbcd	msgptr	; store BC addr into msgptr
	lixd	msgptr	; put message pointer into index register
	ldx	b,+1	; SID - destination
	call	getsrv
	jrc	serr
	; D=socket patn
	lda	srvid
	stx	a,+2	; Set our ID in header
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
	call	wizcmd	; TODO: how long might this take?
	; ignore Sn_SR?
	mvi	c,00011010b	; SEND_OK, DISCON, or TIMEOUT bit
	call	wizist
	cma	; want "0" on success
	ani	00010000b	; SEND_OK
	rz
	; else TIMEOUT/DISCON
serr:
	lhld	CFGADR
	mov	a,m
	ori	senderr
	mov	m,a
	mvi	a,0ffh
	ret

; Poll for a message to be received.
; Check sockets regardless of whether srvtbl[x] indicates requester.
; First socket found is stored in cursok.
; Returns 0 if nothing to do, 0ffh if RECV ready at cursok.
; Always scans all sockets, to ensure dropped coonections get re-initialized.
NWPOLL:
	mvi	d,sock0
	mvi	b,nsocks
	mvi	l,00000100b	; RECV data available bit
	xra	a
	push	psw	; reinit=false
chk2:
	mvi	e,sn$sr
	call	getwiz1
	cpi	ESTAB
	jrz	chk3
	cpi	LISTN
	jrz	chk5	; nothing for us to do, yet
	; else, try to re-init
	pop	psw
	ori	0ffh	; reinit=true
	push	psw
chk5:	mvi	a,001$00$000b
	add	d	; next socket
	mov	d,a
	djnz	chk2
	; if we get through all sockets (and no RECV),
	; re-init any that require it.
	pop	psw
	rz		; if (not reinit) nothing to do
	; check all sockets and re-open as needed
	mvi	d,sock0
	mvi	b,nsocks
	lxi	h,srvtbl
chk4:
	mvi	e,sn$sr
	call	getwiz1
	cpi	ESTAB
	jrz	chk1
	cpi	LISTN
	jrz	chk1
	push	b
	call	do$listen	; destroys E,B
	pop	b
chk1:
	inx	h
	mvi	a,001$00$000b
	add	d	; next socket
	mov	d,a
	djnz	chk4
	xra	a	; nothing to RECV yet
	ret
chk3:
	call	wizsts
	ana	l	; RECV data available
	jrz	chk5	; not ready...
	pop	psw	; discard reinit flag
	mov	a,d
	ani	11100000b ; remove chaff
	sta	cursok
	; compute srvtbl[x] address
	rlc
	rlc
	rlc
	mov	e,a
	mvi	d,0
	lxi	h,srvtbl
	dad	d
	shld	curskp
	ori	0ffh	; ready=true
	ret

;	Receive Message from Network
;	BC = message addr
;	NWPOLL must be called first, and return .TRUE.
RCVMSG:
	sbcd	msgptr
	lda	cursok	; can't check for invalid
	ori	sock0
	mov	d,a	; socket that is ready...
	; D=socket
	lixd	msgptr
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
	lded	curskp
	; TODO: check/validate? (what if different?)
	ldx	a,+2	; SID - sender (requester)
	stax	d	; set SID, use same socket for reply
	lda	cursok	; must restore D=socket BSB
	ori	sock0
	mov	d,a
	mov	a,h
rm1:	ora	l
	jnz	rm0
	ret	; success (A=0)

rerr:
	lhld	CFGADR
	mov	a,m
	ori	rcverr
	mov	m,a
err:	mvi	a,0ffh
NTWKER:	ret

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
