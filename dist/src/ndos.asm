; z80dasm 1.1.3
; command line: /home/drmiller/Downloads/z80dasm-1.1.3/src/z80dasm -b ndosv2.blk -l -a -g 0 -t ndosv2.com
;  NETWORK DISK OPERATING SYSTEM FOR CP/NET
;
;  1982.12.31. exact date unknown
;
;TITLE   NETWORK DISK OPERATING SYSTEM FOR CP/NET SLAVE
;
;
;  EQUATIONS OF DATA 
;
LF      EQU     0AH             ;LINE FEED
CR      EQU     0DH             ;CARRIAGE RETURN
EOF     EQU     1AH             ;CTRL-Z IS END OF FILE 
LEOF    EQU     0ffh            ;-1 is logical end of file 
;
TOP	equ	0000h
CDISK	equ	0004h
BDOS	equ	0005h
SYSDMA	equ	0080h
TPA	equ	0100h

SCTLNG	equ	128	;ONE SECTOR LENGTH
;
;  EQUATIONS OF DOS FUNCTION
;
CCNDIN  EQU     3               ;CONSOLE INPUT WITH DEVICE CODE
CCNDOT  EQU     4               ;CONSOLE OUTPUT WITH DEVICE CODE
CBUFPR  EQU     9               ;BUFFER PRINT
CRDBUF  EQU     10              ;READ BUFFER
CCONST  EQU     11              ;GET CONSOLE STATUS
CGETVR  EQU     12              ;GET VERSION NUMBER
CRSDSK  EQU     13              ;RESET DISK
COPEN   EQU     15              ;OPEN FILE
CCLOSE  EQU     16              ;CLOSE FILE
CSRFST  EQU     17              ;SEARCH FIRST
CSRNXT  EQU     18              ;SEARCH NEXT DIRECTORY
CREAD   EQU     20              ;READ FILE
CSTDMA  EQU     26              ;SET DMA ADDRESS
CGTALL  EQU     27              ;get alloc vector addr
CGTDPB  EQU     31              ;get DPB addr
CSTUSC  EQU     32              ;SET USER CODE
CRSDSN  EQU     37              ;RESET DISK BY DISK VERCTOR
CBMAX   EQU     50              ;MAX OF BDOS FUNCTION
CXMIN   EQU     100             ;extended bdos function
CDEFPW  EQU     106             ;set default password
;
CLOGIN  EQU     64              ;LOGIN
CLOGOF  EQU     65              ;LOGOFF
CNMAX   EQU     72              ;MAX OF NDOS FUNCTION

;
;  SLAVE CONFIGRATION TABLE
;
; -1    NETWORK STATUS
;  0    SLAVE PROCESSOR ID
;  1-32 A - P DISK DEVICE CODE
; 33-34 CONSOLE DEVICE
; 35-36 LIST DEVICE
; 37    LIST BUFFER COUNTER
; 38-42 MESSAGE HEADER FOR LIST OUT
; 43    LISTER DEVICE NUMBER
; 44-171 LIST OUT DATA BUFFER
;
;  EACH DEVICE DATA USED 2 BYTES
;  IN 1-36
;  1B:BIT 7 H ON NETWORK
;     BIT 6 H SET UP IN DISK
;     BIT 0-3 DEVICE NUMBER IN MASTER
;  2B:MASTER ID
;
;
;  BIAS TO DATA IN CONFIGRATION TABLE
;
BSDSKS	equ	1		;first byte in disk table
BSDSKE	equ	32		;last byte in disk table
BSCONS  EQU     33              ;BIAS TO CONSOLE DATA
BSLIST  EQU     35              ;BIAS TO LISTER DATA

	org	0

NDOSTP:
CPMIDC:
	jmp	NDOSE
	jmp	COLDST
NDOS:
	jmp	NDOSE
	jmp	COLDST

LSTDRT: db	000h
CTLPF:	db	000h
RDCBFF: db	000h

	db	'COPYRIGHT (C) 1980-82, DIGITAL RESEARCH '
	db	0,12,0,2,4,0c4h

NDERRM:	db	CR,LF,'NDOS Err $'
NDERR2:	db	', Func $'

