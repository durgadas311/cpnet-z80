;  CP/NET LOADER  FOR CP/NET VER. 1.0
;
;  1982.8.6. BASE
;
;TITLE	CP/NET LOADER VER.1.0
;
wiznet	equ	1
if	wiznet
	extrn	wizcfg,cpnsetup
	public	nvbuf
endif
;
;  EQUATIONS OF DATA
;
LF	EQU	0AH		;LINE FEED
CR	EQU	0DH		;CARRIAGE RETURN
;
TOP	EQU	0		;MEMORY TOP
BDOS	EQU	5		;BDOS ENTRY
RESFCB	EQU	5CH		;RESIDENT FCB
SCTLNG	EQU	128		;SECTOR LENGTH
;
;  EQUATIONS OF BDOS FUNCTION
;
CRESET	EQU	0		;SYSTEM RESET
CCONOT	EQU	2		;CONSOLE OUT
CBUFPR	EQU	9		;BUFFERED STRING PRINT
CGETVR	EQU	12		;GET VERSION NUMBER
COPEN	EQU	15		;OPEN FILE
CREAD	EQU	20		;READ FILE
CSTDMA	EQU	26		;SET DMA ADDRESS
;
	cseg
;  START
;
	JMP	START
;
;  BREAK POINT RESTART NUMBER FOR DEBUG
;
BPNUM:	DB	7
;
;  COMMENTS
;
	DB	'COPYRIGHT (C) 1982,'
;
PUSRID:	DB	' DIGITAL RESEARCH '	;USER ID IS SEARCHED BY THIS STRING
;
;  USER ID CODE
;
	DB	0,0,0,0,0,0
;
CDSKER:	DB	'Disk read error$'
;
PDEBBP:	DW	DEBBP		;POINTER OF DEBUGGER BREAK POINT ROUTINE
;
CSYNC:	DB	'Synchronization$'
CARLOD:	DB	CR,LF,'CP/Net is already loaded.$'
CSTUP:	DB	CR,LF,LF,'CP/NET 1.2 Loader'
	DB	CR,LF,'=================',CR,LF,LF,'$'
;
CBIOS:	DB	'BIOS       $'
CBDOS:	DB	'BDOS       $'
CSNIOS:	DB	'SNIOS   SPR$'
CNDOS:	DB	'NDOS    SPR$'
CTPA:	DB	'TPA        $'
;
CLEND:	DB	'CP/NET 1.2 loading complete.$'
CLERR:	DB	CR,LF,'CP/NET Loader error: $'
;
;  START OF MAIN
;
	LXI	SP,PFLNAM
START:
	LXI	H,STACK
	SPHL			;SET STACK POINTER
	LXI	D,0
	MVI	C,CGETVR	;GET VERSION NUMBER
	CALL	BDOS
	LXI	D,200H
	CALL	ANHLDE		;GET CP/NET MODE
	MVI	A,0
	CALL	SUBYHL		;CHECK ZERO
	ORA	L
	JZ	STARTS		;CP/NET IS NOT LOADED OK
	LXI	B,CARLOD	;CP/NET ALREADY LOADED
	CALL	BUFPRN
exit:	LXI	D,0
	MVI	C,CRESET
	CALL	BDOS		;RETURN TO SYSTEM
;
STARTS:
if	wiznet
	call	wizcfg
	cc	nocfg	; report error, but continue...
endif
	LHLD	BDOSPT		;GET POINT OF BDOS POINTER
	LXI	D,0FF00H
	CALL	ANHMDE		;OFF LOWER BYTE
	SHLD	FREBOT		;SAVE AVAILABLE AREA TOP
	LDA	RESFCB+1	;GET DEBUG MODE
	STA	FDEBUG
	LXI	B,CSTUP
	CALL	BUFPRN		;START UP COMMENT
;
	LXI	B,CBIOS		;BIOS
	CALL	BUFPRN
	LXI	H,TOP+1
	SHLD	BDOSPT		;SET POINTER OF BIOS ROUTINE POINTER
	LHLD	BDOSPT
	MOV	C,M
	INX	H
	MOV	B,M		;GET BIOS POINT
	DCX	B
	DCX	B
	DCX	B
	CALL	LOCPR		;PRINT BIOS TOP
	LHLD	BDOSPT
	LXI	D,-1
	CALL	SUDEHM		;GET COMPLEMET OF BIOS POINT VALUE
	LXI	D,4		;GET BIAS
	DAD	D
	MOV	B,H
	MOV	C,L
	CALL	LOCPR		;PRINT BIOS LENGTH
	CALL	CRLF
