	title	'BIOS for CP/NOS 1.2'
;
;
;	Version 1.1 October, 1981
;	Version 1.2 Beta Test, 08-23-82
;
vers	equ	12	;version 1.2
;
;	Copyright (c) 1980, 1981, 1982
;	Digital Research
;	Box 579, Pacific Grove
;	California, 93950
;
;
true	equ	0ffffh	;value of "true"
false	equ	not true	;"false"
;
DSC2	equ	false
Altos	equ	true
;
;	perform following functions
;	boot	cold start
;	wboot	(not used under CP/NOS)
;	const	console status
;		reg-a = 00 if no character ready
;		reg-a = ff if character ready
;	conin	console character in (result in reg-a)
;	conout	console character out (char in reg-c)
;	list	list out (char in reg-c)
;

	extrn	NDOS	; Network Disk Operating System
	extrn	BDOS	; Basc Disk Operating System
	extrn	NDOSRL	; NDOS serial number, BIOS jump table
			;  is page aligned at 0300H offset
	CSEG
BIOS:
	public	BIOS
;	jump vector for indiviual routines
	jmp	boot
wboote:	jmp	error
	jmp	const
	jmp	conin
	jmp	conout
	jmp	list
	jmp	error
	jmp	error
	jmp	error
	jmp	error
	jmp	error
	jmp	error
	jmp	error
	jmp	error
	jmp	error
	jmp	listst	;list status
	jmp	error
BIOSlen	equ	$-BIOS
;
cr	equ	0dh	;carriage return
lf	equ	0ah	;line feed
;
buff	equ	0080h	;default buffer
;
signon:	;signon message: xxk cp/m vers y.y
	db	cr,lf,lf
	db	'64'	;memory size
	db	'k CP/NOS vers '
	db	vers/10+'0','.',vers mod 10+'0'
	db	cr,lf,0
;
boot:	;print signon message and go to ccp
;
;	device initialization  -  as required
;
	lxi	sp,buff+0080h
	lxi	h,signon
	call	prmsg	;print message
	mvi	a,jmp
	sta	0000h
	sta	0005h
	lxi	h,BDOS
	shld	0006h
	xra	a
	sta	0004h
	lxi	h,NDOSRL+0303h
	shld	0001h
	dcx	h
	dcx	h
	dcx	h
	lxi	d,BIOS
	mvi	c,BIOSlen
initloop:
	ldax	d
	mov	m,a
	inx	h
	inx	d
	dcr	c
	jnz	initloop
	jmp	NDOS+03h ;go to NDOS initialization
;
;	Device equate table
;
	if	DSC2
cstati	equ	41h
cmski	equ	02h
cdprti	equ	40h

cstato	equ	41h
cmsko	equ	01h
cdprto	equ	40h

lstato	equ	49h
lmsko	equ	01h
ldprto	equ	48h
	endif

	if	Altos
cstati	equ	1Dh
cmski	equ	01h
cdprti	equ	1Ch

cstato	equ	1Dh
cmsko	equ	04h
cdprto	equ	1Ch

lstato	equ	1Fh
lmsko	equ	0Ch
ldprto	equ	1Eh
	endif

;
;
const:	;console status to reg-a
	if	Altos
	mvi	a,0
	out	cstati
	endif
	in	cstati
	ani	cmski
	rz
	mvi	a,0ffh
	ret
;
conin:	;console character to reg-a
	call	const
	jz	conin
	in	cdprti
	ani	7fh	;remove parity bit
	ret
;
conout:	;console character from c to console out
	if	Altos
	mvi	a,10h
	out	cstato
	endif
	in	cstato
	ani	cmsko
	jz	conout
	mov	a,c
	out	cdprto
	ret
;
list:	;list device out
	if	Altos
	mvi	a,10h
	out	lstato
	endif
	in	lstato
	ani	lmsko
	cpi	lmsko
	jnz	list
	mov	a,c
	out	ldprto
	ret
;
listst:
	if	Altos
	mvi	a,10h
	out	lstato
	endif
	in	lstato
	ani	lmsko
	cpi	lmsko
	mvi	a,0
	rnz
	dcr	a
	ret
;
;	utility subroutines
error:
	lxi	h,0ffffh
	mov	a,h
	ret

prmsg:	;print message at h,l to 0
	mov	a,m
	ora	a	;zero?
	rz
;	more to print
	push	h
	mov	c,a
	call	conout
	pop	h
	inx	h
	jmp	prmsg
;

	end
