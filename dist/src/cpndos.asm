; NDOS for CP/NOS, may be ROM-able

	extrn	bdosds,nios
	public	ndosrl,ndos

reboot	equ	0000h
cdisk	equ	0004h
bdosa	equ	0005h
defdma	equ	0080h

cr	equ	13
lf	equ	10

printf	equ	9
versnf	equ	12
openf	equ	15
closef	equ	16
readf	equ	20
setdmaf	equ	26
userf	equ	32
freedrf	equ	39

	cseg

	dseg
ndosrl:	db	0,0,0,0,0,0	; serial number
ndosa:	ds	3
	ds	3

	cseg
ndos:	jmp	ndose
	jmp	coldst

	dseg
lstdrt:	ds	1
ctlpf:	ds	1
rdcbff:	ds	1

	cseg
	db	'COPR. ''80-''82 DRI'
sernum:	db	0,0,0,0,0,0

nderrm:	db	cr,lf,'NDOS Err $'
nderr2:	db	', Func $'

	dseg
contad:	dw	0
bdose:	dw	0
version: dw	0
cursid:	db	0
	dw	0

; CP/NET message buffer
msgtop:	ds	1
msgid:	ds	1
	ds	1
msgfun:	ds	1
msgsiz:	ds	1
msgdat:	ds	256

	dw	0c7c7h,0c7c7h,0c7c7h,0c7c7h,0c7c7h,0c7c7h,0c7c7h,0c7c7h
	dw	0c7c7h,0c7c7h,0c7c7h,0c7c7h,0c7c7h,0c7c7h,0c7c7h,0c7c7h
	dw	0c7c7h,0c7c7h,0c7c7h,0c7c7h,0c7c7h,0c7c7h,0c7c7h,0c7c7h
	dw	0c7c7h,0c7c7h,0c7c7h,0c7c7h,0c7c7h,0c7c7h
stack:

ustack:	dw	0
funcod:	db	0
paramt:	dw	0
retcod:	db	0
mcrpnt:	dw	0
lstunt:	db	0
opnunl:	ds	1
fntmpf:	ds	1
orgbio:	ds	2
; data to be initialized
; all these values are overwritten on coldstart
idata1:
curdsk:	db	01h
dmaadd:	dw	defdma
curusr:	db	0

tlbios:	dw	0
	dw	nwboot
	dw	nconst
	dw	nconin
	dw	nconot
	dw	nlist
	dw	0,0,0,0,0,0,0,0,0
	dw	nlstst
	dw	0

ccpfcb:	db	1,'CCP  ',' '+80h,'  SPR',0
	ds	23

hexmsg:	ds	2
	db	'$'
bdermd:	db	0

	cseg
; initialization template for data
tdata1:
	db	01h
	dw	defdma
	db	0,0,0
	dw	nwboot
	dw	nconst
	dw	nconin
	dw	nconot
	dw	nlist
	db	0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
	dw	nlstst
	dw	0
	db	1,'CCP  ',' '+80h,'  SPR',0
	ds	23
	db	0,0,'$',0
d1len	equ	$-tdata1

coldst:	lxi	h,bdosds
	mvi	c,61
colds4:	mvi	m,0
	inx	h
	dcr	c
	jnz	colds4
	lxi	h,tdata1
	lxi	d,idata1
	mvi	c,d1len
colds5:	mov	a,m
	stax	d
	inx	h
	inx	d
	dcr	c
	jnz	colds5
	call	nios+0	; NTWKIN
	ora	a
	jnz	coldse
	mvi	c,17
	lhld	reboot+1
	shld	orgbio
	dcx	h
	lxi	d,tlbios
colds1:	push	b
	ldax	d
	mov	c,a
	inx	d
	ldax	d
	mov	b,a
	inx	d
	ora	c
	jz	colds2
	mov	a,m
	dcx	d
	stax	d
	dcx	h
	mov	a,m
	dcx	d
	stax	d
	inx	d
	inx	d
	mov	m,c
	inx	h
	mov	m,b
colds2:	inx	h
	inx	h
	inx	h
	pop	b
	dcr	c
	jnz	colds1
	call	nios+6	; CNFTBL
	inx	h
	shld	contad
	lhld	bdosa+1
	shld	bdose
	lxi	h,msgdat
	shld	mcrpnt
	xra	a
	sta	lstdrt
	sta	ctlpf
	sta	rdcbff
	lxi	h,ndosrl
	lxi	d,sernum
	mvi	b,6