CONTAD:	dw	0
BDOSE:	dw	0
VERSION: dw	0
CURSID: db	0
	dw	0	; forgotten/unused

MSGTOP:	db	0
MSGID:	db	0
	db	0	; Slave ID - SNIOS (or h/w) sets this
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
OPNUNL: db	0	; Opened in UNLOCK mode, F5' and not F6'
FNTMPF: db	0
ORGBIO: dw	0
CURDSK: db	1
DMAADD:	dw	SYSDMA
CURUSR: db	0

TLBIOS: dw	0
	dw	NWBOOT
	dw	NCONST
	dw	NCONIN
	dw	NCONOT
	dw	NLIST
	dw	0, 0, 0, 0, 0, 0, 0, 0, 0
	dw	NLSTST
	dw	0

CCPFCB:	db	1,'CCP  ',80h+' ','  SPR',0,0,0,0 ; f6' set = ???
	db	0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
	db	0,0,0,0

HEXMSG: db	0,0,'$'
BDERMD: db	0	; current BDOS error mode

COLDST:
	call	NTWKIN
	ora	a
	jnz	COLDSE
	mvi	c,17
	lhld	TOP+1
	shld	ORGBIO
	dcx	h
	lxi	d,TLBIOS
COLDS1:
	push	b
	ldax	d
	mov	c,a
	inx	d
	ldax	d
	mov	b,a
	inx	d
	ora	c
	jz	COLDS2
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
COLDS2:
	inx	h
	inx	h
	inx	h
	pop	b
	dcr	c
	jnz	COLDS1
	call	CNFTBL
	inx	h
	shld	CONTAD
	lhld	BDOS+1
	shld	BDOSE
	lxi	h,MSGDAT
	shld	MCRPNT
	xra	a
	sta	LSTDRT
	sta	CTLPF
	sta	RDCBFF
	lxi	d,NDOS
	mvi	b,006h
COLDS3:
	dcx	d
	dcx	h
	mov	a,m
	stax	d
	dcr	b
	jnz	COLDS3
	mvi	c,CGETVR
	call	BDOS
	shld	VERSION
	jmp	NWBOOT

COLDSE:	; BIOS intercepts not yet set, so can exit as if nothing happened.
	mvi	c,CBUFPR
	lxi	d,INERMS
	call	BDOS
	jmp	TOP

INERMS: db	'Init Err$'

NDOSE:
	lxi	h,0
	mov	a,c
	cpi	CXMIN
	jc	NDOSE1
	sui	CXMIN-CBMAX	; map 100... to 50... (CP/M 2.2 has no funcs 50...)
NDOSE1:
	cpi	CNMAX	; < 72 (or < 122)
	jc	NDOSE2
	dcx	h
	mov	a,h
	ret
NDOSE2:
	dad	sp
	shld	USTACK
	lxi	sp,STACK
	lxi	h,NDEND
	push	h
	mov	c,a
	cpi	CRDBUF	; READ CONSOLE BUFFER (LINE INPUT)
	mvi	a,0
	jnz	NDOSE3
	inr	a
NDOSE3:
	sta	RDCBFF
	xchg	
	shld	PARAMT
	mov	a,c
	sta	FUNCOD
	sta	MSGFUN
	lxi	h,MSGSIZ
	mvi	m,0
	inx	h
	shld	MCRPNT
	xra	a
	mov	b,a
	mov	d,a
	lxi	h,FUNTB1
	dad	b
	mov	e,m
	sub	e
	jz	TBDOSP
	dcr	a
	jnz	NDOSE4
	dcr	a
	mov	h,a
	mov	l,a
	ret
