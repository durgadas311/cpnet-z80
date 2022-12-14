; Runs under CP/M, boots using network and the "loader" style

	maclib	z80
	maclib	config

	extrn	platfm	; platform descriptive string, $-terminated
if NVRAM
	extrn	wizcfg
	public	nvbuf
endif
	extrn	netboot
	public	ldmsg,srvid

false	equ	0
true	equ	not false

	$*MACRO

; CP/M constants
retcpm	equ	0
bdos	equ	5
cmdlin	equ	80h

fcono	equ	2
fprnt	equ	9
fvers	equ	12

CR	equ	13
LF	equ	10
CTLC	equ	3
BEL	equ	7
TAB	equ	9
BS	equ	8
ESC	equ	27
TRM	equ	0
DEL	equ	127

; offsets in msgbuf
FMT	equ	0
DID	equ	1
SID	equ	2
FNC	equ	3
SIZ	equ	4
DAT	equ	5

; Usage: CPNBOOT [nid [args...]]

	; CP/M TPA... where we live
	cseg
	lxi	sp,nbstk
	mvi	c,fvers
	call	bdos
	mov	a,l
	cpi	30h	; not intended for CP/M 3
	jrnc	cpm3err
	mov	a,h
	ani	02h
	jrz	nocpn
	lxi	d,cpnet
err1:	mvi	c,fprnt
	call	bdos
	jmp	retcpm

cpm3err:
	lxi	d,nocpm3
	jr	err1

nocpn:	; CP/NET not running, OK to boot
	lxi	d,platfm
	mvi	c,fprnt
	call	bdos
	lxi	d,signon
	mvi	c,fprnt
	call	bdos
if NVRAM
	call	wizcfg
	cc	nocfg
endif
	jmp	boot

error:
	lxi	d,neterr
err0:
	mvi	c,fprnt
	call	bdos
	jmp	retcpm

syntax:
	lxi	d,netsyn
	jr	err0

; Usage: CPNBOOT [sid|map...] [tag]
signon:	db	' Network Loader',CR,LF,'$'
cpnet:	db	CR,LF,BEL,'CP/NET is already running',CR,LF,'$'
nocpm3:	db	CR,LF,BEL,'Not intended for CP/M 3',CR,LF,'$'
netsyn:	db	CR,LF,BEL,'Command syntax error',CR,LF,'$'
neterr:	db	CR,LF,BEL,'Network boot error',CR,LF,'$'
newline: db	CR,LF,'$'

defmap:
	db	80h,0	; A:=A:
	db	80h,17	; LST:=0
	db	0

; Parse SID or maps (A:=B:, LST:=0)
; Returns HL=tag (or end of line), CY on error
parse:	lxi	h,cmdlin+1	; now it is NUL terminated
	lxiy	newmap
par0:	mviy	0,+0	; terminate current map list entry
	call	token
	rz	; HL=end of args
	bit	1,b	; ZR=sid
	jrnz	par1
	; parse SID and store it
	push	d	; next token start...
	push	h
	xchg	; DE=token
	call	getaddr
	mov	a,h
	ora	a
	mov	a,l
	sta	srvid
	pop	h	; discard
	pop	h	; next token start
	jrnz	parerr	; if not 00-FF
	jr	par0
par1:	bit	0,b	; NZ=map
	rz	; must be tag, HL=string begin
	; strict format, either A:=B: or LST:=0
	push	h
	popix
	mvi	a,':'
	cmpx	+1
	jrnz	par2	; might be LST:
	cmpx	+4
	jrnz	parerr
	ldx	a,+0	; local drive
	sui	'A'
	jrc	parerr
	cpi	16
	jrnc	parerr
	mov	c,a	; local device (0-15)
	ldx	a,+3	; remote drive
	sui	'A'
	jrc	parerr
	cpi	16
	jrnc	parerr
	ori	80h
	mov	b,a	; remote device (0-15) and flag
par4:
	sty	b,+0	; remote device (0-15) and flag
	sty	c,+1	; local device (0-15)
	inxiy
	inxiy
	xchg		; HL=next token start
	jr	par0
par2:	; might be LST:=X (A=':')
	cmpx	+3
	jrnz	parerr
	ldx	a,+0
	cpi	'L'
	jrnz	parerr
	ldx	a,+1
	cpi	'S'
	jrnz	parerr
	ldx	a,+2
	cpi	'T'
	jrnz	parerr
	ldx	a,+5	; remote list number
	call	hexcon
	jrc	parerr
	ori	80h
	mov	b,a
	mvi	c,17	; load LST: device number
	jr	par4

parerr:	stc
	ret

; find token, HL=cur line ptr (should point to blank)
; Returns HL=start, DE=end, B=flags, A=0/ZR if none left
token:	call	skipb
	ora	a
	rz	; HL=end of args
	push	h
	call	skipnb
	xchg
	pop	h
	ori	1	; anything non-zero
	ret

; skip blank chars
skipb:	mov	a,m
	cpi	' '
	rnz
	inx	h
	jr	skipb

; skip non-blank chars (skip to next blank)
; Returns B=flags (bits: 0=mapping, 1=not hex)
skipnb:	mvi	b,0	; flags
snb0:	mov	a,m
	ora	a
	rz
	cpi	' '
	rz
	cpi	'='
	jrnz	snb1
	setb	0,b	; must be mapping
snb1:	bit	1,b
	jrnz	snb2
	call	hexcon	; destroys A (maybe)
	jrnc	snb2
	setb	1,b	; not valid hex
