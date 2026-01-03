;	NETWORK DISK OPERATING SYSTEM FOR CP/NET on CP/M Plus v3
;
; 1982.12.31. exact date unknown
; 2016.05.20. adapted for RSX on CP/M Plus
;	Dropped support for remote console/list, due to BIOS intercept issues.
;	BIOS intercept is a problem because of the transient nature of RSXs.
;	Could add back support for "well-behaved" LIST OUTPUT users,
;	provided BIOS intercept is not required.
;
;TITLE	NETWORK DISK OPERATING SYSTEM FOR CP/NET SLAVE
	maclib	z80

	extrn	NTWKIN, NTWKST, CNFTBL, SNDMSG, RCVMSG, NTWKBT, NTWKDN, CFGTBL
;
;
;	EQUATIONS OF DATA
;
LF	EQU	0AH	;LINE FEED
CR	EQU	0DH	;CARRIAGE RETURN
EOF	EQU	1AH	;CTRL-Z IS END OF FILE
LEOF	EQU	0ffh	;-1 is logical end of file
;
TOP	equ	0000h
CDISK	equ	0004h
BDOS	equ	0005h
SYSDMA	equ	0080h
TPA	equ	0100h

SCTLNG	equ	128	;ONE SECTOR LENGTH
;
;	EQUATIONS OF DOS FUNCTION
;
CCNDIN	EQU	3	;CONSOLE INPUT WITH DEVICE CODE
CCNDOT	EQU	4	;CONSOLE OUTPUT WITH DEVICE CODE
CBUFPR	EQU	9	;BUFFER PRINT
CRDBUF	EQU	10	;READ BUFFER
CCONST	EQU	11	;GET CONSOLE STATUS
CGETVR	EQU	12	;GET VERSION NUMBER
CRSDSK	EQU	13	;RESET DISK
COPEN	EQU	15	;OPEN FILE
CCLOSE	EQU	16	;CLOSE FILE
CSRFST	EQU	17	;SEARCH FIRST
CSRNXT	EQU	18	;SEARCH NEXT DIRECTORY
CREAD	EQU	20	;READ SEQ
CWRITE	EQU	21	;WRITE SEQ
CSTDMA	EQU	26	;SET DMA ADDRESS
CGTALL	EQU	27	;get alloc vector addr
CGTDPB	EQU	31	;get DPB addr
CSTUSC	EQU	32	;SET USER CODE
CRREAD	EQU	33	;READ SEQ
CRWRIT	EQU	34	;WRITE SEQ
CRSDSN	EQU	37	;RESET DISK BY DISK VERCTOR
CFRSP	equ	46	; get disk free space
scbf	equ	49	; get/set SCB
CBIOS	equ	50	; direct BIOS call
COVLY	equ	59	; load overlay
CRSX	equ	60	; call RSX function
CDEFPW	EQU	106	;set default password
CLSBLK	equ	112	; List Block - does not fit in table...

CBMAX	EQU	50	;MAX OF BDOS FUNCTION - CXMIN.. collapsed here
CXMIN	EQU	98	;extended bdos functions base - collapse into CBMAX
;
CNMIN	EQU	64	;MIN OF NDOS FUNCTION
CLOGIN	EQU	64	;LOGIN
CLOGOF	EQU	65	;LOGOFF
CNMAX	EQU	72	;MAX OF NDOS FUNCTION

;
;	SLAVE CONFIGRATION TABLE
;
; -1	NETWORK STATUS
;	0	SLAVE PROCESSOR ID
;	1-32 A - P DISK DEVICE CODE
; 33-34 CONSOLE DEVICE
; 35-36 LIST DEVICE
; 37	LIST BUFFER COUNTER
; 38-42 MESSAGE HEADER FOR LIST OUT
; 43	LISTER DEVICE NUMBER
; 44-171 LIST OUT DATA BUFFER
;
;	EACH DEVICE DATA USED 2 BYTES
;	IN 1-36
;	1B:BIT 7 H ON NETWORK
;	BIT 6 H SET UP IN DISK
;	BIT 0-3 DEVICE NUMBER IN MASTER
;	2B:MASTER ID
;
;	BIAS TO DATA IN CONFIGRATION TABLE
;
BSRID	equ	1	;client ID
BSDSKS	equ	2	;first byte in disk table
BSDSKE	equ	33	;last byte in disk table
BSCONS	EQU	34	;BIAS TO CONSOLE DATA
BSLIST	EQU	36	;BIAS TO LISTER DATA

FCBRR0	equ	33	; offset of RR0 field in FCB (not FCB in MSG)

scbase	equ	09ch	; base address of SCB within page

	org	0

;	RSX Prefix
serial:	db	0,0,0,0,0,0
start:	jmp	COLDST
next:	jmp	0
prev:	dw	0
remove:	db	0	; 0ffh for remove
nonbank:
	db	0
rsxnam:	db	'NDOS3   '
loader:	db	0,0,0

	db	'COPYRIGHT (C) 1980-82, DIGITAL RESEARCH '
	db	0,0,0,0,0,0

NDERRM:	db	CR,LF,'NDOS Err $'
NDERR2:	db	', Func $'

BDOSE:	dw	0
CURSID: db	0
scbadr:	dw	0

MSGTOP:	db	0
MSGID:	db	0
	db	0	; We assume network hw/sw sets this.