NDOSE4:
	lxi	h,NDENDR
	xthl	
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
	dw	NWBOOT	; 0	000h	080h
	dw	SNDHDR	; 2	002h	082h
	dw	RCVPAR	; 4	004h	084h
	dw	SNDFCB	; 6	006h	086h
	dw	CKSFCB	; 8	008h	088h
	dw	RENTMP	; 10	00ah	08ah
	dw	STFID	; 12	00ch	08ch
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
	dw	SETDMA	; 40	028h	0a8h
	dw	SELDSK	; 42	02ah	0aah
	dw	SGUSER	; 44	02ch	0ach
	dw	GETVER	; 46	02eh	0aeh
	dw	GETDSK	; 48	030h	0b0h
	dw	RESET	; 50	032h	0b2h
	dw	NWSTAT	; 52	034h	0b4h
	dw	NWCFTB	; 54	036h	0b6h
	dw	SDMSGU	; 56	038h	0b8h
	dw	RVMSGU	; 58	03ah	0bah
	dw	LOGIN	; 60	03ch	0bch
	dw	LOGOFF	; 62	03eh	0beh
	dw	STSF	; 64	040h	0c0h
	dw	STSN	; 66	042h	0c2h
	dw	STBDER	; 68	044h	0c4h

; hi bit is "end" signal, else keep executing routines in list...
; byte & 07fh is index into FUNTB3, routine to call.
FUNTB2:
	db	080h			; 0	000h
	db	0aeh			; 1	001h
	db	0b2h			; 2	002h
	db	096h			; 3	003h
	db	0aah			; 4	004h
	db	008h, 00eh, 018h, 09ah	; 5	005h
	db	006h, 098h		; 9	009h
	db	040h, 018h, 0a0h	; 11	00bh
	db	042h, 018h, 0a0h	; 14	00eh
	db	006h, 018h, 01ch, 0a2h	; 17	011h
	db	008h, 010h, 018h, 09ch	; 21	015h
	db	008h, 00ah, 002h, 098h	; 25	019h
	db	0a6h			; 29	01dh
	db	0b0h			; 30	01eh
	db	0a8h			; 31	01fh
	db	012h, 002h, 018h, 0a4h	; 32	020h
	db	012h, 002h, 098h	; 36	024h
	db	006h, 018h, 09ch	; 39	027h
	db	0ach			; 42	02ah
	db	006h, 018h, 01eh, 0a2h	; 43	02bh
	db	008h, 010h, 018h, 09eh	; 47	02fh
	db	006h, 018h, 09eh	; 51	033h
	db	008h, 00ch, 018h, 09eh	; 54	036h
	db	0c4h			; 58	03ah
	db	094h			; 59	03bh
	db	03ch, 098h		; 60	03ch
	db	03eh, 098h		; 62	03eh
	db	0b8h			; 64	040h
	db	0bah			; 65	041h
	db	0b4h			; 66	042h
	db	0b6h			; 67	043h
	db	094h			; 68	044h
	db	03eh, 018h, 0a4h	; 69	045h