colds3:	ldax	d
	mov	m,a
	inx	h
	inx	d
	dcr	b
	jnz	colds3
	mvi	m,0c3h
	lxi	d,ndos
	inx	h
	mov	m,e
	inx	h
	mov	m,d
	mvi	c,versnf
	call	bdosa
	shld	version
	jmp	nwboot

coldse:	mvi	c,printf
	lxi	d,inerms
	call	bdosa
	jmp	reboot

inerms:	db	'Init Err$'

ndose:	lxi	h,0
	mov	a,c
	cpi	100
	jc	ndose1
	sui	50
ndose1:	cpi	72
	jc	ndose7
	dcx	h
	mov	a,h
	ret
ndose7:	dad	sp
	shld	ustack
	lxi	sp,stack
	lxi	h,nerror
	push	h
	mov	c,a
	cpi	10
	mvi	a,0
	jnz	ndose2
	inr	a
ndose2:	sta	rdcbff
	xchg
	shld	paramt
	mov	a,c
	sta	funcod
	sta	msgfun
	lxi	h,msgsiz
	mvi	m,0
	inx	h
	shld	mcrpnt
	xra	a
	mov	b,a
	mov	d,a
	lxi	h,funtb1
	dad	b
	mov	e,m
	sub	e
	jz	tbdosp
	dcr	a
	jnz	ndose4
	dcr	a
	mov	h,a
	mov	l,a
	ret
ndose4:	lxi	h,ndendr
	xthl
	lxi	h,funtb2
	dad	d
	push	h
ndose5:	pop	b
	ldax	b
	mov	d,a
	ani	7fh
	mov	e,a
	mov	a,d
	mvi	d,0
	lxi	h,funtb3
	dad	d
	mov	e,m
	inx	h
	mov	d,m
	inx	b
	ral
	jc	ndose6
	push	b
	lxi	h,ndose5
	push	h
ndose6:	xchg
	pchl

funtb3:
	dw	nwboot	; 00h
	dw	sndhdr	; 02h
	dw	rcvpar	; 04h
	dw	sndfcb	; 06h
	dw	cksfcb	; 08h
	dw	rentmp	; 0ah
	dw	stfid	; 0ch
	dw	wtdtc8	; 0eh
	dw	wtdtcp	; 10h
	dw	ckstdk	; 12h
	dw	bcstfn	; 14h
	dw	bcstvc	; 16h
	dw	rcvec	; 18h
	dw	gtfcb	; 1ah
	dw	gtfccr	; 1ch
	dw	ctfcrr	; 1eh
	dw	gtdire	; 20h
	dw	gtosct	; 22h
	dw	gtmisc	; 24h
	dw	gtlogv	; 26h
	dw	setdma	; 28h
	dw	seldsk	; 2ah
	dw	sguser	; 2ch
	dw	getver	; 2eh
	dw	getdsk	; 30h
	dw	reset	; 32h
	dw	nwstat	; 34h
	dw	nwcftb	; 36h
	dw	sdmsgu	; 38h
	dw	rvmsgu	; 3ah
	dw	login	; 3ch
	dw	logoff	; 3eh
	dw	stsf	; 40h
	dw	stsn	; 42h
	dw	stbder	; 44h

funtb2:	; opcodes for funtb3, 80h+ terminates
	db	80h+0			; 00h
	db	80h+2eh			; 01h
	db	80h+32h			; 02h
	db	80h+16h			; 03h
	db	80h+2ah			; 04h
	db	8,14,18h,80h+1ah	; 05h
	db	6,80h+18h		; 09h
	db	40h,18h,80h+20h		; 0bh
	db	42h,18h,80h+20h		; 0eh
	db	6,18h,1ch,80h+22h	; 11h
	db	8,10h,18h,80h+1ch	; 15h
	db	8,10,2,80h+18h		; 19h
	db	80h+26h			; 1dh
	db	80h+30h			; 1eh
	db	80h+28h			; 1fh
	db	12h,2,18h,80h+24h	; 20h
	db	12h,2,80h+18h		; 24h
	db	6,18h,80h+1ch		; 27h
	db	80h+2ch			; 2ah
	db	6,18h,1eh,80h+22h	; 2bh
	db	8,10h,18h,80h+1eh	; 2fh
	db	6,18h,80h+1eh		; 33h
	db	8,12,18h,80h+1eh	; 36h
	db	80h+44h			; 3ah
	db	80h+14h			; 3bh
	db	3ch,80h+18h		; 3ch
	db	3eh,80h+18h		; 3eh
	db	80h+38h			; 40h
	db	80h+3ah			; 41h
	db	80h+34h			; 42h
	db	80h+36h			; 43h
	db	80h+14h			; 44h
	db	3eh,18h,80h+24h		; 45h


