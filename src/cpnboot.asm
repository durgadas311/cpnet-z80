; Runs under CP/M, boots using network and the "loader" style

	maclib	z80

	extrn	NTWKIN,NTWKST,CNFTBL,SNDMSG,RCVMSG,NTWKER,NTWKBT,NTWKDN,CFGTBL
	extrn	platfm	; platform descriptive string, $-terminated

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

; relative locations in cpnos (.sys) image
memtop	equ	0	; top of memory, 00 = 64K
comlen	equ	1	; common length
bnktop	equ	2	; banked top (not used)
bnklen	equ	3	; banked length (00)
entry	equ	4	; entry point of OS
cfgtab	equ	6	; CP/NET cfgtbl
org0	equ	16	; not used(?)
ldmsg	equ	128	; load map/message ('$' terminated)
recs	equ	256	; records to load, top-down

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
	jmp	boot

error:
	lxi	h,neterr
err0:
	mvi	c,fprnt
	call	bdos
	lda	init
	ora	a
	cnz	NTWKDN
	jmp	retcpm

syntax:
	lxi	h,netsyn
	jr	err0

signon:	db	' Network Loader',CR,LF,'$'
cpnet:	db	CR,LF,BEL,'CP/NET is already running',CR,LF,'$'
nocpm3:	db	CR,LF,BEL,'Not intended for CP/M 3',CR,LF,'$'
netsyn:	db	CR,LF,BEL,'Command syntax error',CR,LF,'$'
neterr:	db	CR,LF,BEL,'Network boot error',CR,LF,'$'
newline: db	CR,LF,'$'
init:	db	0

defmap:
	db	80h,0	; A:=A:
	db	80h,17	; LST:=0
	db	0
	; TODO: allow customization of maps
boot:
	; make certain line is NUL-terminated.
	lxi	h,cmdlin
	mov	c,m
	mvi	b,0
	inx	h
	dad	b
	mvi	m,0

	lxi	d,cmdlin+1
bn7:	call	getaddr ;get server ID, ignore extra MSDs
	jc	syntax	; error if invalid
	bit	7,b	;test for no entry
	mvi	a,0
	jrnz	bn8	;use 00
	mov	a,l
bn8:	sta	boot$server
	push	d	; save line pointer
	mvi	a,0ffh	; we don't know yet...
	sta	CFGTBL+1
	call	NTWKIN	; trashes msgbuf...
	pop	d
	ora	a
	jnz	error
	mvi	a,-1
	sta	init

	lxi	h,msgbuf+DAT
	mvi	b,2	; always two bytes
	; fill in basics...
	lda	retcpm+2
	mov	m,a	; BIOS page
	inx	h
	lda	bdos+2
	mov	m,a	; BDOS page
	inx	h
	lxix	defmap
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
loop:
	lda	boot$server
	sta	msgbuf+DID
	lda	CFGTBL+1
	sta	msgbuf+SID
	mvi	a,0b0h
	sta	msgbuf+FMT
	call	netsr	; send request, receive response
	jc	error	; network error
	lda	msgbuf+FMT
	cpi	0b1h
	jnz	error	; invalid response
	lda	msgbuf+FNC
	ora	a
	jz	error	; NAK
	dcr	a
	jrz	ldtxt
	dcr	a
	jrz	stdma
	dcr	a
	jrz	load
	dcr	a
	jnz	error	; unsupported function
	; done - execute boot code
	call	crlf
	lhld	msgbuf+DAT
	pchl	; jump to code...
load:	lhld	dma
	xchg
	lxi	h,msgbuf+DAT
	lxi	b,128
	ldir
	xchg
	shld	dma
netack:
	xra	a
	sta	msgbuf+FNC
	sta	msgbuf+SIZ
	jr	loop
stdma:
	lhld	msgbuf+DAT
	shld	dma
	jr	netack
ldtxt:
	call	crlf
	lxi	d,msgbuf+DAT
	call	print
	jr	netack

netsr:
	lxi	b,msgbuf
	call	SNDMSG
	ora	a
	jrnz	netsre
	lxi	b,msgbuf
	call	RCVMSG
	ora	a
	rz
netsre:	stc
	ret

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

print:	push	h
	push	d
	push	b
	mvi	c,fprnt
	call	bdos
	pop	b
	pop	d
	pop	h
	ret

; variables to network boot CP/NOS
	dseg
boot$server	ds	1
retry$count:	ds	1
msg$adr:	ds	2
dma:		ds	2
msgbuf:		ds	5+256
		ds	256
nbstk:		ds	0

	end