; table of message handlers? per BDOS func?
; -1 = ERROR, 0 = PASSTHRU, else index into FUNTB2
FUNTB1:
	db	0	; 0 -
	db	0	; 1 -
	db	0	; 2 -
	db	0	; 3 -
	db	0	; 4 -
	db	0	; 5 -
	db	0	; 6 -
	db	0	; 7 -
	db	0	; 8 -
	db	0	; 9 -
	db	0	; 10 -
	db	0	; 11 -
	db	001h	; 12 - GET VERSION
	db	002h	; 13 - RESET DISK SYSTEM
	db	004h	; 14 - SELECT DISK
	db	005h	; 15 - OPEN FILE
	db	005h	; 16 - CLOSE FILE
	db	00bh	; 17 - SEARCH FIRST
	db	00eh	; 18 - SEARCH NEXT
	db	009h	; 19 - DELETE FILE
	db	011h	; 20 - READ SEQUENTIAL
	db	015h	; 21 - WRITE SEQUENTIAL
	db	005h	; 22 - MAKE FILE
	db	019h	; 23 - RENAME FILE
	db	01dh	; 24 - GET LOGIN VECTOR
	db	01eh	; 25 - GET CURRENT DISK
	db	01fh	; 26 - SET DMA ADDR
	db	020h	; 27 - GET ALLOC ADDR
	db	024h	; 28 - WRITE PROTECT DISK
	db	01dh	; 29 - GET R/O VECTOR
	db	027h	; 30 - SET FILE ATTR
	db	020h	; 31 - GET DPB ADDR
	db	02ah	; 32 - GET/SET USER CODE
	db	02bh	; 33 - READ RANDOM
	db	02fh	; 34 - WRITE RANDOM
	db	033h	; 35 - GET FILE SIZE
	db	033h	; 36 - SET RAND RECORD
	db	003h	; 37 - RESET DRIVE
	db	003h	; 38 - ACCESS DRIVE
	db	003h	; 39 - FREE DRIVE
	db	02fh	; 40 - WRITE RAND ZERO FILL
	db	-1	; 41 - TEST & WRITE RECORD
	db	036h	; 42 - LOCK RECORD
	db	036h	; 43 - UNLOCK RECORD
	db	-1	; 44 - SET MULTISECTOR COUNT
	db	03ah	; 45 - SET BDOS ERR MODE
	db	-1	; 46 - GET DISK FREE SPACE
	db	-1	; 47 - CHAIN TO PROGRAM
	db	-1	; 48 - FLUSH BUFFERS
	db	-1	; 49 - GET/SET SCB
	db	-1	; 50/100 - DIRECT BIOS CALLS/SET DIR LABEL
	db	-1	; 51/101 -
	db	-1	; 52/102 -
	db	-1	; 53/103 -
	db	-1	; 54/104 -
	db	-1	; 55/105 -
	db	03bh	; 56/106 - /SET DEF PASSWORD
	db	-1	; 57/107 -
	db	-1	; 58/108 -
	db	-1	; 59/109 -
	db	-1	; 60 -
	db	-1	; 61 -
	db	-1	; 62 -
	db	-1	; 63 -
	db	03ch	; 64 - LOGIN
	db	03eh	; 65 - LOGOFF
	db	040h	; 66 - SEND NW MESG
	db	041h	; 67 - RECV NW MESG
	db	042h	; 68 - GET NW STATUS
	db	043h	; 69 - GET NW CFG
	db	044h	; 70 - SET COMP ATTR
	db	045h	; 71 - GET SERVER CFG

SNDHDR:
	lhld	CONTAD
	xchg	
	lxi	h,MSGTOP
	mvi	m,0	; FMT = CP/Net
	ldax	d
	inx	h
	inx	h
	mov	m,a	; SID = our node ID
	inx	h
	inx	h
	inx	h
	xchg		; DE = MSGDAT
	lhld	MCRPNT
	xra	a	; negate DE (BC = 0 - DE)
	sub	e
	mov	c,a
	mvi	a,0
	sbb	d
	mov	b,a
	dad	b	; HL -= DE
	mov	a,l
	ora	h
	jz	SNDHD1	; size set already
	dcx	h
	xchg
	dcx	h
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

TBDOSP:
	lhld	PARAMT
	xchg	
	lda	FUNCOD
	mov	c,a
TOBDOS:
	lhld	BDOSE
	pchl	

CKFCBD:	; sets server ID
	lhld	PARAMT
	mov	a,m
	dcr	a
	jp	CKFCB1
	lda	CURDSK
CKFCB1:
	mov	e,a
	mvi	d,0
	call	CHKDSK
	cpi	0ffh
	rnz	
	call	TBDOSP
	jmp	NDEND

CHKDSK:	; sets server ID
	lhld	CONTAD
	dad	d
	dad	d
	inx	h
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

NWBOOT:
	lxi	sp,TPA
	lxi	h,NDOS
	shld	BDOS+1
	lhld	ORGBIO
	shld	TOP+1
	xra	a
	sta	PARAMT
	call	SGUSER
	call	RESET
	mvi	a,39	; FREE DRIVE
	sta	FUNCOD
	sta	MSGFUN
	lxi	h,0ffffh
	shld	PARAMT
	call	BCSTVC
	xra	a
	sta	CCPFCB+32
	lxi	d,CCPFCB
	lxi	h,NDOSTP
	call	LOAD
	ora	a
	jz	GOCCP
	mvi	c,CBUFPR
	lxi	d,CLDERR
	call	TOBDOS
	jmp	$

CLDERR:	db	'CCP.SPR ?$'

GOCCP:
	lda	CDISK
	mov	c,a
	sphl
	push	h
	push	b
	lda	CURUSR
	mov	e,a
	mvi	c,CSTUSC
	call	TOBDOS
	call	NTWKBT
	pop	b
	ret

SNDFCB:
	call	CKSFCB
	jmp	SNDHDR