;
	LXI	B,CBDOS		;BDOS
	CALL	BUFPRN
	LHLD	FREBOT		;GET BDOS TOP
	MOV	B,H
	MOV	C,L
	CALL	LOCPR		;PRINT BDOS TOP
	LHLD	BDOSPT
	MOV	C,M
	INX	H
	MOV	B,M
	DCX	B
	DCX	B
	DCX	B		;BIOS TOP
	MOV	D,B
	MOV	E,C
	LHLD	FREBOT
	CALL	SUDEHL		;GET BDOS LENGTH
	MOV	B,H
	MOV	C,L
	CALL	LOCPR		;PRINT BDOS LENGTH
	CALL	CRLF
;
	LXI	H,CSNIOS	;SNIOS.SPR
	SHLD	PFLNAM		;SET FILE NAME POINT FOR ERROR ROUTINE
	MOV	B,H
	MOV	C,L
	CALL	BUFPRN
	LHLD	FREBOT		;GET LOADING POINT
	MOV	B,H
	MOV	C,L
	LXI	D,FSNIOS	;FCB POINT OF SNIOS.SPR
	CALL	LOAD		;LOAD SNIOS.SPR
	SHLD	TOPPNT		;SAVE SNIOS TOP
	LXI	D,-1
	CALL	SUDEHL		;CHECK ERROR
	ORA	L
	JNZ	$+6		;NOT ERROR
	JMP	ERROR		;SNIOS.SPR LOAD ERROR
;
	LHLD	TOPPNT
	shld	sniose
	MOV	B,H
	MOV	C,L
	CALL	LOCPR		;PRINT SNIOS TOP
	LXI	B,TOPPNT
	LXI	D,FREBOT
	CALL	SUDMBM		;GET SNIOS LENGTH
	MOV	B,H
	MOV	C,L
	CALL	LOCPR		;PRINT SNIOS LENGTH
	CALL	CRLF
	LHLD	TOPPNT		;SET SNIOS TOP AS THE BOTTOM OF NDOS
	SHLD	FREBOT
;
	LXI	H,CNDOS		;NDOS.SPR
	SHLD	PFLNAM
	MOV	B,H
	MOV	C,L
	CALL	BUFPRN
	LHLD	FREBOT		;GET LOADING POINT
	MOV	B,H
	MOV	C,L
	LXI	D,FNDOS		;GET FCB POINT
	CALL	LOAD		;LOAD NDOS.SPR
	SHLD	TOPPNT
	LXI	D,-1
	CALL	SUDEHL		;CHECK LOAD ERROR
	ORA	L
	JNZ	$+6		;NOT ERROR
	JMP	ERROR		;NDOS.SPR LOADING ERROR
;
	LHLD	TOPPNT
	MOV	B,H
	MOV	C,L
	CALL	LOCPR		;PRINT NDOS TOP
	LXI	B,TOPPNT
	LXI	D,FREBOT
	CALL	SUDMBM		;GET LENGTH
	MOV	B,H
	MOV	C,L
	CALL	LOCPR		;PRINT LENGTH
	CALL	CRLF
	LHLD	TOPPNT
	INX	H
	INX	H
	INX	H
	SHLD	PNDOSC		;SAVE NDOS COLD START ROUTINE POINTER
;
	LXI	B,CTPA		;TPA
	CALL	BUFPRN
	LXI	B,TOP
	CALL	LOCPR		;TOP OF TPA
	LHLD	TOPPNT
	MOV	B,H
	MOV	C,L
	CALL	LOCPR		;LENGTH IS NDOS TOP
	CALL	CRLF
	LHLD	PNDOSC
	INX	H
	INX	H
	INX	H
	XCHG
	LXI	B,PUSRID
	CALL	CHKUSC		;CHECK USER ID CODE
	CALL	CRLF
	LXI	B,CLEND
	CALL	BUFPRN		;PRINT LOADING END COMMENT
	CALL	CRLF
if	wiznet
	lda	nverr
	ora	a
	jnz	nonv
	call	netcfg	; HL=network config table
	lxi	d,nvbuf+288	; cfgtbl template area
	call	cpnsetup
nonv:
endif
	CALL	GOTDOS		;TO NDOS OR BREAK
	; NOTREACHED