MSGFUN:	db	0
MSGSIZ:	db	0
MSGDAT:	ds	256

	db	0c7h,0c7h,0c7h,0c7h,0c7h,0c7h
	db	0c7h,0c7h,0c7h,0c7h,0c7h,0c7h
	db	0c7h,0c7h,0c7h,0c7h,0c7h,0c7h
	db	0c7h,0c7h,0c7h,0c7h,0c7h,0c7h
	db	0c7h,0c7h,0c7h,0c7h,0c7h,0c7h
	db	0c7h,0c7h,0c7h,0c7h,0c7h,0c7h
	db	0c7h,0c7h,0c7h,0c7h,0c7h,0c7h
	db	0c7h,0c7h,0c7h,0c7h,0c7h,0c7h
	db	0c7h,0c7h,0c7h,0c7h,0c7h,0c7h
	db	0c7h,0c7h,0c7h,0c7h,0c7h,0c7h
STACK:	ds	0

USTACK:	dw	0
FUNCOD:	db	0
PARAMT:	dw	0
RETCOD:	db	0
MCRPNT:	dw	0
LSTUNT: db	0
F5SETF: db	0
FNTMPF: db	0
ORGBIO: dw	0

HEXMSG: db	0,0,'$'

CLDERR:	db	'Init err$'

COLDSE:	; BC and DE are pushed...
	lxi	d,CLDERR
	mvi	c,CBUFPR
	call	next
	lxi	h,next
	shld	start+1	; only until remove takes place...
	mvi	a,0ffh
	sta	remove
	pop	b
	pop	d
	jmp	next	; pass to BDOS and hope for the best...

; Not a true cold start - we are in context of a valid BDOS call...
COLDST:
	mov	a,c
	cpi	scbf	; hack to avoid init too soon (in LOADER3)
	jz	next	;
	push	d
	push	b
	call	NTWKIN
	ora	a
	jnz	COLDSE
	lxi	h,NDOSE
	shld	start+1
	xra	a	;
	sta	remove	; is the required?
	lxi	h,MSGDAT
	shld	MCRPNT
	; Apparently, it is passe to use BDOS calls for certain things...
	lxi	d,scbadd
	mvi	c,scbf
	call	next
	shld	scbadr
	lxi	d,CSTUP
	mvi	c,CBUFPR
	call	next
	pop	b
	pop	d
	jmp	NDOSE	; this one might be for us

scbadd:	db	03ah, 0

BDERMD:	lhld	scbadr
	mvi	l,scbase+4bh
	mov	a,m
	ret

SYSMSC:	lhld	scbadr
	mvi	l,scbase+4ah
	mov	a,m
	ret

CURUSR: lhld	scbadr
	mvi	l,scbase+44h
	mov	a,m
	ret

; Some sneaky programs, like ERASE.COM, use the "saved search address" from the SCB.
; so we must put the address there if the BDOS does not (i.e. networked drive).
SETSRA:	lhld	PARAMT
	xchg
	lhld	scbadr
	mvi	l,scbase+47h
	mov	m,e
	inx	h
	mov	m,d
	ret

SETDSK: lhld	scbadr
	mvi	l,scbase+3eh
	lda	PARAMT
	mov	m,a
	ret

CURDSK: lhld	scbadr
	mvi	l,scbase+3eh
	mov	a,m
	ret

DMAADD: lhld	scbadr
	mvi	l,scbase+3ch
	mov	a,m
	inx	h
	mov	h,m
	mov	l,a
	ret

CSTUP:	DB	'NDOS3 Started.',CR,LF,'$'
CSTDN:	DB	'NDOS3 Ending.',CR,LF,'$'
;wbmsg:	DB	'NDOS3 Warm-boot.',CR,LF,'$'

NDOSE:
	mov	a,c	; must save REAL function code!
	sta	FUNCOD
	sta	MSGFUN
	ora	a
	jz	WARMST
	cpi	COVLY
	jz	LDOVLY	; LOAD OVERLAY (RSX SCRUB) - indication of warm boot
	cpi	CRSX
	jz	CALRSX	; used to unload CP/Net
	cpi	CBIOS
	jz	next	; DIRECT BIOS CALL - might need to trap for LIST OUT

	lxi	h,FUNTBS
NDOSE1:
	mov	a,c
	sub	m
	jc	next
	inx	h
	cmp	m
	inx	h
	jc	NDOSE2
	inx	h
	inx	h
	mov	a,m
	ora	a
	jnz	NDOSE1
	jmp	next

NDOSE2:
	sspd	USTACK
	lxi	sp,STACK
	mov	c,a	; modified func code!
	mov	a,m
	inx	h
	mov	h,m
	mov	l,a	; HL = func table
	push	h
	xchg
	shld	PARAMT
	call	DMAADD
	shld	DMAADR	; cache DMA address for this call...
	lxi	h,MSGSIZ
	mvi	m,0	; assume 1-byte payload
	inx	h
	shld	MCRPNT	; MSGDAT
	xra	a
	mov	b,a
	mov	d,a
	pop	h	; specific func table in HL
	dad	b
	mov	e,m	; don't need HL anymore
	sub	e	; assumes A=0
	jz	tnextp	; code 0 = not handled by CP/Net
NDOSE4:
	lxi	h,NDENDR
	push	h
	lxi	h,FUNTB2
	dad	d
	push	h
NDOSE5:
	pop	b
	ldax	b
	mov	d,a
	ani	07fh	; strip off EOP bit
	mov	e,a
	mov	a,d
	mvi	d,0
	lxi	h,FUNTB3
	dad	d
	mov	e,m
	inx	h
	mov	d,m
	inx	b
	ral
	jc	NDOSE6
	push	b
	lxi	h,NDOSE5
	push	h
NDOSE6:
	xchg
	pchl