CKSFCB:	; sets server ID
	call	CKFCBD		; check FCB disk for local/remote (local does not return)
STFCB:
	lhld	MCRPNT
	lda	CURUSR
	mov	m,a	; put USR in msg buf
	inx	h
	mov	m,c	; put DSK in msg buf
	inx	h
	xchg	
	lhld	PARAMT
	inx	h
	xchg	
	mvi	b,35
	call	MCPYTS	; copy FCB to msg buf
	xra	a
	sta	FNTMPF
	sta	OPNUNL
	lhld	MCRPNT
	lxi	d,-35
	dad	d	; point to start of FCB name in msg buf
SUBTMP:
	call	CKDOL	; substitute $NN for $$$ at start of name
	mvi	b,0
	dad	b	; skip rest of 3 chars
	inx	h
	mov	a,m
	ani	080h	; check f5' attr - MP/M Open/Make in Unlocked Mode
	inx	h	;                  (Close: partial close)
	jz	SUBTM1	;                  (Delete: delete XFCBs only)
	mov	a,m
	ani	080h	; check f6' attr - MP/M Open Read-Only
	jnz	SUBTM1	;                  (Make: assign password)
	dcr	a
	sta	OPNUNL
SUBTM1:
	lda	FNTMPF
	add	a
	sta	FNTMPF
	inx	h
	inx	h
	inx	h	; substitute $NN for $$$ in file type
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
	lhld	CONTAD
	mov	a,m	; client (slave) ID
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
	cpi	10
	jnc	HEXDG1
	adi	'0'
	stax	d
	ret
HEXDG1:
	adi	'A'-10
	stax	d
	ret

RENTMP:
	lhld	MCRPNT
	lxi	d,-19
	dad	d
	jmp	SUBTMP

MCPYTS:
	ldax	d
	mov	m,a
	inx	h
	inx	d
	dcr	b
	jnz	MCPYTS
	shld	MCRPNT
	ret

STFID:	; File ID from DMA[0:1].
	mvi	b,2
	jmp	WTDTCS
WTDTC8:
	mvi	b,8
	jmp	WTDTCS

WTDTCP:
	mvi	b,SCTLNG
WTDTCS:
	lhld	DMAADD
	xchg	
	lhld	MCRPNT
	call	MCPYTS
	jmp	SNDHDR

CKSTDK:
	lda	CURDSK
	mov	e,a
	mvi	d,0
	call	CHKDSK
	cpi	0ffh
	jnz	STDSK1
	call	TBDOSP
	jmp	NDEND

STDSK1:
	sta	MSGID
	lhld	MCRPNT
	dcr	c
	mov	m,c
	inx	h
	shld	MCRPNT
	ret

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
	; min size is 1 byte, so OK to leave MCRPNT at 0
	jmp	BCST2
BCST1:
	mvi	b,8
	call	MCPYTS
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
	call	TOBDOS
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
	lhld	CONTAD
	inx	h
	push	d
	lxi	d,0
	lxi	b,016ffh	; bug? should be 010ffh?
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
	lhld	CONTAD
	inx	h
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
	mvi	c,'?'	; "drive" code
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
	jmp	SNDHDR

STSN:	; setup Search Next
	lda	CURSID
	cpi	0ffh	; was Search First a local op?
	jnz	STSN1
	call	TBDOSP
	jmp	NDEND
STSN1:
	sta	MSGID
	lda	CURUSR
	lhld	MCRPNT
	inx	h
	mov	m,a
	inx	h
	shld	MCRPNT
	jmp	SNDHDR

; returns disk (FCB[0]) in D
RCVEC:
	call	RCVPAR
	lxi	h,MSGDAT+1
	shld	MCRPNT
	mov	d,m	; FCB[0]
	dcx	h
	mov	a,m	; result
	sta	RETCOD
	dcx	h
	mov	a,m	; MSGSIZ
	dcr	a
	rnz		; not error - skip rest
	lda	BDERMD
	inr	a
	jnz	NDERR
	xchg		; H = D (err code)
	jmp	NDENDR

