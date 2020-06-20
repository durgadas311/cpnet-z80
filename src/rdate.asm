; Get time/date from a remote server and display it.
;
	maclib z80

BDOS	equ	0005h
CMDLN	equ	0080h

; BDOS functions
CONOUT	equ	2
PRINT	equ	9
GETVER	equ	12

; CP/NET NDOS functions
NSEND	equ	66
NRECV	equ	67

	org	0100h
	jmp	start

vers:	dw	0

gettime: db	0, 0, 2, 105, 0, 0
gottime: db	1, 2, 0, 105, 0, 0, 0, 0, 0, 0 ; template of what is received

; assume < 100
decout:
	mvi	b,'0'
decot0:
	sui	10
	jc	decot1
	inr	b
	jmp	decot0
decot1:
	adi	10
	adi	'0'
	push	psw
	mov	a,b
	call	prout
	pop	psw
	jmp	prout

; Keeps number in HL - caller must preserve/init
; Returns CY for invalid
hexnum:
	sui	'0'
	rc
	cpi	9+1
	jnc	hexnm1
hexnm2:
	dad	h
	dad	h
	dad	h
	dad	h
	ora	l
	mov	l,a
	ret
hexnm1:
	sui	'A'-'9'
	rc
	cpi	5+1
	cmc
	rc
	adi	10
	jmp	hexnm2

hexout:
	push	psw
	rrc
	rrc
	rrc
	rrc
	call	hexdig
	pop	psw
hexdig:
	call	tohex
prout:
	mov	e,a
	mvi	c,CONOUT
	jmp	BDOS

tohex:
	ani	0fh
	adi	90h
	daa
	aci	40h
	daa
	ret

wdays:	db	'Sun$Mon$Tue$Wed$Thu$Fri$Sat$'

; HL = CP/M Date-time field, w/o seconds
; Print date and time to console.
prdate:
	mov	e,m
	inx	h
	mov	d,m
	inx	h
	push	h
	push	d
	xchg
	call	weekdy
	add	a
	add	a	; *4
	mov	c,a
	mvi	b,0
	lxi	h,wdays
	dad	b
	xchg
	call	xitmsg
	mvi	a,' '
	call	prout
	pop	d
; compute year
	mvi	c,78	; base year, epoch, binary
	mvi	b,078h	; year, BCD
	; special-case date=0...
	mov	a,e
	ora	d
	jnz	prdat0
	inx	d
prdat0:
	lxi	h,365
	mov	a,c
	ani	03h	; Not strictly true, but works until year 2100...
	jnz	prdat1
	inx	h
prdat1:	push	h
	ora	a
	dsbc	d
	pop	h
	jnc	prdat2	; done computing year...
	xchg
	ora	a
	dsbc	d
	xchg
	inr	c
	mov	a,b
	adi	1
	daa
	mov	b,a
	jmp	prdat0
prdat2:	; DE = days within year 'C'
	push	b	; save (2-digit) year, B = BCD, C = binary (until 2155)
	lxi	h,month0+24
	mov	a,c
	ani	03h
	jnz	prdat3
	lxi	h,month1+24
prdat3:	; compute month, DE = days in year,HL = mon-yr-days table adj for leap
	mvi	b,12
prdat4:
	dcx	h
	dcx	h
	dcr	b
	jm	prdat5	; should never happen...
	push	h
	push	d
	mov	a,m
	inx	h
	mov	h,m
	mov	l,a
		; DE = days in year, HL = ytd[month]
	ora	a
	dsbc	d
	mov	a,l	; potential remainder (neg)
	pop	d
	pop	h
	jnc	prdat4
prdat5:	; B = month, 0-11; A = -dom
	neg
	push	psw
	inr	b
	mov	a,b
	call	decout
	mvi	e,'/'
	mvi	c,CONOUT
	call	BDOS
	pop	psw
	call	decout
	mvi	e,'/'
	mvi	c,CONOUT
	call	BDOS
	pop	b
	mov	a,b	; already BCD
	call	hexout
	mvi	e,' '
	mvi	c,CONOUT
	call	BDOS
	pop	h	; -> BCD hours
	mov	a,m
	inx	h
	push	h
	call	hexout
	mvi	e,':'
	mvi	c,CONOUT
	call	BDOS
	pop	h	; -> BCD minutes
	mov	a,m
	inx	h
	push	h
	call	hexout
	mvi	e,':'
	mvi	c,CONOUT
	call	BDOS
	pop	h	; -> BCD seconds
	mov	a,m
	jmp	hexout

;		J   F   M   A   M   J   J   A   S   O   N   D
month0:	dw	 0, 31, 59, 90,120,151,181,212,243,273,304,334
month1:	dw	 0, 31, 60, 91,121,152,182,213,244,274,305,335

start:
	mvi	c,GETVER
	call	BDOS
	shld	vers
	lxi	h,CMDLN
	mov	c,m
	inx	h
sid1:
	mov	a,m
	cpi	' '
	jnz	sid0
	inx	h
	dcr	c
	jnz	sid1
	jmp	start1 ; no params, use defaults

sid0:	; scan hex number as server ID
	xchg
	lxi	h,0
sid2:
	ldax	d
	inx	d
	call	hexnum
	jc	sid3
	dcr	c
	jnz	sid2
sid3:
	mov	a,l
	sta	gettime+1

start1:
	lhld	vers
	mvi	a,2	; bit for CP/Net
	ana	h
	jz	error2

	lxi	d,gettime
	mvi	c,NSEND
	call	BDOS
	cpi	0ffh	; NDOS does not handle send errors well...
	jz	error	; not sure if this works...
	lxi	d,gottime
	mvi	c,NRECV
	call	BDOS
	cpi	0ffh	; NDOS does not handle recv errors well...
	jz	error	; not sure if this works...
	; do a little more checking...
	lda	gottime+4	; SIZ
	cpi	4	; should be 5 bytes in length...
	jnz	error
	jmp	shwtime

shwtime:
	lxi	d,done
	mvi	c,PRINT
	call	BDOS
	lxi	h,gottime+5
	call	prdate
	ret

; From DATE.PLM: week$day = (word$value + base$day - 1) mod 7;
;                base$day  lit '0',
weekdy:	dcx	h	; 1/1/78 is "0" (Sun), -1 for offset
	lxi	d,7000
	ora	a
wd0:	dsbc	d
	jrnc	wd0
	dad	d
	lxi	d,700
	ora	a
wd1:	dsbc	d
	jrnc	wd1
	dad	d
	lxi	d,70
	ora	a
wd2:	dsbc	d
	jrnc	wd2
	dad	d
	lxi	d,7
	ora	a
wd3:	dsbc	d
	jrnc	wd3
	dad	d
	mov	a,l
	ret

error:
	lxi	d,errmsg
	jmp	xitmsg

error2:
	lxi	d,errcpn
;	jmp	xitmsg

xitmsg:
	mvi	c,PRINT
	call	BDOS
	ret

done:	db	'Remote Time is: $'
errmsg: db	7,'Error retrieving network time.$'
errcpn: db	7,'This program requires CP/NET.$'

; Must be linked with an SNIOS, at least SNIOS000

	end