FUNTB3:
	dw	0	; 0	000h	080h - never called
	dw	SNDHDR	; 2	002h	082h
	dw	RCVPAR	; 4	004h	084h
	dw	SNDFCB	; 6	006h	086h
	dw	CKSFCB	; 8	008h	088h
	dw	RENTMP	; 10	00ah	08ah
	dw	WTDTC2	; 12	00ch	08ch
	dw	WTDTC8	; 14	00eh	08eh
	dw	WTDTCP	; 16	010h	090h
	dw	CKSTDK	; 18	012h	092h
	dw	BCSTFN	; 20	014h	094h
	dw	BCSTVC	; 22	016h	096h
	dw	RCVEC	; 24	018h	098h
	dw	GTFCB	; 26	01ah	09ah
	dw	GTFCCR	; 28	01ch	09ch
	dw	GTFCRR	; 30	01eh	09eh
	dw	GTDIRE	; 32	020h	0a0h
	dw	GTOSCT	; 34	022h	0a2h
	dw	GTMISC	; 36	024h	0a4h
	dw	GTLOGV	; 38	026h	0a6h
	dw	LIST1	; 40	028h	0a8h
	dw	SELDSK	; 42	02ah	0aah
	dw	LSTBLK	; 44	02ch	0ach
	dw	GETVER	; 46	02eh	0aeh
	dw	0	; 48	030h	0b0h - to be removed
	dw	RESET	; 50	032h	0b2h
	dw	NWSTAT	; 52	034h	0b4h
	dw	NWCFTB	; 54	036h	0b6h
	dw	SDMSGU	; 56	038h	0b8h
	dw	RVMSGU	; 58	03ah	0bah
	dw	LOGIN	; 60	03ch	0bch
	dw	LOGOFF	; 62	03eh	0beh - generic send to server 'E'
	dw	STSF	; 64	040h	0c0h
	dw	STSN	; 66	042h	0c2h
	dw	0	; 68	044h	0c4h - to be removed
	dw	CKSTDP	;	046h	0c6h
	dw	CHKMSC	;	048h	0c8h

; hi bit is "end" signal, else keep executing routines in list...
; byte & 07fh is index into FUNTB3, routine to call.
FUNTB2:
	db	080h			; - never called
fgtvr	equ	$-FUNTB2
	db	0aeh			;
frssy	equ	$-FUNTB2
	db	0b2h			;
frsvc	equ	$-FUNTB2
	db	096h			;
fsldk	equ	$-FUNTB2
	db	0aah			;
fopfi	equ	$-FUNTB2
	db	008h, 00eh, 018h, 09ah	;
fdlfi	equ	$-FUNTB2
	db	006h, 098h		;
fsrfs	equ	$-FUNTB2
	db	040h, 018h, 0a0h	;
fsrnx	equ	$-FUNTB2
	db	042h, 018h, 0a0h	;
frdsq	equ	$-FUNTB2
	db	048h, 006h, 018h, 01ch, 0a2h	; READ SEQ
fwrsq	equ	$-FUNTB2
	db	048h, 008h, 010h, 018h, 09ch	; WRITE SEQ
frefi	equ	$-FUNTB2
	db	008h, 00ah, 002h, 098h	;
flgvc	equ	$-FUNTB2
	db	0a6h			;
fgtal	equ	$-FUNTB2
	db	012h, 002h, 018h, 0a4h	;
fwrpr	equ	$-FUNTB2
	db	012h, 002h, 098h	;
fstfi	equ	$-FUNTB2
	db	006h, 018h, 09ch	;
frdrr	equ	$-FUNTB2
	db	048h, 006h, 018h, 01eh, 0a2h	; READ RAND
fwrrr	equ	$-FUNTB2
	db	048h, 008h, 010h, 018h, 09eh	; WRITE RAND [ZEROFIL]
fgtsz	equ	$-FUNTB2
	db	006h, 018h, 09eh	;
flkrc	equ	$-FUNTB2
	db	008h, 00ch, 018h, 09eh	;
fstpw	equ	$-FUNTB2
	db	094h			;
flgin	equ	$-FUNTB2
	db	03ch, 098h		;
flgof	equ	$-FUNTB2
	db	03eh, 098h		;
fsdnw	equ	$-FUNTB2
	db	0b8h			;
frvnw	equ	$-FUNTB2
	db	0bah			;
fnwst	equ	$-FUNTB2
	db	0b4h			;
fnwcf	equ	$-FUNTB2
	db	0b6h			;
fstcp	equ	$-FUNTB2	; ***** DUPLICATE of fstpw *****
	db	094h			;
fsvcf	equ	$-FUNTB2
	db	03eh, 018h, 0a4h	;
fgtdl	equ	$-FUNTB2
	db	046h, 002h, 098h	;
fdkms	equ	$-FUNTB2
	db	046h, 002h, 018h, 0a4h	;
flst1	equ	$-FUNTB2
	db	0a8h
flstbk	equ	$-FUNTB2
	db	0ach