NDERR:
	push	d
	lxi	d,NDERRM
	call	PRMSG
	pop	psw	; A = (D) (err code)
	; BUG? should PUSH PSW here?
	call	HEXOUT
	lxi	d,NDERR2
	call	PRMSG
	lda	FUNCOD
	call	HEXOUT
	pop	psw	; BUG?
	mov	h,a
	lda	BDERMD
	cpi	0feh
	jz	NDENDR
	jmp	NWBOOT

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
	jmp	TOBDOS

GTFCB:
	lda	OPNUNL
	inr	a
	jnz	GTFCCR
	; Not RR, but File ID in r0,r1 due to open in UNLOCKED mode...
GTFCRR:
	mvi	b,35	; FCB+CR+RR (-drive)
	jmp	GTFC1
GTFCCR:
	mvi	b,32	; FCB+CR, not RR?
GTFC1:
	call	RSTMP	; un-do temp file subst
	lhld	MCRPNT
	inx	h	; skip drive, it might have changed
	xchg	
	lhld	PARAMT
	inx	h
	;jmp	MCPYFS

MCPYFS:
	ldax	d
	mov	m,a
	inx	d
	inx	h
	dcr	b
	jnz	MCPYFS
	xchg	
	shld	MCRPNT
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
	rz	
	lhld	MCRPNT
	xchg	
	lhld	DMAADD
	lxi	b,32
GTDIR1:
	dcr	a
	jz	GTDIR2
	dad	b
	jmp	GTDIR1
GTDIR2:
	mov	b,c
	call	MCPYFS
	ret

GTOSCT:
	lda	RETCOD
	ora	a
	rnz	
	lxi	h,MSGDAT+37
	xchg	
	lhld	DMAADD
	mvi	b,SCTLNG
	jmp	MCPYFS

GTMISC:
	lhld	MCRPNT
	dcx	h
	lda	FUNCOD
	cpi	CGTALL	; get alloc addr
	jz	GTMSC3	; for alloc vec, just leave in message buffer
	xchg
	cpi	CGTDPB	; get DPB addr
	jnz	GTMSC1
	; fn 31 - get DPB
	lxi	h,CURDPB
	push	h
	mvi	b,16	; should be 15 for CP/M 2.2, 17 for CP/M 3
	jmp	GTMSC2

GTMSC1:		; fn 71 - get server config
	lxi	h,CURSCF
	push	h
	mvi	b,23
GTMSC2:
	call	MCPYFS
	pop	h
GTMSC3:
	mov	a,l
	sta	RETCOD
	ret

GTLOGV:
	lhld	CONTAD
	lxi	d,BSDSKE
	dad	d
	xchg	
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

SETDMA:
	lhld	PARAMT
	shld	DMAADD
	jmp	TBDOSP

SELDSK:
	lda	PARAMT
	sta	CURDSK
	mvi	d,000h
	mov	e,a
	call	CHKDSK
	cpi	0ffh	; local disk
	jz	TBDOSP	; let BDOS handle
	lhld	MCRPNT
	dcr	c
	mov	m,c
	inx	h
	shld	MCRPNT
	call	SNDHDR
	jmp	RCVEC

RESET:
	lxi	h,SYSDMA
	shld	DMAADD
	xchg	
	mvi	c,CSTDMA
	call	TOBDOS
	xra	a
	sta	PARAMT
	mvi	a,14	; select disk
	sta	FUNCOD
	sta	MSGFUN
	lxi	h,MSGDAT
	shld	MCRPNT
	call	SELDSK
	lhld	CONTAD	; check if A: is remote...
	inx	h
	mov	a,m
	ral
	jc	RESET1
	mvi	c,CRSDSK	; reset disk system
	call	TOBDOS
	sta	RETCOD
	ret
RESET1:
	lhld	BDOSE
	mov	a,l
	cpi	006h
	jnz	RESET2
	mvi	l,025h	; offset of variable in standard BDOS?
	mov	e,m
	inx	h
	mov	d,m
	xchg
	inx	h
	mvi	m,0	; force user code to 0 without calling BDOS?
RESET2:
	lxi	d,0ffffh
	mvi	c,CRSDSN	; reset drives
	jmp	TOBDOS

