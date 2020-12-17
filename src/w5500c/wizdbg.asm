; A debug util for WizNET W5500-based devices, via parallel-SPI interface
;
; Commands:
;	g <bsb> <off> <num>	Get <num> bytes from <bsb> at <off>
;	s <bsb> <off> <dat>...	Set bytes to <bsb> at <off>

	maclib	z180

	maclib	config
if 0
	extrn	wizcfg, wizcmd, wizget, wizset, wizclose, setsok, settcp
	public	nvbuf ; dummy
endif

WRITE	equ	00000100b

CR	equ	13
LF	equ	10

cpm	equ	0
bdos	equ	5
cmdlin	equ	0080h

print	equ	9
getver	equ	12

	org	00100h

	jmp	start

usage:	db	'Usage: WIZDBG {G bsb off num}',CR,LF
	db	'       WIZDBG {S bsb off dat...}',CR,LF
	db	'       bsb = Block Select Bits, hex 00..1F',CR,LF
	db	'       off = Offset within BSB, hex',CR,LF
	db	'       num = Number of bytes to GET, dec',CR,LF
	db	'       dat = Byte(s) to SET, hex',CR,LF,'$'
nocpn:	db	'CP/NET is running. Stop it first',CR,LF,'$'
cpnet:	db	0

start:
	sspd	usrstk
	lxi	sp,stack
	mvi	c,getver
	call	bdos
	mov	a,h
	ani	02h
	sta	cpnet
	lhld	bdos+1	; compute max buf space
	mvi	l,0	;
	dcr	h	; safety margin
	lxi	d,buf
	ora	a
	dsbc	d
	mvi	l,0	; more safety margins
	shld	max
; start parsing commandline
	lda	cmdlin
	ora	a
	jz	help

	lxi	h,cmdlin
	mov	b,m
	inx	h
pars0:
	mov	a,m
	cpi	' '
	jnz	pars1
	inx	h
	djnz	pars0
	jmp	help

pars1:
	cpi	'G'
	jz	pars2
	cpi	'S'
	jnz	help
	lda	cpnet
	ora	a
;	jnz	nocpnt	; djrm, comment out to allow writing during program testing
	mvi	a,'S'
pars2:
	sta	com
	call	skipb
	jc	help
	; <bsb> and <off> are always present,
	; plus either <num> or (at least) one <dat>.
	call	parshx
	jc	help
	mov	a,d
	ora	a
	jnz	help
	mov	a,e
	cpi	32	; 00..1F allowed
	jnc	help
	rlc
	rlc
	rlc
	sta	bsb
	call	skipb
	jc	help
	call	parshx
	jc	help
	xchg
	shld	off
	xchg
	call	skipb
	jc	help
	lda	com
	cpi 	'G'
	jz	get
	mvi	c,0
	lxix	buf
set0:
	call	parshx
	jc	help
	mov	a,d
	ora	a
	jnz	help
	stx	e,+0
	inxix
	inr	c	; can't overflow with 128-byte buffer
	mov	a,b
	ora	a
	jz	set1
	call	skipb
	jnc	set0
set1:
	mov	a,c
	sta	num
	call	wizset
	jmp	exit

get:
	call	parsnm
	jc	help
	; done parsing command, can destroy HL/B
	lhld	max
	ora	a
	dsbc	d
	jc	help	; or "overflow"? "too large"?
	sded	num
	call	wizget
	lxi	h,buf
	push	h
; dump 'num' bytes from 'buf'... label with bsb/off...
get0:
	lda	bsb
	ani	11111000b
	rrc
	rrc
	rrc
	call	hexout
	mvi	a,':'
	call	chrout
	lhld	off
	call	wrdout
	; now output <=16 bytes " XX"...
	mvi	b,16
get1:
	mvi	a,' '
	call	chrout
	pop	h
	mov	a,m
	inx	h
	push	h
	call	hexout
	lhld	off
	inx	h
	shld	off
	lhld	num
	dcx	h
	shld	num
	mov	a,h
	ora	l
	jz	get2
	djnz	get1
	call	crlf
	jmp	get0
get2:
	call	crlf
exit:
	jmp	cpm

help:
	lxi	d,usage
xitmsg:
	mvi	c,print
	call	bdos
	jmp	exit

nocpnt:
	lxi	d,nocpn
	jmp	xitmsg

if 1
;------------------------------------------------------------------------------
cmirror:
	mov	c,a		; a = 76543210
	rlc
	rlc			; a = 54321076
	xra	c
	ani	0AAh
	xra	c		; a = 56341270
	mov	c,a
	rlc
	rlc
	rlc			; a = 41270563
	rrcr	c		; l = 05634127
	xra	c
	ani	66h
	xra	c		; a = 01234567
	mov	c,a
	ret

cslower:
	in0	a,(CNTR)	;check the CSIO is not enabled
	ani	CNTRTE+CNTRRE
	jrnz	cslower
	mvi	a,0f7h
	out0	a,(IOSYSTEM)
	ret

csraise:
	in0	a,(CNTR)	;check the CSIO is not enabled
	ani	CNTRTE+CNTRRE
	jrnz	csraise

	mvi	a,0ffh		;SC130 SC1 CS is on Bit 2 and SC126 SC2 CS is on Bit 3, raise both.
	out0	a,(IOSYSTEM)
	ret