; table of message handlers? per BDOS func?
; -1 = ERROR, 0 = PASSTHRU, else index into FUNTB2
FUNTB1:
	db	0	; 0 -
	db	0	; 1 -
	db	0	; 2 -
	db	0	; 3 -
	db	0	; 4 -
	db	flst1	; 5 -
	db	0	; 6 -
	db	0	; 7 -
	db	0	; 8 -
	db	0	; 9 -
	db	0	; 10 -
	db	0	; 11 -
	db	fgtvr	; 12 - GET VERSION
	db	frssy	; 13 - RESET DISK SYSTEM
	db	fsldk	; 14 - SELECT DISK
	db	fopfi	; 15 - OPEN FILE
	db	fopfi	; 16 - CLOSE FILE
	db	fsrfs	; 17 - SEARCH FIRST
	db	fsrnx	; 18 - SEARCH NEXT
	db	fdlfi	; 19 - DELETE FILE
	db	frdsq	; 20 - READ SEQUENTIAL
	db	fwrsq	; 21 - WRITE SEQUENTIAL
	db	fopfi	; 22 - MAKE FILE
	db	frefi	; 23 - RENAME FILE
	db	flgvc	; 24 - GET LOGIN VECTOR
	db	0	; 25 - GET CURRENT DISK
	db	0	; 26 - SET DMA ADDR
	db	fgtal	; 27 - GET ALLOC ADDR
	db	fwrpr	; 28 - WRITE PROTECT DISK
	db	flgvc	; 29 - GET R/O VECTOR
	db	fstfi	; 30 - SET FILE ATTR
	db	fgtal	; 31 - GET DPB ADDR
	db	0	; 32 - GET/SET USER CODE
	db	frdrr	; 33 - READ RANDOM
	db	fwrrr	; 34 - WRITE RANDOM
	db	fgtsz	; 35 - GET FILE SIZE
	db	fgtsz	; 36 - SET RAND RECORD
	db	frsvc	; 37 - RESET DRIVE
	db	frsvc	; 38 - ACCESS DRIVE
	db	frsvc	; 39 - FREE DRIVE
	db	fwrrr	; 40 - WRITE RAND ZERO FILL
	db	0	; 41 - TEST & WRITE RECORD
	db	flkrc	; 42 - LOCK RECORD
	db	flkrc	; 43 - UNLOCK RECORD
	db	0	; 44 - SET MULTISECTOR COUNT
	db	0	; 45 - SET BDOS ERR MODE
	db	fdkms	; 46 - GET DISK FREE SPACE
	db	0	; 47 - CHAIN TO PROGRAM (***? can't chain to remote program)
	db	fstcp	; 48 - FLUSH BUFFERS
	db	0	; 49 - GET/SET SCB
	; 50..63 - handled by special case
NFTB1	equ	$-FUNTB1

	; if any are passed to server, must preserve FUNCOD as real code
FUNTBX:
	db	fstcp	; 98 - FREE BLOCKS
	db	fopfi	; 99 - TRUNCATE FILE
	db	0	; 100 - SET DIR LABEL ****support?****
	db	fgtdl	; 101 - GET DIR LABEL BYTE
	db	fopfi	; 102 - READ FILE DATE-PWD MODE
	db	0	; 103 - WRITE FILE XFCB ****support?****
	db	0	; 104 - SET DATE & TIME
	db	0	; 105 - GET DATE & TIME - can't support here, use SEND NW MESG
	db	fstpw	; 106 - SET DEF PASSWORD
	db	0	; 107 - GET SERIAL NUMBER
	db	0	; 108 - GET/SET PGM RET CODE
	db	0	; 109 - GET/SET CONS MODE
	db	0	; 110 - GET/SET OUT DELIM
	db	0	; 111 - PRINT BLOCK
	db	flstbk	; 112 - LIST BLOCK
NFTBX	equ	$-FUNTBX

	; CP/Net functions, not known to BDOS
FUNTBN:
	db	flgin	; 64 - LOGIN
	db	flgof	; 65 - LOGOFF
	db	fsdnw	; 66 - SEND NW MESG
	db	frvnw	; 67 - RECV NW MESG
	db	fnwst	; 68 - GET NW STATUS
	db	fnwcf	; 69 - GET NW CFG
	db	fstcp	; 70 - SET COMP ATTR
	db	fsvcf	; 71 - GET SERVER CFG
NFTBN	equ	$-FUNTBN

FUNTBS:
	db	0,NFTB1
	dw	FUNTB1
	db	CNMIN,NFTBN
	dw	FUNTBN
	db	CXMIN,NFTBX
	dw	FUNTBX
	dw	0

SNDHDR:
	lxi	h,MSGTOP
	mvi	m,0	; FMT = CP/Net
	inx	h
	; DID (server ID) already set
	inx	h
	; SID, our node ID, will be set by SNIOS
	inx	h
	inx	h
	inx	h
	xchg		; DE = MSGDAT
	lhld	MCRPNT
	ora	a
	dsbc	d	; HL -= DE
	jz	SNDHD1	; size set already
	dcx	h	; SIZ is -1
	xchg
	dcx	h	; point to SIZ byte
	mov	m,e	; SIZ = length - 1
SNDHD1:
	lxi	b,MSGTOP
SDMSGE:
	call	SNDMSG
	inr	a
	rnz
	jmp	NERROR

RVMSGE:
	call	RCVMSG
	inr	a
	rnz
NERROR:
	lxi	h,-1
	mov	a,h
	jmp	NDEND

NDENDR:
	lda	RETCOD
NDEND:
	xchg
	lhld	USTACK
	sphl
	xchg
	mov	l,a
	mov	b,h
	ret

RCVPAR:
	lxi	b,MSGTOP
	call	RVMSGE
	lxi	h,MSGDAT
	shld	MCRPNT
	ret

tnextp:	; abandon call to real BDOS
	lhld	USTACK
	sphl
TBDOSP:
	lhld	PARAMT
	xchg
	lda	FUNCOD
	mov	c,a
	jmp	next

CKFCBD:
	lhld	PARAMT
	mov	a,m
	dcr	a
	jp	CKFCB1
	call	CURDSK
CKFCB1:
	mov	e,a
	mvi	d,0
	call	CHKDSK
	cpi	0ffh
	rnz
	call	TBDOSP
	jmp	NDEND

CHKDSK:
	lxi	h,CFGTBL+BSDSKS
	dad	d
	dad	d
	mov	a,m
	ral
	jc	CHKDS1	; remote disk
	mvi	a,0ffh
	ret
CHKDS1:
	rar
	ani	00fh	; remote server disk number
	inr	a
	mov	c,a
	inx	h
	mov	a,m	; remote server node ID
	sta	MSGID
	ret

SNDFCB:
	call	CKSFCB
	jmp	SNDHDR

CKSFCB:
	call	CKFCBD		; check FCB disk for local/remote (local does not return)
STFCB:
	call	CURUSR
	lhld	MCRPNT
	mov	m,a	; put USR in msg buf
	inx	h
	mov	m,c	; put DSK in msg buf
	inx	h
	push	h
	xchg
	lhld	PARAMT
	inx	h
	lxi	b,35
	ldir	; copy FCB to msg buf
	xchg
	shld	MCRPNT
	xra	a
	sta	FNTMPF
	sta	F5SETF
	pop	h	; point to start of FCB name in msg buf
SUBTMP:
	call	CKDOL	; substitute $NN for $$$ at start of name
	mvi	b,0
	dad	b	; skip rest of 3 chars
	inx	h
	mov	a,m
	ani	080h	; check f5' attr - partial close/delete XFCBs only
	inx	h
	jz	SUBTM1
	mov	a,m
	ani	080h	; check f6' attr - assign passwd/set byte count
	jnz	SUBTM1
	dcr	a
	sta	F5SETF
SUBTM1:
	lda	FNTMPF
	add	a
	sta	FNTMPF
	inx	h
	inx	h
	inx	h
CKDOL:
	mvi	c,3
	mvi	a,'$'
CKDOL1:
	cmp	m
	rnz
	inx	h
	dcr	c
	jnz	CKDOL1
	xchg
	lxi	h,FNTMPF
	inr	m
	dcx	d
	lda	CFGTBL+BSRID	; client (slave) ID
	mov	b,a
	call	HEXDIG
	dcx	d
	mov	a,b
	rar
	rar
	rar
	rar
	call	HEXDIG
	inx	d
	inx	d
	xchg
	ret

HEXDIG:
	ani	00fh
	adi	90h
	daa
	aci	40h
	daa
	stax	d
	ret

RENTMP:
	lhld	MCRPNT
	lxi	d,-19
	dad	d
	jmp	SUBTMP

WTDTC2:	; hardly worth ldir, should just hard-code
	lxi	b,2
	jmp	WTDTCS
WTDTC8:
	lxi	b,8
	jmp	WTDTCS

WTDTCP:
	lxi	b,SCTLNG
WTDTCS:
	lhld	MCRPNT
	xchg
	lhld	DMAADR
	ldir
	xchg
	shld	MCRPNT
	jmp	SNDHDR

CKSTDP:
	lda	PARAMT
	jmp	STDSK0
CKSTDK:
	call	CURDSK
STDSK0:
	mov	e,a
	mvi	d,000h
	call	CHKDSK
	cpi	0ffh
	jnz	STDSK1
	call	TBDOSP
	jmp	NDEND

STDSK1:	; server already set in MSGID
	lhld	MCRPNT
	dcr	c
	mov	m,c
	inx	h
	shld	MCRPNT
	ret

; Handle multi-sector count
CHKMSC:
	call	CKFCBD	; does not return if disk is local
	; From here on, we know the disk is remote
	call	SYSMSC
	cpi	1
	; skip multi-sector handling if count == 1
	rz	; returns to NDOSE5, goto next opcode.
	sta	CURMSC
	pop	h	; NDOSE5 ret addr
	shld	MSCRET
	pop	h	; FUNTB2 pointer (past CHKMSC)
	shld	MSCTBP
	lda	FUNCOD
	cpi	CRREAD
	jc	CKMSC2
	; save rand rec position
	lhld	PARAMT	; FCB
	lxi	b,FCBRR0
	dad	b
	mov	e,m
	inx	h
	mov	d,m
	inx	h
	mov	a,m
	sta	SAVRR+2
	xchg
	shld	SAVRR
	jmp	CKMSC2
CKMSC0:
	lda	RETCOD
	ora	a
	jnz	CKMSC1
	lda	CURMSC
	dcr	a
	sta	CURMSC
	jz	CKMSC1
	lxi	h,MSGDAT
	shld	MCRPNT
	lhld	DMAADR
	lxi	b,128
	dad	b
	shld	DMAADR
	lda	FUNCOD
	cpi	CRREAD
	jc	CKMSC2
	; advance random record number...
	lhld	PARAMT	; FCB
	lxi	b,FCBRR0
	dad	b
	inr	m
	jnz	CKMSC2
	inx	h
	inr	m
	jnz	CKMSC2
	inx	h
	inr	m
CKMSC2:
	lxi	h,CKMSC0
	push	h
	lhld	MSCTBP
	push	h
	lhld	MSCRET
	pchl	; jmp NDOSE5 - do next opcode. Returns to CKMSC0 when done.

; done with multi-sec read/write, restore everything.
CKMSC1:	; could be EOF, or some physical error
	lda	FUNCOD
	cpi	CRREAD
	jc	CKMSC3
	; restore file position...
	lda	SAVRR+2
	lhld	SAVRR
	xchg
	lhld	PARAMT	; FCB
	lxi	b,FCBRR0
	dad	b
	mov	m,e
	inx	h
	mov	m,d
	inx	h
	mov	m,a
	; If the program's next op is random read/write, then we are
	; finished now. But, if the next op is sequential then
	; we must set the file position back to where it started.
	; Use READ RAND to set file position. Response is ignored.
	mvi	a,CRREAD
	sta	MSGFUN
	lxi	h,MSGDAT
	shld	MCRPNT
	call	SNDFCB
	call	RCVPAR
	; ignore data/error returned by CRREAD
CKMSC3:
	mvi	h,0	; success returns NREC=0
	lda	RETCOD
	ora	a
	rz		; NDENDR
	lda	CURMSC	; if error ended us early, need num sec completed.
	mov	e,a	; save where SYSMSC won't destroy it
	call	SYSMSC
	sub	e
	mov	h,a
	ret		; NDENDR


BCSTFN:	; broadcast func (set default password, set compat attrs)
	lxi	d,0
	call	FORALL
	mov	a,c
	inr	c
	jz	RSTALL	; no (more) servers, reset and return
	sta	MSGID
	lhld	PARAMT
	xchg
	lhld	MCRPNT
	lda	FUNCOD
	cpi	CDEFPW-CBMAX	; a.k.a. 106 - set def password
	jz	BCST1
	; fn 70 - set compat attr
	mov	m,e
	jmp	BCST2
BCST1:
	lxi	b,8
	xchg
	ldir
	xchg
	shld	MCRPNT
BCST2:
	call	SNDHDR
	call	RCVPAR
	jmp	BCSTFN

BCSTVC:	; broadcast "drive vector" funcs to all servers
	lhld	PARAMT
	xchg
BCSTV1:
	call	FORALL
	push	h
	mov	a,c
	inr	c
	jnz	BCSTV2	; some remote drives to do
	call	RSTALL
	pop	d
	lda	FUNCOD
	cpi	CRSDSN	; reset drive
	rnz		; only reset drive is passed to local
	mov	c,a
	call	next
	sta	RETCOD
	ret
BCSTV2:
	sta	MSGID
	lxi	h,MSGDAT
	mov	m,e
	inx	h
	mov	m,d
	inx	h
	shld	MCRPNT
	call	SNDHDR
	lda	FUNCOD
	sui	38	; access drive
	jz	BCSTV3
	push	psw
	call	RCVPAR
	pop	psw
	pop	d
	dcr	a
	jz	BCSTV1
	lda	MSGDAT
	sta	RETCOD
	inr	a
	jz	RSTALL
	jmp	BCSTV1

BCSTV3:
	call	RCVEC
	pop	d
	jmp	BCSTV1

; Returns vector of all disks for given server,
; each call skips servers already reported.
FORALL:
	lxi	h,CFGTBL+BSDSKS
	push	d
	lxi	d,0
	lxi	b,010ffh
FORAL1:
	mov	a,m
	ral
	jnc	FORAL6	; local
	ral
	jc	FORAL6	; "already did" flag
	inx	h
	mov	a,c
	cpi	0ffh
	jz	FORAL2
	cmp	m
	jz	FORAL3
	dcx	h
	jmp	FORAL6
FORAL2:
	mov	c,m
FORAL3:
	dcx	h
	mov	a,m
	ori	040h	; mark this one done...
	mov	m,a
	xthl
	call	RHLR0
	jnc	FORAL7
	xthl
	mov	a,m
	ani	00fh
	inr	a
	push	h
	lxi	h,1
FORAL4:
	dcr	a
	jz	FORAL5
	dad	h
	jmp	FORAL4
FORAL5:
	mov	a,e
	ora	l
	mov	e,a
	mov	a,d
	ora	h
	mov	d,a
	pop	h
	jmp	FORAL8
FORAL6:
	xthl
	call	RHLR0
	jnc	FORAL7
	mov	a,h
	ori	080h
	mov	h,a
FORAL7:
	xthl
FORAL8:
	inx	h
	inx	h
	dcr	b
	jnz	FORAL1
	pop	h
	ret

RHLR0:
	ora	a
	mov	a,h
	rar
	mov	h,a
	mov	a,l
	rar
	mov	l,a
	ret

; Reset from FORALL
RSTALL:
	lxi	h,CFGTBL+BSDSKS
	mvi	b,16
RSTAL1:
	mov	a,m
	ani	08fh	; clear FORALL iterator flag(s)
	mov	m,a
	inx	h
	inx	h
	dcr	b
	jnz	RSTAL1
	ret

STSF:	; setup Search First
	mvi	a,0ffh
	sta	CURSID	; assume local
	lhld	PARAMT
	mov	a,m
	cpi	'?'
	jnz	STSF1
	call	CKSTDK
	mvi	c,'?'+080h	; "drive" code with CP/M3 flag
	call	STFCB
	jmp	STSF2
STSF1:
	lhld	MCRPNT
	inx	h
	shld	MCRPNT
	call	CKSFCB	; if remote, set FCB in msg
STSF2:
	lda	MSGID
	sta	CURSID
	call	SETSRA
	jmp	SNDHDR

STSN:	; setup Search Next
	lda	CURSID
	cpi	0ffh	; was Search First a local op?
	jnz	STSN1
	call	TBDOSP
	jmp	NDEND
STSN1:
	sta	MSGID
	call	CURUSR
	lhld	MCRPNT
	inx	h
	mov	m,a
	inx	h
	shld	MCRPNT
	jmp	SNDHDR

RCVEC:
	call	RCVPAR
	lxi	h,MSGDAT+1
	shld	MCRPNT
	mov	d,m	; D = ext err code
	dcx	h
	mov	a,m
	sta	RETCOD
	dcx	h
	mov	a,m	; SIZ
	dcr	a
	mvi	h,0	; ensure H=0 to avoid confusion with extended errors
	rnz		; not extended error - skip rest
	call	BDERMD
	inr	a
	jnz	NDERR
	xchg
	jmp	NDENDR

NDERR:
	push	d
	lxi	d,NDERRM
	call	PRMSG
	pop	psw	; A = (D), ext err code
	push	psw	; Fix bug in NDOS.ASM
	call	HEXOUT
	lxi	d,NDERR2
	call	PRMSG
	lda	FUNCOD
	call	HEXOUT
	call	BDERMD
	pop	h	; H = ext err code
	cpi	0feh
	jz	NDENDR
	jmp	TOP	; abort program

HEXOUT:
	lxi	d,HEXMSG+1	; do low nibble first
	push	psw
	call	HEXDIG
	pop	psw
	rar
	rar
	rar
	rar
	dcx	d	; back to hi nibble
	call	HEXDIG
PRMSG:
	mvi	c,CBUFPR
	jmp	next

GTFCB:
	lda	F5SETF
	inr	a
	jnz	GTFCCR
GTFCRR:
	lxi	b,35	; FCB+CR+RR (-drive)
	jmp	GTFC1
GTFCCR:
	lxi	b,32	; FCB+CR, not RR
GTFC1:
	call	RSTMP	; un-do temp file subst
	lhld	PARAMT
	inx	h
	xchg
	lhld	MCRPNT
	inx	h
	ldir
	shld	MCRPNT
	mvi	h,0	; ensure H=0 to avoid confusion with extended errors
	ret

RSTMP:	; restore TMP filename
	lda	FNTMPF
	rar
	rar
	jnc	RSTMP1
	lhld	MCRPNT
	inx	h
	inx	h
	mvi	m,'$'
	inx	h
	mvi	m,'$'
RSTMP1:
	ral
	rnc
	lhld	MCRPNT
	lxi	d,10
	dad	d
	mvi	m,'$'
	inx	h
	mvi	m,'$'
	ret

GTDIRE:
	lda	RETCOD
	inr	a
	mvi	h,0	; ensure H=0 to avoid confusion with extended errors
	rz
	lhld	MCRPNT
	; Special case for CP/M3 full search, although really
	; any SEARCH that wants to be fully compatible with CP/M
	; neuances - specifically that the DMA buffer contains the
	; full directory sector after a search.
	;
	; CP/Net breaks SEARCH funcs 17/18 by only returning
	; one DIRENT at a time, while the local BDOS calls
	; actually fill the DMA buffer with the directory sector.
	; DIR.COM depends on this for getting timestamps.
	lda	MSGSIZ
	ora	a	; 00 = 1 byte, dir code only, DMA buf implied
	rz		; NDENDR will return dir code to user
	cpi	32+4	; anything 1 < x < 128 really, pick a number (expect 32).
	jnc	STOSC0	; assume 128 bytes, copy all to DMA buffer.
	; single DIRENT returned, copy to correct location.
	xchg
	lhld	DMAADR
	lda	RETCOD
	inr	a
	lxi	b,32
GTDIR1:
	dcr	a
	jz	GTDIR2
	dad	b
	jmp	GTDIR1
GTDIR2:
	xchg
	ldir
	shld	MCRPNT
	ret

GTOSCT:
	lda	RETCOD
	ora	a
	rnz
	lxi	h,MSGDAT+37
STOSC0:
	lded	DMAADR
	lxi	b,SCTLNG
	ldir
	shld	MCRPNT
	mvi	h,0	; ensure H=0 to avoid confusion with extended errors
	ret

GTMISC:
	lhld	MCRPNT
	dcx	h	; drop error byte
	lda	FUNCOD
	cpi	CGTALL	; get alloc addr
	jz	GTMSC3	; for alloc vec, just leave in message buffer
	cpi	CFRSP	; get disk free space
	jz	GTMSC4
	cpi	CGTDPB	; get DPB addr
	jnz	GTMSC1
	; fn 31 - get DPB
	lxi	d,CURDPB
	push	d
	lxi	b,16	; should be 15 for CP/M 2.2, 17 for CP/M 3
	jmp	GTMSC2
GTMSC4:
	lxi	d,0
	push	d
	lded	DMAADR
	lxi	b,3
	jmp	GTMSC2

GTMSC1:		; fn 71 - get server config
	lxi	d,CURSCF
	push	d
	lxi	b,23
GTMSC2:
	ldir
	shld	MCRPNT
	pop	h
GTMSC3:
	mov	a,l
	sta	RETCOD
	ret

GTLOGV:
	lxi	d,CFGTBL+BSDSKE
	lxi	h,0
	mvi	b,16
GTLGV1:
	ldax	d
	dcx	d
	mov	c,a
	ldax	d
	dcx	d
	dad	h
	call	DRVSTS
	dcr	b
	jnz	GTLGV1
	mov	a,l
	sta	RETCOD
	ret

; Get a drive's status (i.e. GET LOGIN VECTOR)
; B = local drive num
; A = net cfg byte, bit-7 = remote, bit-0:3 = remote drive num
; Returns DE bit-0 = drive's status
DRVSTS:
	push	d
	push	b
	push	h
	ral
	jc	DRVST1
	; drive is local
	push	b
	call	TBDOSP
	pop	b
	dcr	b
	xchg
	jmp	DRVST2

DRVST1:	; drive is remote
	rar
	ani	00fh
	mov	b,a	; remote drive number
	mov	a,c	; server ID
	sta	MSGID
	lxi	h,MSGDAT
	shld	MCRPNT
	push	b
	call	SNDHDR
	call	RCVPAR
	pop	b
	lhld	MCRPNT
	mov	e,m
	inx	h
	mov	d,m
DRVST2:	; DE = vector of active drives
	mov	a,b
	ora	a
	jz	DRVST4
DRVST3:	; get drive 'B' bit to LSB
	mov	a,d
	rar
	mov	d,a
	mov	a,e
	rar
	mov	e,a
	dcr	b
	jnz	DRVST3
DRVST4:
	mvi	d,000h
	mov	a,e
	ani	001h
	mov	e,a
	pop	h
	dad	d
	pop	b
	pop	d
	ret

SELDSK:
	lda	PARAMT
	mvi	d,000h
	mov	e,a
	call	CHKDSK
	cpi	0ffh	; local disk
	jz	TBDOSP	; let BDOS handle
	call	SETDSK
	lhld	MCRPNT
	dcr	c
	mov	m,c
	inx	h
	shld	MCRPNT
	call	SNDHDR
	jmp	RCVEC

RESET:	; anything to do? BDOS will be called... but BDOS does not call 0005 (us)?
	lxi	h,MSGDAT
	shld	MCRPNT
	; A: cannot be remote...
	jmp	next

LIST1:
	lxi	d,PARAMT
	lxi	b,1
	jmp	lstbk2

LSTBLK:
	lhld	PARAMT
	mov	e,m
	inx	h
	mov	d,m	; address of data
	inx	h
	mov	c,m
	inx	h
	mov	b,m	; length
	mov	a,c
	ora	b
	rz
lstbk2:
	lxix	CFGTBL+BSLIST
	bitx	7,+0
	jz	tnextp
	lxi	h,CFGTBL+BSLIST+9
	push	d
	ldx	e,+7
	mvi	d,0
	dad	d
	pop	d
lstbk0:
	ldax	d
	inx	d
	mov	m,a
	inx	h
	inrx	+7	; dirty == not-zero
	jm	lstbk3	; send data
	cpi	0ffh	; stop at 0ffh? or need to continue if more?
	jz	lstbk3	; this will continue if more chars exist...
lstbk1:
	dcx	b
	mov	a,b
	ora	c
	jnz	lstbk0
	ret

lstbk3:	; must send buffer
	ldx	a,+0
	ani	0fh
	stx	a,+8
	; SIZ already len-1, incl LST unit
	ldx	a,+1	; LST server
	stx	a,+4	; DID
	push	d
	push	b
	pushix
	lxi	b,CFGTBL+BSLIST+3	; MSG buffer
	call	SNDMSG
	popix
	pushix
	mvix	0,+7	; clear dirty flag, setup for next char
	inr	a
	jz	NERROR
	lxi	b,MSGTOP
	call	RVMSGE
	popix
	pop	b
	pop	d
	lxi	h,CFGTBL+BSLIST+9
	jmp	lstbk1

GETVER:
	lhld	scbadr
	mvi	l,scbase+05h
	mov	l,m
	mvi	h,002h
	mov	a,l
	sta	RETCOD
	ret

NWSTAT:
	call	NTWKST
	sta	RETCOD
	ret

NWCFTB:
	call	CNFTBL
	mov	a,l
	sta	RETCOD
	ret

LOGIN:
	lhld	MCRPNT
	xchg
	lhld	PARAMT
	mov	a,m
	sta	MSGID
	inx	h
	lxi	b,8
	ldir
	xchg
	shld	MCRPNT
	jmp	SNDHDR

LOGOFF:
	lda	PARAMT
	sta	MSGID
	jmp	SNDHDR

SDMSGU:
	lhld	PARAMT
	mov	b,h
	mov	c,l
	call	SNDMSG
	sta	RETCOD
	ret

RVMSGU:
	lhld	PARAMT
	mov	b,h
	mov	c,l
	call	RCVMSG
	sta	RETCOD
	ret

LDERR:
	mvi	a,-1
	pop	h
	ret

SAVDMA:	dw	0
SAVRR:	db	0,0,0
MSCRET:	dw	0
MSCTBP:	dw	0
CURMSC:	db	0
DMAADR:	dw	0

CURDPB:	ds	15
CURSCF:	ds	23

; this is used to do warm boot initialization, since most
; programs do not call BDOS Function 0 but instead just
; JMP 0. The CCP then makes this call, either upon startup
; and/or immediately prior to running a program.
; Perportedly, the CPP calls this with DE=NULL in order
; to scrub RSXs on warm boot.
LDOVLY:
WARMST:
	push	d
	push	b
	call	NTWKBT
	; TODO: any other re-init? reset some context?
;	lxi	d,wbmsg
;	mvi	c,CBUFPR
;	call	next
	pop	b
	pop	d
	jmp	next

; An example of how to process BDOS Func 60 RSX Func 113
; and remove one's self.
CALRSX:
	mov	l,e
	mov	h,d
	mov	a,m
	inx	h
	cpi	113	; Check for RSX Func 113
	jnz	next
	mov	a,m
	inx	h
	cpi	1	; Check param count to be sure
	jnz	next
	push	d
	mov	e,m
	inx	h
	mov	d,m
	lxi	h,rsxnam
	mvi	b,8
rsxf0:			; Compare paramter to our name
	ldax	d
	cmp	m
	jnz	rsxf1
	inx	d
	inx	h
	dcr	b
	jnz	rsxf0
rsxf1:
	pop	d
	jnz	next
	; shutdown NDOS3...
	call	NTWKDN
	lxi	d,CSTDN
	mvi	c,CBUFPR
	call	next
	lxi	h,next
	shld	start+1	; only until remove takes place...
	mvi	a,0ffh
	sta	remove
	lxi	h,0
	mov	a,l
	ret

	end