SGUSER:
	lda	PARAMT
	cpi	0ffh
	lxi	h,CURUSR
	mov	e,a
	mov	a,m
	sta	RETCOD
	rz		; skip if GET
	mov	m,e
	mvi	c,020h	; min CP/M version allowed.
	lda	VERSION
	cmp	c
	rc	
	jmp	TOBDOS

GETVER:
	lhld	VERSION
	mvi	a,002h
	ora	h
	mov	h,a
	mov	a,l
	sta	RETCOD
	ret

GETDSK:
	lda	CURDSK
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
	lhld	PARAMT
	mov	a,m
	sta	MSGID
	inx	h
	xchg	
	lhld	MCRPNT
	mvi	b,8
	call	MCPYTS
	jmp	SNDHDR

LOGOFF:
	lda	PARAMT
	sta	MSGID
	jmp	SNDHDR

SDMSGU:
	lhld	PARAMT
	mov	b,h
	mov	c,l
	jmp	SDMSGE

RVMSGU:
	lhld	PARAMT
	mov	b,h
	mov	c,l
	jmp	RVMSGE

STBDER:
	lda	PARAMT
	sta	BDERMD
	ret

NCONST:
	lhld	TLBIOS+4
	lxi	d,11
	jmp	NCONCM

NCONIN:
	lxi	h,CPCHK
	push	h
	lhld	TLBIOS+6
	lxi	d,3
	jmp	NCONCM

CPCHK:
	push	psw
	cpi	010h	; ^P
	jnz	CPCHK5
	lda	RDCBFF
	ora	a
	jz	CPCHK5
	lhld	CONTAD
	dcx	h
	lda	CTLPF
	ora	a
	jz	CPCHK2
	xra	a
	sta	CTLPF
	mov	a,m
	ani	0fbh	; Ctl-P flag OFF
	mov	m,a
	lxi	d,BSLIST+1	; +1 for dcx h
	dad	d
	mov	a,m
	ral
	mvi	c,LEOF	; EOF for list device
	cc	NLIST
	xra	a
	sta	LSTDRT
	lxi	h,'FF'
	shld	CTPMSG+7
	jmp	CPCHK3

CTPMSG:	db	'Ctl-P OFF',0

CPCHK2:
	mvi	a,0ffh
	sta	CTLPF
	mov	a,m
	ori	004h
	mov	m,a
	lxi	h,'N'
	shld	CTPMSG+7
CPCHK3:
	lxi	h,CTPMSG
CPCHK4:
	mov	a,m
	ora	a
	jz	CPCHK5
	mov	c,a
	inx	h
	push	h
	call	NCONOT
	pop	h
	jmp	CPCHK4
CPCHK5:
	pop	psw
	ret

NCONOT:
	lhld	TLBIOS+8
	lxi	d,0100h+4	; count + func offset
NCONCM:
	push	h
	push	b
	lhld	CONTAD
	lxi	b,BSCONS
	dad	b
	pop	b
	mov	a,m
	ral
	rnc	
	mov	a,m
	ani	00fh
	mov	b,a
	inx	h
	mov	a,m
	lxi	h,MSGTOP
	mvi	m,0
	inx	h
	mov	m,a
	xthl	
	lhld	CONTAD
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
	lxi	b,MSGTOP
	call	SDMSGE
	lxi	b,MSGTOP
	call	RVMSGE
	lda	MSGDAT
	ret

NLIST:
	mvi	a,0ffh
	sta	LSTDRT
	lhld	CONTAD
	lxi	d,BSLIST
	dad	d
	mov	a,m
	ral
	jc	NLIST1
	lhld	TLBIOS+10
	pchl	
NLIST1:
	mov	a,m
	ani	00fh
	sta	LSTUNT
	push	b
	mov	b,c
	inx	h
	inx	h
	mov	c,m
	inr	m
	mvi	a,080h
	cmp	m
	jz	NLIST2
	mov	a,b
	cpi	0ffh
	jnz	NLIST3
NLIST2:
	xra	a
	mov	m,a
	sta	LSTDRT
NLIST3:
	lxi	d,7
	dad	d
	mvi	b,000h
	dad	b
	pop	d
	mov	m,e
	rnz	
	lhld	CONTAD
	lxi	d,BSLIST+1
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
	lda	LSTUNT
	mov	m,a
	call	SDMSGE
	lxi	b,MSGTOP
	jmp	RVMSGE