; first level table, function to opcode-string map
funtb1:	db	0,0,0,0,0,0
	db	0,0,0,0,0,0
	db	1,2,4,5,5,11,14,9,11h,15h,5,19h,1dh,1eh,1fh,20h,24h,1dh,27h,20h
	db	2ah,2bh,2fh,33h,33h,3,3,3,2fh,0ffh,36h,36h,0ffh,3ah
	db	0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh
	db	3bh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,3ch,3eh,40h,41h,42h,43h,44h,45h

sndhdr:	lhld	contad
	xchg
	lxi	h,msgtop
	mvi	m,0
	ldax	d
	inx	h
	inx	h
	mov	m,a
	inx	h
	inx	h
	inx	h
	xchg
	lhld	mcrpnt
	xra	a
	sub	e
	mov	c,a
	mvi	a,0
	sbb	d
	mov	b,a
	dad	b
	mov	a,l
	ora	h
	jz	sndhd1
	dcx	h
	xchg
	dcx	h
	mov	m,e
sndhd1:	lxi	b,msgtop
sdmsge:	call	nios+9	; SNDMSG
	inr	a
	rnz
	jmp	ndend

rvmsge:
	call	nios+12	; RCVMSG
	inr	a
	rnz
ndend:	lxi	h,-1
	mov	a,h
	jmp	nerror

ndendr:	lda	retcod
nerror:
	xchg
	lhld	ustack
	sphl
	xchg
	mov	l,a
	mov	b,h
	ret

rcvpar:	lxi	b,msgtop
	call	rvmsge
	lxi	h,msgdat
	shld	mcrpnt
	ret

tbdosp:	lhld	paramt
	xchg
	lda	funcod
	mov	c,a
tobdos:	lhld	bdose
	pchl

ckfcbd:	lhld	paramt
	mov	a,m
	dcr	a
	jp	ckfcb1
	lda	curdsk
ckfcb1:	mov	e,a
	mvi	d,0
	call	chkdsk
	cpi	0ffh
	rnz
	call	tbdosp
	jmp	nerror

chkdsk:	lhld	contad
	dad	d
	dad	d
	inx	h
	mov	a,m
	ral
	jc	chkds1
	mvi	a,0ffh
	ret
chkds1:	rar
	ani	0fh
	inr	a
	mov	c,a
	inx	h
	mov	a,m
	sta	msgid
	ret

nwboot:	lxi	sp,0100h
	lxi	h,ndosa
	shld	bdosa+1
	lhld	orgbio
	shld	reboot+1
	xra	a
	sta	paramt
	call	sguser
	call	reset
	mvi	a,freedrf
	sta	funcod
	sta	msgfun
	lxi	h,-1
	shld	paramt
	call	bcstvc
	xra	a
	sta	ccpfcb+32
	lxi	d,ccpfcb
	lxi	h,ndosrl
	call	load
	ora	a
	jz	goccp
	mvi	c,printf
	lxi	d,clderr
	call	tobdos
	jmp	$

clderr:	db	'CCP.SPR ?$'

goccp:	lda	cdisk
	mov	c,a
	sphl
	push	h
	push	b
	lda	curusr
	mov	e,a
	mvi	c,userf
	call	tobdos
	call	nios+18	; NTWKBT
	pop	b
	ret

sndfcb:	call	cksfcb
	jmp	sndhdr

cksfcb:	call	ckfcbd
stfcb:	lhld	mcrpnt
	lda	curusr
	mov	m,a
	inx	h
	mov	m,c
	inx	h
	xchg
	lhld	paramt
	inx	h
	xchg
	mvi	b,35
	call	mcpyts
	xra	a
	sta	fntmpf
	sta	opnunl
	lhld	mcrpnt
	lxi	d,-35
	dad	d
subtmp:	call	ckdol
	mvi	b,0
	dad	b
	inx	h
	mov	a,m
	ani	80h
	inx	h
	jz	subtm1
	mov	a,m
	ani	80h
	jnz	subtm1
	dcr	a
	sta	opnunl
