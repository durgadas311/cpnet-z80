; SNIOS I/O module for Z180 ASCI1 on MinZ-U

	maclib	z180
	maclib	config

	public	sendby,check,recvby,recvbt

	cseg

check:	; validate existence of port, also initialize
	mvi	a,0ffh	; high = inactive (off) during init
	out0	a,trdr
	mvi	a,10h
	out0	a,cntr	; shift out new /RTS value
	mvi	a,00010100b	; disable Rx/Tx for init
	out0	a,ctla
	mvi	a,00000100b	; need CTS1E=1...
	out0	a,stat
	lda	004fh	; CPU speed stored here
	cpi	36
	jrz	ck2
	; 33.333MHz, 115200 baud TCR to ~115400 baud
	mvi	a,00000000b+asc$ps+asc$dr
	out0	a,ctlb
	mvi	a,00000000b+asc$brg
	out0	a,asxt
if astc
	lxi	h,astc
	out0	l,astcl
	out0	h,astch
endif
	jr	ck3
ck2:	; 36.864MHz uses "standard" dividers to 230800 baud
	mvi	a,00000000b+fst$brg
	out0	a,asxt
	mvi	a,00000000b+fst$ps+fst$dr+fst$ss
	out0	a,ctlb
ck3:
	mvi	a,01101100b	; enable Rx/Tx, CKA1D off, EFR
	out0	a,ctla
	; ASCI1 on MinZ uses CSIO for RTS...
	xra	a	; low = active (on)
	out0	a,trdr
	mvi	a,10h
	out0	a,cntr	; shift out new /RTS value
if 1	; why is delay needed?
	lxi	b,0100h
ck0:	dcx	b
	mov	a,b
	ora	c
	jrnz	ck0
endif
	xra	a
	ret

sendby:	push	psw
conot1:
	in0	a,ctlb
	ani	00100000b	; /CTS
	jrnz	conot1
	in0	a,stat
	ani	00000010b	; TDRE
	jrz	conot1
	pop	psw
	out0	a,tdr
	ret

; For CP/NET, wait long timeout for first char
; Return: CY=timeout else A=char
; At 115200, one char is 1600 cycles...
recvbt:
	push	d
	push	b
	mvi	d,20	; 20x = 3.1 seconds (5.6 seconds)
rcvb0:	; loop = 156mS
	lxi	b,0	; 65536* = 2883584 = 5177344
rcvb1:				; 0-wait    3-wait
	in0	a,stat		; 12        21?
	ani	10000000b	;  6        12
	jrnz	rcvb2		;  6n       12n
	dcx	b		;  4        7
	mov	a,b		;  4        7
	ora	c		;  4        7
	jrnz	rcvb1		;  8t = 44  14t = 80
	dcr	d
	jrnz	rcvb0
	pop	b
	pop	d
	stc
	ret
rcvb2:	in0	a,rdr	; CY=0 from ANI
	pop	b
	pop	d
	ret

; For CP/NET, wait short timeout for next char
recvby:
	push	d
	push	b
	mvi	d,2	; 2x = 312mS for next char
	jr	rcvb0