;
;  ERROR ROUTINE
;
ERROR:
	LXI	SP,PFLNAM
	LXI	B,CLERR
	CALL	BUFPRN		;LOADER ERROR
	LHLD	PFLNAM		;GET ERROR DATA COMMENT POINT
	MOV	B,H
	MOV	C,L
	CALL	BUFPRN		;PRINT ERROR DATA
ERSTOP:
	MVI	A,-1
	RAR
	JNC	ERSTOS
	LXI	H,TOP
	SPHL
	DI
	EI
	HLT
	JMP	ERSTOP
;
ERSTOS:
	EI
	HLT
;
;  CONSOLE OUT
;  INPUT
;   C:DATA
;
CONOT:
	LXI	H,WCONOT
	MOV	M,C
	LHLD	WCONOT
	MVI	H,0
	XCHG
	MVI	C,002H
	CALL	BDOS
	RET
;
;  BUFFER PRINT
;  INPUT
;  BC:STRING POINT
;
BUFPRN:
	LXI	H,WBUFPR+1
	MOV	M,B
	DCX	H
	MOV	M,C		;SAVE PARAMETER
	LHLD	WBUFPR
	XCHG
	MVI	C,CBUFPR
	CALL	BDOS
	RET
;
;  OPEN FILE			NOT USED
;  INPUT
;  BC:FCB POINT
;
	LXI	H,WOPEN+1
	MOV	M,B
	DCX	H
	MOV	M,C
	LHLD	WOPEN
	XCHG
	MVI	C,COPEN
	CALL	BDOS
	RET
;
;  READ SEQUENTIAL		NOT USED
;  INPUT
;  BC:FCB POINT
;
	LXI	H,WREAD+1
	MOV	M,B
	DCX	H
	MOV	M,C
	LHLD	WREAD
	XCHG
	MVI	C,CREAD
	CALL	BDOS
	RET
;
;  SET DMA ADDRESS		NOT USED
;  INPUT
;  BC:DMA ADDRESS
;
	LXI	H,WSRDMA+1
	MOV	M,B
	DCX	H
	MOV	M,C
	LHLD	WSRDMA
	XCHG
	MVI	C,CSTDMA
	CALL	BDOS
	RET
;
;  CARRIAGE RETURN & LINE FEED
;
CRLF:
	MVI	C,CR
	CALL	CONOT
	MVI	C,LF
	CALL	CONOT
	RET
;
;  PRINT NIBBLE BY HEXADECIMAL
;  INPUT
;   C:DATA
;
NIBBLE:
	LXI	H,WNIBLE
	MOV	M,C
	MVI	A,9
	LXI	H,WNIBLE
	CMP	M
	JNC	NIBBLS		;0 TO 9
	LDA	WNIBLE		;A TO F
	ADI	'A'
	SUI	10
	MOV	C,A
	CALL	CONOT
	JMP	NIBBEN
;
NIBBLS:				;0 TO 9
	LDA	WNIBLE
	ADI	'0'
	MOV	C,A
	CALL	CONOT
NIBBEN:
	RET
;
;  PRINT BYTE DATA BY HEXADECIMAL
;  INPUT
;   C:DATA
;
HXPRN:
	LXI	H,WHXPRN
	MOV	M,C
	LDA	WHXPRN
	ANI	0F8H
	RAR
	RAR
	RAR
	RAR
	MOV	C,A
	CALL	NIBBLE		;PRINT HIGHER NIBBLE
	LDA	WHXPRN
	ANI	00FH
	MOV	C,A
	CALL	NIBBLE		;PRINT LOWER NIBBLE
	RET
;
;  PRINT WORD DATA
;  INPUT
;  BC:DATA
;
LOCPR:
	LXI	H,WLOCPR+1
	MOV	M,B
	DCX	H
	MOV	M,C		;SAVE DATA
	MVI	C,' '
	CALL	CONOT
	MVI	C,' '
	CALL	CONOT		;PRINT SPACE
	LHLD	WLOCPR
	MOV	A,H
	MOV	C,A
	CALL	HXPRN		;HIGHER BYTE
	LHLD	WLOCPR
	MOV	A,L
	MOV	C,A
	CALL	HXPRN		;LOWER BYTE
	MVI	C,'H'
	CALL	CONOT
	RET