subtm1:	lda	fntmpf
	add	a
	sta	fntmpf
	inx	h
	inx	h
	inx	h
ckdol:	mvi	c,3
	mvi	a,36
ckdol1:	cmp	m
	rnz
	inx	h
	dcr	c
	jnz	ckdol1
	xchg
	lxi	h,fntmpf
	inr	m
	dcx	d
	lhld	contad
	mov	a,m
	mov	b,a
	call	hexdig
	dcx	d
	mov	a,b
	rar
	rar
	rar
	rar
	call	hexdig
	inx	d
	inx	d
	xchg
	ret

hexdig:	ani	0fh
	cpi	10
	jnc	hexdg1
	adi	'0'
	stax	d
	ret

hexdg1:	adi	'A'-10
	stax	d
	ret

rentmp:	lhld	mcrpnt
	lxi	d,-19
	dad	d
	jmp	subtmp

mcpyts:	ldax	d
	mov	m,a
	inx	h
	inx	d
	dcr	b
	jnz	mcpyts
	shld	mcrpnt
	ret

stfid:	mvi	b,2
	jmp	wtdtcs

wtdtc8:	mvi	b,8
	jmp	wtdtcs

wtdtcp:	mvi	b,defdma
wtdtcs:	lhld	dmaadd
	xchg
	lhld	mcrpnt
	call	mcpyts
	jmp	sndhdr

ckstdk:	lda	curdsk
	mov	e,a
	mvi	d,0
	call	chkdsk
	cpi	0ffh
	jnz	stdsk1
	call	tbdosp
	jmp	nerror

stdsk1:	sta	msgid
	lhld	mcrpnt
	dcr	c
	mov	m,c
	inx	h
	shld	mcrpnt
	ret

bcstfn:	lxi	d,0
	call	forall
	mov	a,c
	inr	c
	jz	rstall
	sta	msgid
	lhld	paramt
	xchg
	lhld	mcrpnt
	lda	funcod
	cpi	56
	jz	bcst1
	mov	m,e
	jmp	bcst2

bcst1:	mvi	b,8
	call	mcpyts
bcst2:	call	sndhdr
	call	rcvpar
	jmp	bcstfn

bcstvc:	lhld	paramt
	xchg
bcstv1:	call	forall
	push	h
	mov	a,c
	inr	c
	jnz	bcstv2
	pop	d
	jmp	rstall
bcstv2:	sta	msgid
	lxi	h,msgdat
	mov	m,e
	inx	h
	mov	m,d
	inx	h
	shld	mcrpnt
	call	sndhdr
	lda	funcod
	sui	38
	jz	bcstv3
	push	psw
	call	rcvpar
	pop	psw
	pop	d
	dcr	a
	jz	bcstv1
	lda	msgdat
	sta	retcod
	inr	a
	jz	rstall
	jmp	bcstv1

bcstv3:	call	rcvec
	pop	d
	jmp	bcstv1

forall:	lhld	contad
	inx	h
	push	d
	lxi	d,0
	lxi	b,16ffh
foral1:	mov	a,m
	ral
	jnc	foral6
	ral
	jc	foral6
	inx	h
	mov	a,c
	cpi	0ffh
	jz	foral2
	cmp	m
	jz	foral3
	dcx	h
	jmp	foral6
foral2:	mov	c,m
foral3:	dcx	h
	mov	a,m
	ori	40h
	mov	m,a
	xthl
	call	rhlr0
	jnc	foral7
	xthl
	mov	a,m
	ani	0fh
	inr	a
	push	h
	lxi	h,1
foral4:	dcr	a
	jz	foral5
	dad	h
	jmp	foral4
foral5:	mov	a,e
	ora	l
	mov	e,a
	mov	a,d
	ora	h
	mov	d,a
	pop	h
	jmp	foral8
foral6:	xthl
	call	rhlr0
	jnc	foral7
	mov	a,h
	ori	80h
	mov	h,a
foral7:	xthl
foral8:	inx	h
	inx	h
	dcr	b
	jnz	foral1
	pop	h
	ret

rhlr0:	ora	a
	mov	a,h
	rar
	mov	h,a
	mov	a,l
	rar
	mov	l,a
	ret

rstall:	lhld	contad
	inx	h
	mvi	b,16
