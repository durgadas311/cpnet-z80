; Translate text file between CP/M and Unix line-ends
	maclib	z80

WBOOT	equ	0000h
BDOS	equ	0005h
CMDLINE	equ	0080h

CR	equ	13
LF	equ	10
EOF	equ	26

CONOUT	equ	2
PRINT	equ	9
OPEN	equ	15
CLOSE	equ	16
SERFST	equ	17
SERNXT	equ	18
DELETE	equ	19
READ	equ	20
WRITE	equ	21
MAKE	equ	22
RENAME	equ	23
SETDMA	equ	26
SETATR	equ	30
PARSE	equ	152

BUFLEN	equ	128

	org	0100h
	jmp	start

infile:	ds	36
outfile: ds	36
tmpfile: ds	36

sawcr:	db	0
conv:	db	0
bytcnt:	db	0
flptr:	dw	0
flcnt:	db	0

pfcb:	dw	0	; text to parse
	dw	0	; output FCB

; TODO: support things like A:=B:*.asm[u]
start:
	lxi	sp,stack
	lxi	d,CMDLINE
	ldax	d
	inx	d
	ora	a
	jz	help
	mov	l,a
	mvi	h,0
	dad	d
	mvi	m,0	; ensure NUL terminated
	xchg
	shld	pfcb
	lxi	h,outfile
	shld	pfcb+2
	lxi	d,pfcb
	mvi	c,PARSE
	call	BDOS
	mov	a,h
	ana	l
	cpi	0ffh
	jz	parerr
	mov	a,m	; HL point to next, unparsed, char
	cpi	'='
	jnz	parerr
	inx	h
	shld	pfcb
	lxi	h,infile
	shld	pfcb+2
	lxi	d,pfcb
	mvi	c,PARSE
	call	BDOS
	mov	a,h
	ana	l
	cpi	0ffh
	jz	parerr
	mov	a,m	; HL point to next, unparsed, char
	cpi	'['
	jnz	parerr	; make this optional, default is no conversion?
	inx	h
	mov	a,m
	ani	0dfh	; toupper
	cpi	'U'
	jz	convok
	cpi	'C'
	jnz	parerr
convok:
	ani	010h	; 0=to-cp/m, ~0=to-unix
	sta	conv
	inx	h
	mov	a,m
	cpi	']'
	jnz	parerr
	inx	h
	mov	a,m
	ora	a
	jnz	parerr
	lxi	h,infile
	call	chkafn
	jnc	multcp
	lda	outfile+1
	cpi	' '
	jnz	noblank
	lxi	d,outfile+1
	lxi	h,infile+1
	lxi	b,11
	ldir
	lda	outfile+1
	cpi	' '
	jz	parerr
noblank:
	lxi	h,outfile
	call	chkafn
	jnc	parerr
	call	trfile	; errors abort, do not return here
	jmp	WBOOT

multcp:
	lda	outfile+1
	cpi	' '
	jnz	parerr
	; make list of matching files, then
	; translate each one...
	lxi	h,flist
	shld	flptr
	xra	a
	sta	flcnt
	lxi	d,inbuf
	mvi	c,SETDMA
	call	BDOS
	lxi	d,infile
	mvi	c,SERFST
	call	BDOS
	cpi	0ffh
	jz	inofile
serloop:
	rlc
	rlc
	rlc
	rlc
	rlc	; * 32
	mov	e,a
	mvi	d,0
	lxi	h,inbuf
	dad	d
	inx	h
	xchg
	lhld	flptr
	xchg
	lxi	b,11
	ldir
	xchg
	mvi	m,'$'
	inx	h
	shld	flptr
	lda	flcnt
	inr	a
	sta	flcnt
	lxi	d,0
	mvi	c,SERNXT
	call	BDOS
	cpi	0ffh
	jnz	serloop
	; got list of 'flcnt' files at 'flist'
	; There must be at least one if we get here...
	lxi	d,cpying
	mvi	c,PRINT
	call	BDOS
	lxi	h,flist
	lda	flcnt
floop:
	push	psw
	push	h
	lxi	d,fprefx
	mvi	c,PRINT
	call	BDOS
	pop	d
	push	d
	mvi	c,PRINT
	call	BDOS
	pop	h
	push	h
	lxi	d,infile+1
	lxi	b,11
	ldir
	lxi	h,infile+1
	lxi	d,outfile+1
	lxi	b,11
	ldir
	call	trfile
	pop	h
	pop	psw
	lxi	b,12
	dad	b
	dcr	a
	jnz	floop
	jmp	WBOOT

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

; Translate file infile => outfile
trfile:
	xra	a
	sta	infile+12
	sta	outfile+12
	lxi	h,outfile
	lxi	d,tmpfile
	lxi	b,16
	ldir
	lxi	h,tmpfile+9
	mvi	m,'$'
	inx	h
	mvi	m,'$'
	inx	h
	mvi	m,'$'
	; FCBs all setup.
	lxi	d,infile
	mvi	c,OPEN
	call	BDOS
	cpi	0ffh
	jz	inofile
	xra	a
	sta	infile+32
	lxi	d,tmpfile
	mvi	c,DELETE
	call	BDOS
	lxi	d,tmpfile
	mvi	c,MAKE
	call	BDOS
	cpi	0ffh
	jz	mkerr
	sta	sawcr
	call	infill
	call	outinit
chrloop:
	call	getchr
	cpi	EOF
	jz	ineof
	mvi	d,0
	cpi	CR
	jnz	notcr
	lda	conv
	ora	a
	jnz	chrloop	; to-unix: drop all CR
	inr	d
	mvi	a,CR