;
;  CHECK USER ID CODE
;  INPUT
;  DE:NDOS ENTRY
;  BC:ID CODE AREA
;
CHKUSC:
	LXI	H,PNDOS+1
	MOV	M,D
	DCX	H
	MOV	M,E		;SAVE NDOS ENTRY POINT
	DCX	H
	MOV	M,B
	DCX	H
	MOV	M,C		;SAVE ID CODE AREA
CHKUSN:				;ONE DATA POINT LOOP
	MVI	A,0
	RAR
	JNC	CHKUSE		;END (NOT USED)
	LXI	H,CNTLDR
	MVI	M,-1
	INX	H
	MVI	M,-1		;INITIALIZE SEARCH COUNT
CHKUSL:				;CHARACTER CHECK LOOP
	LDA	CNTLDR
	INR	A
	STA	CNTLDR		;LOADER POINTER COUNT UP
	MOV	C,A
	MVI	B,0
	LHLD	PIDCOD		;GET ID CODE AREA
	DAD	B		;GET DATA POINT
	LDA	CNTNDS
	INR	A
	STA	CNTNDS		;NDOS POINTER COUNT UP
	MOV	C,A
	MVI	B,0
	PUSH	H
	LHLD	PNDOS
	DAD	B		;GET NDOS DATA POINT
	POP	B
	LDAX	B
	CMP	M		;COMPARE CODE
	JNZ	$+6		;NOT MATCH
	JMP	CHKUSL		;TO NEXT CHARACTER
;
	MVI	A,23		;CHECK LENGTH  NAME & USER ID TOTAL LENGTH
	LXI	H,CNTLDR
	CMP	M
	JNC	$+4		;NOT OK
	RET			;OK MATCH CODE
;
	MVI	A,0		;CHECK END OF COMPARE
	LXI	D,PNDOS
	CALL	SUDMBY
	ORA	L
	SUI	001H
	SBB	A		;CHECK END OF MEMORY
	XCHG
	PUSH	PSW
	MVI	A,17		;NAME LENGTH -1
	INX	H
	SUB	M
	SBB	A		;CHECK NAME MATCH
	POP	B
	MOV	C,B
	ORA	C
	RAR
	JNC	CHKNXT		;NOT END TO NEXT
	LXI	H,CSYNC		;COMPARE FAIL
	SHLD	PFLNAM		;SYNCHRONIZATION ERROR
	JMP	ERROR
;
CHKNXT:				;CHECK NEXT ADDRESS
	LHLD	PNDOS
	INX	H		;UP START ADDRESS
	SHLD	PNDOS
	JMP	CHKUSN		;CHECK AGAIN
;
CHKUSE:				;END DUMMY
	RET
;
;  BREAK POINT FOR DEBUGGER
;
DEBBP:
	DI			;RESTART INSTRUCTION IS SET HERE
	RET
;
;  GOTO COLD BOOT OF NDOS
;
GOTDOS:
	LXI	H,PNDOSC
	SPHL			;SET STACK TO ENTRY POINT SAVE AREA
	DCX	H
	MOV	A,M
	CPI	'B'
	JNZ	GOTDOE		;NOT BREAK
	LDA	BPNUM		;BREAK, SO GET RESTART NUMBER
	ADD	A
	ADD	A
	ADD	A
	ORI	0C7H		;MAKE RESTART CODE
	LHLD	PDEBBP
	MOV	M,A		;SAVE RESTART CODE
	CALL	DEBBP		;TO BREAK ROUTINE
GOTDOE:				;TO NDOS COLD START ROUTINE
	RET