rstal1:	mov	a,m
	ani	8fh
	mov	m,a
	inx	h
	inx	h
	dcr	b
	jnz	rstal1
	ret

stsf:	mvi	a,0ffh
	sta	cursid
	lhld	paramt
	mov	a,m
	cpi	'?'
	jnz	stsf1
	call	ckstdk
	mvi	c,'?'
	call	stfcb
	jmp	stsf2

stsf1:	lhld	mcrpnt
	inx	h
	shld	mcrpnt
	call	cksfcb
stsf2:	lda	msgid
	sta	cursid
	jmp	sndhdr

stsn:	lda	cursid
	cpi	0ffh
	jnz	stsn1
	call	tbdosp
	jmp	nerror

stsn1:	sta	msgid
	lda	curusr
	lhld	mcrpnt
	inx	h
	mov	m,a
	inx	h
	shld	mcrpnt
	jmp	sndhdr

rcvec:	call	rcvpar
	lxi	h,msgdat+1
	shld	mcrpnt
	mov	d,m
	dcx	h
	mov	a,m
	sta	retcod
	dcx	h
	mov	a,m
	dcr	a
	rnz
	lda	bdermd
	inr	a
	jnz	nderr
	xchg
	jmp	ndendr

nderr:	push	d
	lxi	d,nderrm
	call	prmsg
	pop	psw
	call	hexout
	lxi	d,nderr2
	call	prmsg
	lda	funcod
	call	hexout
	pop	psw
	mov	h,a
	lda	bdermd
	cpi	0feh
	jz	ndendr
	jmp	nwboot

hexout:	lxi	d,hexmsg+1
	push	psw
	call	hexdig
	pop	psw
	rar
	rar
	rar
	rar
	dcx	d
	call	hexdig
prmsg:	mvi	c,printf
	jmp	tobdos

gtfcb:	lda	opnunl
	inr	a
	jnz	gtfccr
ctfcrr:	mvi	b,35
	jmp	gtfc1
gtfccr:	mvi	b,32
gtfc1:	call	rstmp
	lhld	mcrpnt
	inx	h
	xchg
	lhld	paramt
	inx	h
	;jmp	mcpyfs

mcpyfs:	ldax	d
	mov	m,a
	inx	d
	inx	h
	dcr	b
	jnz	mcpyfs
	xchg
	shld	mcrpnt
	ret

rstmp:	lda	fntmpf
	rar
	rar
	jnc	rstmp1
	lhld	mcrpnt
	inx	h
	inx	h
	mvi	m,'$'
	inx	h
	mvi	m,'$'
rstmp1:	ral
	rnc
	lhld	mcrpnt
	lxi	d,10
	dad	d
	mvi	m,'$'
	inx	h
	mvi	m,'$'
	ret

gtdire:	lda	retcod
	inr	a
	rz
	lhld	mcrpnt
	xchg
	lhld	dmaadd
	lxi	b,32
gtdir1:	dcr	a
	jz	gtdir2
	dad	b
	jmp	gtdir1
gtdir2:	mov	b,c
	call	mcpyfs
	ret

gtosct:	lda	retcod
	ora	a
	rnz
	lxi	h,msgdat+37
	xchg
	lhld	dmaadd
	mvi	b,128
	jmp	mcpyfs

gtmisc:	lhld	mcrpnt
	dcx	h
	lda	funcod
	cpi	27
	jz	gtmsc3
	xchg
	cpi	31
	jnz	gtmsc1
	lxi	h,curdpb
	push	h
	mvi	b,16
	jmp	gtmsc2
gtmsc1:	lxi	h,curscf
	push	h
	mvi	b,23
gtmsc2:	call	mcpyfs
	pop	h
gtmsc3:	mov	a,l
	sta	retcod
	ret

gtlogv:	lhld	contad
	lxi	d,32
	dad	d
	xchg
	lxi	h,0
	mvi	b,16
gtlgv1:	ldax	d
	dcx	d
	mov	c,a
	ldax	d
	dcx	d
	dad	h
	call	drvsts
	dcr	b
	jnz	gtlgv1
	mov	a,l
	sta	retcod
	ret

drvsts:	push	d
	push	b
	push	h
	ral
	jc	drvst1
	push	b
	call	tbdosp
	pop	b
	dcr	b
	xchg
	jmp	drvst2

