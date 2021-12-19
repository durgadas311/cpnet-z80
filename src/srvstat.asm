; Get Server Status
	maclib	z80

cpm	equ	0
bdos	equ	5
cmdbuf	equ	0080h

; Offsets in Server Config Table
TEMP	equ	0
STS	equ	1
ID	equ	2
MAX	equ	3
CUR	equ	4
VEC	equ	5	; 2 bytes
RID	equ	7	; start of remote IDs

	org	00100h

	jmp	start

signon:	db	13,10,'Server Status'
	db	13,10,'============='
	db	'$'
sidmsg:	db	13,10,'Server ID = $'
stsmsg:	db	13,10,'Server Status Byte = $'
tmpmsg:	db	13,10,'Temp Drive = $'
maxmsg:	db	13,10,'Maximum Requesters = $'
nummsg:	db	13,10,'Number of Requesters = $'
reqmsg:	db	13,10,'Requesters logged in:$'
nonmsg:	db	13,10,'  (none)$'
spcmsg:	db	13,10,'  $'
cpnerr:	db	13,10,'CP/NET has not been loaded.$'
cfgerr:	db	13,10,'Unable to get Server Config Table.$'

start:
	sspd	usrstk
	lxi	sp,stack
	call	getver
	mov	a,h
	ani	01h
	jnz	dompm
	mov	a,h
	ani	02h
	jz	nocpnt
	call	parse	; might set 'sid'

	lxi	d,signon	; Intro
	call	msgout

	call	getcfg
	mov	a,l
	ora	h
	jz	nocfg
	mov	a,l
	ana	h
	cpi	0ffh
	jz	nocfg

	shld	nettbl
show:
	lixd	nettbl

	lxi	d,sidmsg
	call	msgout
	ldx	c,ID
	call	hexout

	lxi	d,stsmsg	; Net Sts Byte
	call	msgout
	ldx	c,STS
	call	hexout

	lxi	d,tmpmsg
	call	msgout
	ldx	a,TEMP
	adi	'A'
	call	chrout
	mvi	a,':'
	call	chrout

	lxi	d,maxmsg
	call	msgout
	ldx	a,MAX
	call	decout

	lxi	d,nummsg
	call	msgout
	ldx	a,CUR
	call	decout

	lxi	d,reqmsg
	call	msgout
	ldx	l,VEC
	ldx	h,VEC+1
	ldx	a,CUR
	ora	a
	jz	none
	lxi	d,RID
	dadx	d
	mvi	b,16
drvlup:
	mov	a,l
	ani	1
	jz	noreq
	lxi	d,spcmsg
	call	msgout
	ldx	c,+0
	call	hexout
noreq:	inxix
	rarr	h
	rarr	l
	djnz	drvlup
	jmp	exit

; MP/M system - check for server config table
dompm:
	lxi	d,signon	; Intro - TODO: diff for MP/M?
	call	msgout
	mvi	c,154
	call	bdos
	mvi	l,9	; CP/NET server cfg
	mov	e,m
	inx	h
	mov	d,m	;
	mvi	l,196	; temp drive
	mov	a,m	; (0=def, 1=A:, ...)
	dcr	a	; unclear what 'def' should do
	sta	mpmtbl+TEMP
	mov	a,e
	ora	d
	jz	nocfg
	xchg
	lxi	d,mpmtbl+STS
	lxi	b,22	; TODO: include password?
	ldir
	lxi	h,mpmtbl
	shld	nettbl
	jmp	show

none:	lxi	d,nonmsg
	call	msgout
	jmp	exit

nocfg:	lxi	d,cfgerr
	jmp	no1

nocpnt:	lxi	d,cpnerr	; CP/NET has not been loaded
no1:	call	msgout
exit:	lhld	usrstk
	sphl
	ret

chrout:
	pushix
	push	h
	push	b
	mov	e,a
	mvi	c,002h
	call	bdos
	pop	b
	pop	h
	popix
	ret

msgout:
	pushix
	push	h
	push	b
	mvi	c,009h
	call	bdos
	pop	b
	pop	h
	popix
	ret

getver:
	mvi	c,12
	call	bdos
	ret

getcfg:
	; TODO: check if server "exists"?
	lda	sid
	mov	e,a
	mvi	c,047h
	call	bdos
	ret

parse:	lxi	h,cmdbuf
	mov	b,m
	inr	b
pars0:	inx	h
	dcr	b
	rz
	mov	a,m
	cpi	' '
	jz	pars0
	call	parshx
	jc	nocfg
	mov	a,d
	sta	sid
	ret

; HL=cmdbuf, B=len
; returns CY if error, Z if term char, NZ end of text, D=number
parshx:
	mvi	d,0
pm0:	mov	a,m
	cpi	' '
	jz	nzret
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
	mov	e,a
	mov	a,d
	add	a
	rc
	add	a
	rc
	add	a
	rc
	add	a
	rc
	add	e	; carry not possible
	mov	d,a
	inx	h
	djnz	pm0
nzret:
	xra	a
	inr	a	; NZ
	ret

crlf:
	mvi	a,13
	call	chrout
	mvi	a,10
	call	chrout
	ret

; leading zeroes blanked - must preserve B
decout:
	push	b
	mvi	c,0
	mvi	d,100
	call	divide
	mvi	d,10
	call	divide
	adi	'0'
	call	chrout
	pop	b
	ret

divide:	mvi	e,0
div0:	sub	d
	inr	e
	jrnc	div0
	add	d
	dcr	e
	jrnz	div1
	bit	0,c
	jrnz	div1
	ret
div1:	setb	0,c
	push	psw	; remainder
	mvi	a,'0'
	add	e
	call	chrout
	pop	psw	; remainder
	ret

hexout:
	push	b
	mov	a,c
	rrc
	rrc
	rrc
	rrc
	call	hexdig
	pop	b
	mov	a,c
	call	hexdig
	mvi	a,'H'
	call	chrout
	ret

hexdig:
	ani	0fh
	adi	90h
	daa
	aci	40h
	daa
	jmp	chrout

	ds	40
stack:	ds	0
usrstk:	dw	0

sid:	db	0
count:	db	0
nettbl:	dw	0

mpmtbl:	ds	23	; copied from MP/M system data
	; TODO: also show password?

	end