;
;  LOAD ONE FILE
;  INPUT
;  BC:BOTTOM OF FREE AREA
;  DE:FCB
;  OUTPUT
;  HL:TOP OF PROGRAM  -1 ERROR
;
LOAD:
	MOV	H,B
	MOV	L,C
	SHLD	LDBOTM		;SAVE BOTTOM
	XCHG
	SHLD	LDFCB		;SAVE FCB POINT
	MVI	C,CSTDMA
	LXI	H,-SCTLNG	;SUBTRUCT ONE SECTOR LENGTH
	DAD	D
	SHLD	LDDMA		;SAVE DMA POINT FOR PARAMETER READ
	XCHG
	CALL	BDOS		;SET DMA ADDRESS TO SCRATCH AREA
	LHLD	LDFCB
	XCHG
	MVI	C,COPEN
	CALL	BDOS		;OPEN FILE
	CPI	-1
	MOV	H,A
	MOV	L,A
	RZ			;OPEN ERROR (NOT FOUND)
	CALL	OSREAD		;GET PARAMETER SECTOR
	LHLD	LDDMA
	INX	H
	MOV	E,M
	INX	H
	MOV	D,M		;GET CODE AREA LENGTH
	INX	H
	INX	H
	MOV	C,M
	INX	H
	MOV	B,M		;GET DATA AREA LENGTH
	XCHG
	SHLD	LDLNGT		;SAVE CODE AREA LENGTH
	DAD	B		;GET TOTAL LENGTH
	XCHG
	LHLD	LDBOTM		;GET BOTTOM
	XCHG
	XRA	A
	SUB	L
	MOV	L,A
	MVI	A,0
	SBB	H
	MOV	H,A
	DAD	D		;SUBTRUCT LENGTH FROM BOTTOM POINT
	MVI	L,0		;GET LOADING TOP
	SHLD	LDTOP		;SAVE LOADING TOP (PROGRAM TOP)
	XCHG
	LXI	H,-SCTLNG
	DAD	D		;SUBTRUCT ONE SECTOR LENGTH
	SHLD	LDDMA		;SET RELOCATION DATA BUFFER TOP
	CALL	OSREAD		;GET DATA & IGNORE
	LHLD	LDLNGT
	LXI	D,SCTLNG-1
	DAD	D		;ADJUST BOUNDARY
	MOV	A,L
	RAL
	MOV	A,H
	RAL			;GET SECTOR COUNT OF CODE AREA
	LHLD	LDTOP		;GET LOADING TOP
LOADLP:				;ONE SECTOR LOADING LOOP
	STA	LDCNT		;SAVE COUNT
	SHLD	LDPNT		;SAVE LOADING POINT
	XCHG
	MVI	C,CSTDMA
	CALL	BDOS		;SET DMA ADDRESS
	CALL	OSREAD		;READ ONE SECTOR DATA
	LHLD	LDPNT
	LXI	D,SCTLNG	;ONE SECTOR LENGTH
	DAD	D		;GET NEXT DMA ADDRESS
	LDA	LDCNT
	DCR	A		;SECTOR COUNT DOWN
	JNZ	LOADLP		;TO NEXT SECTOR
	LHLD	LDDMA		;GET BUFFER POINT FOR RELOCATION DATA
	XCHG
	MVI	C,CSTDMA
	CALL	BDOS		;SET TO RELOCATION BUFFER POINT
	LHLD	LDLNGT		;GET LENGTH TO GET RELOCATION DATA TOP
	MOV	B,H
	MOV	C,L
	XCHG
	LHLD	LDTOP		;CODE TOP
	XCHG
	DAD	D		;GET TOP OF RELOCATION DATA
	PUSH	H		;SAVE RELOCATION DATA POINT
	MOV	H,D		;SET RELOCATION BIAS
LOADRL:				;RELOCATION LOOP
	MOV	A,B
	ORA	C
	JNZ	$+8		;NOT TO END
	POP	H		;END OF RELOCATION
	LHLD	LDTOP		;TOP OF PROGRAM
	RET			;END OF LOADING
;
	DCX	B
	MOV	A,E
	ANI	07H
	JNZ	LOADRB		;NOT BYTE BOUNDARY
	XTHL			;BYTE BOUNDARY,  GET DATA POINT
	MOV	A,L
	ANI	07FH
	JNZ	LOADRS		;NOT SECTOR BOUNDARY
	PUSH	B
	PUSH	D
	PUSH	H
	LHLD	LDFCB		;GET FCB POINT
	XCHG
	MVI	C,CREAD
	CALL	BDOS		;GET ONE SECTOR DATA
	POP	H
	POP	D
	POP	B
	LHLD	LDDMA		;GET DATA TOP POINT
	ORA	A
	JNZ	OSRDER		;NO DATA, SO ERROR
LOADRS:
	MOV	A,M		;GET NEXT RELOCATION DATA
	INX	H
	XTHL
	MOV	L,A
LOADRB:
	MOV	A,L
	RAL			;GET ONE BIT DATA
	MOV	L,A
	JNC	$+6		;NOT RELOCATE
	LDAX	D		;RELOCATE
	ADD	H
	STAX	D
	INX	D
	JMP	LOADRL		;TO NEXT DATA
;
;  READ ONE SECTOR DATA
;
OSREAD:
	LHLD	LDFCB		;GET FCB
	XCHG
	MVI	C,CREAD
	CALL	BDOS		;READ ONE SECTOR
	ORA	A
	RZ			;NOT ERROR