NLSTST:
	lhld	CONTAD
	lxi	d,BSLIST
	dad	d
	mov	a,m
	ral
	jc	NLSTS1
	lhld	TLBIOS+30
	pchl	
NLSTS1:
	ret

LOAD:
	shld	LDBOTM
	xchg	
	shld	LDFCB
	mvi	c,CSTDMA	; set DMA addr
	lxi	h,-SCTLNG
	dad	d
	shld	LDDMA
	xchg	
	call	BDOS
	lhld	LDFCB
	xchg
	mvi	c,COPEN	; open file
	call	BDOS
	cpi	0ffh
	rz
	call	OSREAD
	lhld	LDDMA
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
	shld	LDLNGT
	dad	b
	xchg	
	lhld	LDBOTM
	xchg	
	xra	a
	sub	l
	mov	l,a
	mvi	a,000h
	sbb	h
	mov	h,a
	dad	d
	mvi	l,000h
	shld	LDTOP
	xchg	
	lxi	h,-SCTLNG
	dad	d
	shld	LDDMA
	call	OSREAD
	lhld	LDLNGT
	lxi	d,SCTLNG-1
	dad	d
	mov	a,l
	ral
	mov	a,h
	ral
	lhld	LDTOP
LOAD1:
	sta	LDCNT
	shld	LDPNT
	xchg	
	mvi	c,CSTDMA
	call	BDOS
	call	OSREAD
	lhld	LDPNT
	lxi	d,SCTLNG
	dad	d
	lda	LDCNT
	dcr	a
	jnz	LOAD1
	lhld	LDDMA
	xchg	
	mvi	c,CSTDMA	; set DMA addr
	call	BDOS
	lhld	LDLNGT
	mov	b,h
	mov	c,l
	xchg	
	lhld	LDTOP
	xchg	
	dad	d
	push	h
	mov	h,d
LOAD2:
	mov	a,b
	ora	c
	jnz	LOAD3
	pop	h
	push	psw
	lhld	LDFCB
	xchg	
	mvi	c,CCLOSE	; close file
	call	BDOS
	pop	psw
	lhld	LDTOP
	ret
LOAD3:
	dcx	b
	mov	a,e
	ani	007h
	jnz	LOAD5
	xthl	
	mov	a,l
	ani	07fh
	jnz	LOAD4
	push	b
	push	d
	push	h
	lhld	LDFCB
	xchg	
	mvi	c,CREAD	; read seq.
	call	BDOS
	pop	h
	pop	d
	pop	b
	lhld	LDDMA
	ora	a
	jnz	LDERR
LOAD4:
	mov	a,m
	inx	h
	xthl	
	mov	l,a
LOAD5:
	mov	a,l
	ral
	mov	l,a
	jnc	LOAD6
	ldax	d
	add	h
	stax	d
LOAD6:
	inx	d
	jmp	LOAD2

OSREAD:
	lhld	LDFCB
	xchg	
	mvi	c,CREAD	; read seq.
	call	BDOS
	ora	a
	rz	
LDERR:
	mvi	a,-1
	pop	h
	ret

	db	0,0,0	; forgotten?

LDDMA:	dw	0
LDLNGT:	dw	0
LDFCB:	dw	0
LDBOTM:	dw	0
LDTOP:	dw	0
LDCNT:	db	0
LDPNT:	dw	0

CURDPB:	ds	15
CURSCF:	ds	23

	org	0bffh
	db	0	;NDOS BOTTOM

;
;  SNIOS ROUTINES
;
NTWKIN	EQU	$	;NETWORK INITIALIZE
NTWKST	EQU	$+3	;NETWORK STATUS
CNFTBL	EQU	$+6	;GET CONFIGRATION TABLE ADDRESS
SNDMSG	EQU	$+9	;SEND MESSAGE
RCVMSG	EQU	$+12	;RECEIVE MESSAGE
NTWKER	EQU	$+15	;NETWORK ERROR
NTWKBT	EQU	$+18	;NETWORL WARM BOOT
;
;

	end