notcr:	cpi	LF
	jnz	notlf
	lda	conv
	ora	a
	jnz	crlfok	; to-unix: do not add back CR
	lda	sawcr
	ora	a
	jnz	crlfok
	mvi	a,CR
	call	putchr
	mvi	d,0
crlfok:
	mvi	a,LF
notlf:
	push	d
	call	putchr
	pop	d
	mov	a,d
	sta	sawcr
	jmp	chrloop

ineof:
	lda	conv
	ora	a
	jnz	done0	; Unix file, set byte count instead...
ineof0:
	mvi	a,EOF
	call	putchr
	; fill buffer and force flush...
	lda	outcnt
	ora	a	; zero means next putchr will flush...
	jnz	ineof0
done0:
	lda	outcnt
	mov	c,a
	mvi	a,BUFLEN
	sub	c
	sta	bytcnt	; 0..128
	call	outflush	; flushes full 128 byte record
done:
	; close all and rename tmpfile...
	call	closeall
	lda	conv
	ora	a
	jz	iscpm
	lda	bytcnt
	sta	tmpfile+32
	lxi	h,tmpfile+6
	mov	a,m
	ori	80h
	mov	m,a
	lxi	d,tmpfile
	mvi	c,SETATR
	call	BDOS	; trim file back to exact byte count
	; check error? aborting doesn't help
iscpm:
	lxi	d,outfile
	mvi	c,DELETE
	call	BDOS
	; check error? do anything different?
	lxi	h,outfile
	lxi	d,tmpfile+16
	lxi	b,16
	ldir
	lxi	d,tmpfile
	mvi	c,RENAME
	call	BDOS
	cpi	0ffh
	jz	renerr
	ret

getchr:
	lda	incnt
	ora	a
	cz	infill
	lda	incnt
	dcr	a
	sta	incnt
	lhld	inptr
	mov	a,m
	inx	h
	shld	inptr
	ret

putchr:
	push	psw
	lda	outcnt
	ora	a
	cz	outflush
	lda	outcnt
	dcr	a
	sta	outcnt
	pop	psw
	lhld	outptr
	mov	m,a
	inx	h
	shld	outptr
	ret

outflush:
	lxi	d,outbuf
	mvi	c,SETDMA
	call	BDOS
	lxi	d,tmpfile
	mvi	c,WRITE
	call	BDOS
	ora	a
	jnz	outerr
outinit:
	lxi	h,outbuf
	shld	outptr
	mvi	a,BUFLEN
	sta	outcnt
	ret

infill:
	lxi	d,inbuf
	mvi	c,SETDMA
	call	BDOS
	lxi	d,infile
	mvi	c,READ
	call	BDOS
	ora	a
	jz	inok
	cpi	1
	jnz	inerr
	mvi	a,EOF	; should never happen for text files, but handle anyway
	sta	inbuf
inok:
	lxi	h,inbuf
	shld	inptr
	mvi	a,BUFLEN
	sta	incnt
	ret

closeall:
	lxi	d,tmpfile
	mvi	c,CLOSE
	call	BDOS
	lxi	d,infile
	mvi	c,CLOSE
	call	BDOS
	ret

parerr:
	lxi	d,perrm
	mvi	c,PRINT
	call	BDOS
	lxi	d,CMDLINE
	ldax	d
	inx	d
	mov	l,a
	mvi	h,0
	dad	d
	mvi	m,'$'
	mvi	c,PRINT
	call	BDOS
help:
	lxi	d,usage
	mvi	c,PRINT
	call	BDOS
	jmp	WBOOT

mkerr:	; infile open, partial cleanup
	lxi	d,merrm
	jmp	abort

inerr:	; both files open
	lxi	d,ierrm
	jmp	abort

outerr:	; both files open
	lxi	d,oerrm
abort:
	push	d
	call	closeall
	lxi	d,tmpfile
	mvi	c,DELETE
	call	BDOS
	pop	d
	jmp	errmsg

renerr:	; files are all closed, no cleanup
	lxi	d,rerrm
	jmp	errmsg

inofile:	; files not open yet, no cleanup
	lxi	d,nerrm
errmsg:
	push	d
	lda	flcnt
	ora	a
	jz	nocrlf
	mvi	e,CR
	mvi	c,CONOUT
	call	BDOS
	mvi	e,LF
	mvi	c,CONOUT
	call	BDOS
nocrlf:
	pop	d
	mvi	c,PRINT
	call	BDOS
	jmp	WBOOT

; Check for '?' (ambiguous file name) in FCB HL
; Return CY set if unambiguous
chkafn:
	mvi	b,13
qchk:
	mov	a,m
	cpi	'?'
	rz
	inx	h
	dcr	b
	jnz	qchk
	stc
	ret


perrm:	db	'Invalid: $'
ierrm:	db	'Error reading input$'
oerrm:	db	'Error writing output$'
nerrm:	db	'No file found for input$'
merrm:	db	'Error creating temp$'
rerrm:	db	'Error renaming temp$'
usage:	db	CR,LF,'Usage: TR A:{outfile}=B:infile[U|C]$'
cpying:	db	'Copying -$'
fprefx:	db	CR,LF,'    $'

outcnt:	db	0
outptr:	dw	0
incnt:	db	0
inptr:	dw	0

stack	equ	$+64

outbuf	equ	stack
inbuf	equ	outbuf+BUFLEN
flist	equ	inbuf+BUFLEN

	end