writebyte:
	call	cmirror		; reverse the bits before we busy wait
writewait:
	in0	a,(CNTR)
	tsti	CNTRTE+CNTRRE	; check the CSIO is not enabled
	jrnz	writewait

	ori	CNTRTE		; set TE bit
	out0	c,(TRDR)	; load (reversed) byte to transmit
	out0	a,(CNTR)	; enable transmit
	ret

readbyte:
	in0	a,(CNTR)
	tsti	CNTRTE+CNTRRE	; check the CSIO is not enabled
	jrnz	readbyte

	ori	CNTRRE		; set RE bit
	out0	a,(CNTR)	; enable reception
readwait:
	in0	a,(CNTR)
	tsti	CNTRRE		; check the read has completed
	jrnz	readwait

	in0	a,(TRDR)	; read byte
	jmp	cmirror		; reverse the byte, leave in C and A

;------------------------------------------------------------------------------
; Read (GET) data from chip.
; 'num', 'bsb', 'off' setup.
; Returns: 'buf' filled with 'num' bytes.
wizget:
	call 	cslower
	lhld	off
	mov	a,h
	call	writebyte	; addr hi
	lhld	off
	mov	a,l
	call	writebyte	; addr lo
	lda	bsb		;
	call	writebyte
	lhld    num             ; count into HL
	lxi	d,buf		; address to save to, DE
wizgetloop:
 	call	readbyte 	; data
	stax	d
    	inx	d		; ptr++
        dcx     h               ; count down 1
        mov     a,h
        ora     l
        jrnz    wizgetloop
	call	csraise
	ret

;------------------------------------------------------------------------------
; Write (SET) data in chip.
; 'num', 'buf', 'bsb', 'off' setup.
wizset:
	call 	cslower
	lhld	off
	mov	a,h
	call	writebyte	; addr hi
	lhld	off
	mov	a,l
	call	writebyte	; addr lo
	lda	bsb
	ori	WRITE
	call	writebyte
	lhld    num             ; count into HL
	lxi	d,buf		; data address
wizsetloop:
    	ldax	d
    	call 	writebyte
   	inx	d		; ptr++
        dcx 	h               ; count down 1
        mov     a,h
        ora     l
        jrnz    wizgetloop
	call	csraise
	ret

endif
; code unchanged below here
;------------------------------------------------------------------------------

chrout:
	push	h
	push	d
	push	b
	mov	e,a
	mvi	c,002h
	call	bdos
	pop	b
	pop	d
	pop	h
	ret

crlf:
	mvi	a,CR
	call	chrout
	mvi	a,LF
	call	chrout
	ret

; Print 16-bit hex value from HL
wrdout:
	push	h
	mov	a,h
	call	hexout
	pop	h
	mov	a,l
hexout:
	push	psw
	rrc
	rrc
	rrc
	rrc
	call	hexdig
	pop	psw
	;jmp	hexdig
hexdig:
	ani	0fh
	adi	90h
	daa
	aci	40h
	daa
	jmp	chrout

skipb:
	inx	h	; skip option letter
	dcr	b
	stc
	rz
skip0:	mov	a,m
	ora	a
	cpi	' '
	rnz	; no carry?
	inx	h
	djnz	skip0
	stc
	ret

; Parse (up to) 16-bit hex value.
; input: HL is cmd buf, B remaining chars
; returns number in DE, CY if error, NZ end of text
parshx:
	lxi	d,0
pm0:	mov	a,m
	cpi	' '
	rz
	sui	'0'
	rc
	cpi	'9'-'0'+1
	jc	pm3
	sui	'A'-'0'
	rc
	cpi	'F'-'A'+1
	cmc
	rc
	adi	10
pm3:
	ani	0fh
	xchg
	dad	h
	jc	pme
	dad	h
	jc	pme
	dad	h
	jc	pme
	dad	h
	jc	pme
	xchg
	add	e	; carry not possible
	mov	e,a
	inx	h
	djnz	pm0
nzret:
	xra	a
	inr	a	; NZ
	ret
pme:	xchg
	stc
	ret

; Parse a 16-bit (max) decimal number
parsnm:
	lxi	d,0
pd0:	mov	a,m
	cpi	' '
	rz
	cpi	'0'
	rc
	cpi	'9'+1
	cmc
	rc
	ani	0fh
	push	h
	mov	h,d
	mov	l,e
	dad	h	; *2
	jc	pd1
	dad	h	; *4
	jc	pd1
	dad	d	; *5
	jc	pd1
	dad	h	; *10
	jc	pd1
	mov	e,a
	mvi	d,0
	dad	d
	xchg
	pop	h
	rc
	inx	h
	djnz	pd0
	ora	a	; NC
	ret

pd1:	pop	h
	ret	; CY still set

	ds	40
stack:	ds	0
usrstk:	dw	0

com:	db	0
bsb:	db	0
off:	dw	0
num:	dw	0	; SET: one byte, GET: two bytes
max:	dw	0	; maximum <num> allowed (for GET)

buf:	ds	0
nvbuf:	ds	0

	end