OSRDER:				;NO DATA, SO ERROR
	POP	H		;OVERRIDING RETURN
	LXI	H,-1
	RET
;
;  LOADING ROUTINE WORKING
;
LDDMA:	DS	2		;DMA ADDRESS
LDLNGT:	DS	2		;CODE AREA LENGTH
LDFCB:	DS	2		;FCB POINTER
LDBOTM:	DS	2		;BOTTOM POINT OF FREE AREA
LDTOP:	DS	2		;TOP POINT OF PROGRAM
LDCNT:	DS	1		;LOAD SECTOR COUNT
LDPNT:	DS	2		;LOADING POINTER
;
;  AND ROUTINES
;  HL=HL AND A
;  HL=HL AND DE
;
	MOV	E,A
	MVI	D,0
ANHLDE:
	MOV	A,E
	ANA	L
	MOV	L,A
	MOV	A,D
	ANA	H
	MOV	H,A
	RET
;
;  HL=(DE) AND A
;  HL=(HL) AND DE
;
	XCHG
	MOV	E,A
	MVI	D,0
ANHMDE:
	XCHG
	LDAX	D
	ANA	L
	MOV	L,A
	INX	D
	LDAX	D
	ANA	H
	MOV	H,A
	RET
;
;  SUBTRUCT ROUTINES
;  HL=A - HL
;  HL=DE - HL
;
SUBYHL:
	MOV	E,A
	MVI	D,0
SUDEHL:
	MOV	A,E
	SUB	L
	MOV	L,A
	MOV	A,D
	SBB	H
	MOV	H,A
	RET
;
;  HL=(DE) - (BC)
;
SUDMBM:
	MOV	L,C
	MOV	H,B
	MOV	C,M
	INX	H
	MOV	B,M
	LDAX	D
	SUB	C
	MOV	L,A
	INX	D
	LDAX	D
	SBB	B
	MOV	H,A
	RET
;
;  HL=(DE) - A
;
SUDMBY:
	MOV	L,A
	MVI	H,000H
	LDAX	D
	SUB	L
	MOV	L,A
	INX	D
	LDAX	D
	SBB	H
	MOV	H,A
	RET
;
;  HL=A - (HL)
;  HL=DE - (HL)
;
	MOV	E,A
	MVI	D,000H
SUDEHM:
	MOV	A,E
	SUB	M
	MOV	E,A
	MOV	A,D
	INX	H
	SBB	M
	MOV	D,A
	XCHG
	RET

if	wiznet
nocfg:	mvi	a,1
	sta	nverr
	lxi	d,ncfg
	mvi	c,CBUFPR
	jmp	bdos

netcfg:
	lhld	sniose
	lxi	d,6
	dad	d
	pchl
endif

	dseg
;
;  WORKING
;
PFLNAM:	DW	CDSKER		;LOAD ERROR COMMENT POINTER
WCONOT:	DB	0		;WORK FOR CONSOLE OUT
WBUFPR:	DW	0		;WORK FOR BUFFER PRINT
WOPEN:	DW	0		;WORK FOR OPEN FILE
WREAD:	DW	0		;WORK FOR READ SEQUENTIAL
WSRDMA:	DW	0		;WORK FOR SET DMA
WNIBLE:	DB	0		;NIBBLE OUT WORKING
WHXPRN:	DB	0		;HEXA PRINT WORKING
WLOCPR:	DW	0		;WORK FOR WORD PRINT
;
;  FOR ID CODE CHECK
;
PIDCOD:	DW	0
PNDOS:	DW	0
CNTLDR:	DB	0
CNTNDS:	DB	0
;

if	wiznet
ncfg:	db	'NVRAM not configured',cr,lf,'$'
nverr:	db	0
endif
;
	DS	60		;STACK AREA
STACK:
;
BDOSPT:	DW	BDOS+1		;POINTER DATA FOR DOS
	DW	0
FREBOT:	DW	0
TOPPNT:	DW	0
;
	DS	9
;
;  LOADING FILE FCB
;
FNDOS:				;FOR NDOS.SPR
	DB	0,'NDOS    SPR'
	DB	0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
FSNIOS:				;FOR SNIOS.SPR
	DB	0,'SNIOS   SPR'
	DB	0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
;
FDEBUG:	DS	1
PNDOSC:	DS	2	; NDOS cold start entry
sniose:	ds	2	; SNIOS entry base

nvbuf:	ds	512

;
	END