drvst1:	rar
	ani	0fh
	mov	b,a
	mov	a,c
	sta	msgid
	lxi	h,msgdat
	shld	mcrpnt
	push	b
	call	sndhdr
	call	rcvpar
	pop	b
	lhld	mcrpnt
	mov	e,m
	inx	h
	mov	d,m
drvst2:	mov	a,b
	ora	a
	jz	drvst4
drvst3:	mov	a,d
	rar
	mov	d,a
	mov	a,e
	rar
	mov	e,a
	dcr	b
	jnz	drvst3
drvst4:	mvi	d,0
	mov	a,e
	ani	1
	mov	e,a
	pop	h
	dad	d
	pop	b
	pop	d
	ret

setdma:	lhld	paramt
	shld	dmaadd
	jmp	tbdosp

seldsk:	lda	paramt
	sta	curdsk
	mvi	d,0
	mov	e,a
	call	chkdsk
	cpi	0ffh
	jz	tbdosp
	lhld	mcrpnt
	dcr	c
	mov	m,c
	inx	h
	shld	mcrpnt
	call	sndhdr
	jmp	rcvec

reset:	lxi	h,defdma
	shld	dmaadd
	xra	a
	sta	paramt
	mvi	a,14
	sta	funcod
	sta	msgfun
	lxi	h,msgdat
	shld	mcrpnt
	jmp	seldsk

sguser:	lda	paramt
	cpi	0ffh
	lxi	h,curusr
	mov	e,a
	mov	a,m
	sta	retcod
	rz
	mov	m,e
	ret

getver:	lhld	version
	mvi	a,2
	ora	h
	mov	h,a
	mov	a,l
	sta	retcod
	ret

getdsk:	lda	curdsk
	sta	retcod
	ret

nwstat:	call	nios+3	; NTWKST
	sta	retcod
	ret

nwcftb:	call	nios+6	; CNFTBL
	mov	a,l
	sta	retcod
	ret

login:	lhld	paramt
	mov	a,m
	sta	msgid
	inx	h
	xchg
	lhld	mcrpnt
	mvi	b,8
	call	mcpyts
	jmp	sndhdr

logoff:	lda	paramt
	sta	msgid
	jmp	sndhdr

sdmsgu:	lhld	paramt
	mov	b,h
	mov	c,l
	jmp	sdmsge

rvmsgu:	lhld	paramt
	mov	b,h
	mov	c,l
	jmp	rvmsge

stbder:	lda	paramt
	sta	bdermd
	ret

nconst:	lhld	tlbios+4
	lxi	d,11
	jmp	nconcm

nconin:	lxi	h,cpchk
	push	h
	lhld	tlbios+6
	lxi	d,3
	jmp	nconcm

cpchk:	push	psw
	cpi	10h	; Ctrl-P
	jnz	cpchk5
	lda	rdcbff
	ora	a
	jz	cpchk5
	lhld	contad
	dcx	h
	lda	ctlpf
	ora	a
	jz	cpchk2
	xra	a
	sta	ctlpf
	mov	a,m
	ani	0fbh
	mov	m,a
	lxi	d,36
	dad	d
	mov	a,m
	ral
	mvi	c,0ffh
	cc	nlist
	xra	a
	sta	lstdrt
	lxi	h,'FF'
	shld	ctpmsg+7
	jmp	cpchk3

ctpmsg:	db	'Ctl-P OFF',0

cpchk2:	mvi	a,0ffh
	sta	ctlpf
	mov	a,m
	ori	04h
	mov	m,a
	lxi	h,'N'
	shld	ctpmsg+7
cpchk3:	lxi	h,ctpmsg
cpchk4:	mov	a,m
	ora	a
	jz	cpchk5
	mov	c,a
	inx	h
	push	h
	call	nconot
	pop	h
	jmp	cpchk4
cpchk5:	pop	psw
	ret

nconot:	lhld	tlbios+8
	lxi	d,260	; count + func offset
nconcm:	push	h
	push	b
	lhld	contad
	lxi	b,33
	dad	b
	pop	b
	mov	a,m
	ral
	rnc
	mov	a,m
	ani	0fh
	mov	b,a
	inx	h
	mov	a,m
	lxi	h,msgtop
	mvi	m,0
	inx	h
	mov	m,a	
	xthl
	lhld	contad
	mov	a,m
	pop	h
	inx	h
	mov	m,a
	inx	h
	mov	m,e
	inx	h
	mov	m,d
	inx	h
	mov	m,b
	inx	h
	mov	m,c
	lxi	b,msgtop
	call	sdmsge
	lxi	b,msgtop
	call	rvmsge
	lda	msgdat
	ret