snb2:	inx	h
	jr	snb0
	
boot:
	; make certain line is NUL-terminated.
	lxi	h,cmdlin
	mov	c,m
	mvi	b,0
	inx	h
	dad	b
	mvi	m,0

	xra	a	; default SID 00
	sta	srvid
	call	parse
	jc	syntax	; error if invalid
	; HL=tag (or NUL)
	xchg	; line ptr to DE

	lxi	h,msgbuf+DAT
	mvi	b,2	; always two bytes
	; fill in basics...
	lda	retcpm+2
	mov	m,a	; BIOS page
	inx	h
	lda	bdos+2
	mov	m,a	; BDOS page
	inx	h
	push	d
	lxix	newmap
	bitx	7,+0	; any new maps?
	jrnz	nm1
if NVRAM
	lda	nverr
	ora	a
	jrnz	nonv
	; translate cfgtbl template into maps...
	lxix	nvbuf+288	; cfgtbl template
	mvi	b,16	; 16 drives
	mvi	c,0	; start at A:
	lda	srvid
	mov	e,a
nv0:	inxix
	inxix
	ldx	a,+0
	cpi	0ffh
	jrz	nv1
	mov	d,a
	mov	a,e
	cmpx	+1	; same server?
	jrnz	nv1
	mov	m,d
	inx	h
	mov	m,c
	inx	h
nv1:	inr	c
	djnz	nv0
	inxix	; skip CON:
	inxix
	ldx	a,+0
	cpi	0ffh
	jrz	nm0
	mov	d,a
	mov	a,e
	cmpx	+1	; same server?
	jrnz	nm0
	mov	m,d
	inx	h
	mvi	m,17	; LST: device number
	inx	h
	jr	nm0
nonv:
endif
	lxix	defmap	; else use defaults
nm1:	ldx	a,+0
	ora	a
	jrz	nm0
	mov	m,a
	inx	h
	ldx	a,+1
	mov	m,a
	inx	h
	inr	b
	inr	b
	inxix
	inxix
	jr	nm1
nm0:
	pop	d
	push	h	; save start of string
	; now pass string, if present
	mvi	m,0	; len, re-set later
	inx	h
	mvi	c,2	; strlen incl. len and NUL
bn1:
	call	char
	jrz	bn2	; no string present
	cpi	' '
	jrz	bn1	; skip leading blanks
bn0:	mov	m,a
	inx	h
	inr	c
	call	char
	jrnz	bn0	; copy whole string... can't exceed 128?
bn2:	mvi	m,0	; NUL term
	mov	a,c	; SIZ incl NUL
	add	b	; previous header bytes
	dcr	a	; SIZ is N-1
	sta	msgbuf+SIZ
	mov	a,c
	dcr	a	; len is without len byte
	pop	h	; len byte of string...
	mov	m,a
	mvi	a,2	; FNC=2 is loader boot style
	sta	msgbuf+FNC
	lxi	h,msgbuf
	call	netboot
	jc	error
	; HL = start address
	push	h
	call	crlf
	pop	h
	pchl

; Get next character from NUL-terminated line buffer (DE).
char:	ldax	d
	ora	a
	rz
	inx	d
	ret

; Get HEX value from line buffer
; Return: CY=error, HL=value, bit7(B)=1 if no input
getaddr:		;extract address from line buffer (dilimitted by " ")
	setb	7,b	;flag to detect no address entered
	lxi	h,0
ga2:	call	char
	rz		;end of buffer/line before a character was found
	cpi	' '	;skip all leading spaces
	jrnz	ga1	;if not space, then start getting HEX digits
	jr	ga2	;else if space, loop untill not space

ga0:	call	char
	rz
ga1:	call	hexcon	;start assembling digits into 16 bit accumilator
	jrc	chkdlm	;check if valid delimiter before returning error.
	res	7,b	;reset flag
	push	d	;save buffer pointer
	mov	e,a
	mvi	d,0
	dad	h	;shift "accumilator" left 1 digit
	dad	h
	dad	h
	dad	h
	dad	d	;add in new digit
	pop	d	;restore buffer pointer
	jr	ga0	;loop for next digit

chkdlm: cpi	' '	;blank is currently the only valid delimiter
	rz
	stc
	ret

hexcon: 		;convert ASCII character to HEX digit
	cpi	'0'	;must be .GE. "0"
	rc
	cpi	'9'+1	;and be .LE. "9"
	jrc	ok0	;valid numeral.
	cpi	'A'	;or .GE. "A"
	rc
	cpi	'F'+1	;and .LE. "F"
	cmc
	rc		;return [CY] if not valid HEX digit
	sui	'A'-'9'-1	;convert letter
ok0:	sui	'0'	;convert (numeral) to 0-15 in (A)
	ret

crlf:	push	d
	lxi	d,newline
	call	print
	pop	d
	ret

; DE='$'-terminated message
print:	push	h
	push	d
	push	b
	mvi	c,fprnt
	call	bdos
	pop	b
	pop	d
	pop	h
	ret

ldmsg:	push	h
	call	crlf
	pop	d
	jr	print

if NVRAM
nocfg:	mvi	a,1
	sta	nverr
	lxi	d,ncfg
	jmp	print

ncfg:	db	'NVRAM not configured',CR,LF,'$'
nverr:	db	0
endif

; variables to network boot CP/NOS
	dseg
srvid:		ds	1
msgbuf:		ds	5+256
		ds	256
nbstk:		ds	0

if NVRAM
nvbuf:		ds	512
endif

newmap:		ds	0

	end