nlist:	mvi	a,0ffh
	sta	lstdrt
	lhld	contad
	lxi	d,35
	dad	d
	mov	a,m
	ral
	jc	nlist1
	lhld	tlbios+10
	pchl
nlist1:	mov	a,m
	ani	0fh
	sta	lstunt
	push	b
	mov	b,c
	inx	h
	inx	h
	mov	c,m
	inr	m
	mvi	a,80h
	cmp	m
	jz	nlist2
	mov	a,b
	cpi	0ffh
	jnz	nlist3
nlist2:	xra	a
	mov	m,a
	sta	lstdrt
nlist3:	lxi	d,7
	dad	d
	mvi	b,0
	dad	b
	pop	d
	mov	m,e
	rnz
	lhld	contad
	lxi	d,36
	dad	d
	mov	a,m
	inx	h
	inx	h
	mov	e,c
	mov	b,h
	mov	c,l
	inx	h
	mov	m,a
	inx	h
	inx	h
	inx	h
	inr	e
	mov	m,e
	inx	h
	lda	lstunt
	mov	m,a
	call	sdmsge
	lxi	b,msgtop
	jmp	rvmsge

nlstst:	lhld	contad
	lxi	d,35
	dad	d
	mov	a,m
	ral
	jc	nlsts1
	lhld	tlbios+30
	pchl

nlsts1:	ret

load:	shld	ldbotm
	xchg
	shld	ldfcb
	mvi	c,setdmaf
	lxi	h,-128
	dad	d
	shld	lddma
	xchg
	call	bdosa
	lhld	ldfcb
	xchg
	mvi	c,openf
	call	bdosa
	cpi	0ffh
	rz
	call	osread
	lhld	lddma
	inx	h
	mov	e,m
	inx	h
	mov	d,m
	inx	h
	inx	h
	mov	c,m
	inx	h
	mov	b,m
	xchg
	shld	ldlngt
	dad	b
	xchg
	lhld	ldbotm
	xchg
	xra	a
	sub	l
	mov	l,a
	mvi	a,0
	sbb	h
	mov	h,a
	dad	d
	mvi	l,0
	shld	ldtop
	xchg
	lxi	h,-128
	dad	d
	shld	lddma
	call	osread
	lhld	ldlngt
	lxi	d,127
	dad	d
	mov	a,l
	ral
	mov	a,h
	ral
	lhld	ldtop
load1:	sta	ldcnt
	shld	ldpnt
	xchg
	mvi	c,setdmaf
	call	bdosa
	call	osread
	lhld	ldpnt
	lxi	d,128
	dad	d
	lda	ldcnt
	dcr	a
	jnz	load1
	lhld	lddma
	xchg
	mvi	c,setdmaf
	call	bdosa
	lhld	ldlngt
	mov	b,h
	mov	c,l
	xchg
	lhld	ldtop
	xchg
	dad	d
	push	h
	mov	h,d
load2:	mov	a,b
	ora	c
	jnz	load3
	pop	h
	push	psw
	lhld	ldfcb
	xchg
	mvi	c,closef
	call	bdosa
	pop	psw
	lhld	ldtop
	ret

load3:	dcx	b
	mov	a,e
	ani	07h
	jnz	load5
	xthl
	mov	a,l
	ani	7fh
	jnz	load4
	push	b
	push	d
	push	h
	lhld	ldfcb
	xchg
	mvi	c,readf
	call	bdosa
	pop	h
	pop	d
	pop	b
	lhld	lddma
	ora	a
	jnz	lderr
load4:	mov	a,m
	inx	h
	xthl
	mov	l,a
load5:	mov	a,l
	ral
	mov	l,a
	jnc	load6
	ldax	d
	add	h
	stax	d
load6:	inx	d
	jmp	load2

osread:	lhld	ldfcb
	xchg
	mvi	c,readf
	call	bdosa
	ora	a
	rz
lderr:	mvi	a,0ffh
	pop	h
	ret

	dseg
	ds	2	; unused?
	ds	1	; unused?
lddma:	ds	2
ldlngt:	ds	2
ldfcb:	ds	2
ldbotm:	ds	2
ldtop:	ds	2
ldcnt:	ds	1
ldpnt:	ds	2
curdpb:	ds	15
curscf:	ds	23

	cseg
	end
