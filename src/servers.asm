; Reconstruction of SERVER.RSP for the CP/NET Server.
; Contains code optimizations (macros) that cause a slight
; variation in one code sequence, compared to original SERVER.RSP.
;
; Allow for mini R/O vector in low 4 bits of compatability attributes
; (process descriptor + 29). This requires XIOS support, to check and
; enforce (WRITE returns "2").
; This also requires that the temporary drive not be a protected drive,
; or else spooling may not work.
; By default, drive A: is protected (RESNTSRV.ASM).
	maclib	config
	maclib	cfgnwif

	public	pinit,srvlgo
	extrn	bdos,cfgadr,nlock,nunlock,nwq0p
	extrn	bffree,rqfree
	extrn	NTWKIN,NTWKST,SNDMSG,RCVMSG,NWPOLL,NTWKER,NTWKDN,NWLOGO

SRVNUM	macro	?o
	lxi	h,@srvno+?o
	dad	sp
	mov	a,m
	adi	90h
	daa
	aci	40h
	daa
	endm

cpm	equ	0

; CP/M FCB
F$NAM	equ	1	; FILENAME
F$TYP	equ	9	; TYP
F$EXT	equ	12	; extent
F$RC	equ	15	; rec cnt
F$CR	equ	32	; current record
F$RREC	equ	33	; random record
F$LEN	equ	36	; FCB length

; CP/M DIRENT
D$LEN	equ	32	; DIRENT length

; Each SERVRxPR process keeps it's local data on it's stack.
; A template of that data is shown between '?base' and 'stack0'.
;
; References to stack data must take into account the current
; stack depth. Each push/pop must be accounted for to compute
; the correct offset to use when referencing stack variables.

	cseg
	db	'COPYRIGHT (C) 1982, DIGITAL RESEARCH '
	db	0,0,0,0,0,0	; serial number

stacks:
	db	0c7h,0c7h,0c7h,0c7h
	db	0c7h,0c7h,0c7h,0c7h,0c7h,0c7h,0c7h,0c7h,0c7h,0c7h,0c7h,0c7h
	db	0c7h,0c7h,0c7h,0c7h,0c7h,0c7h,0c7h,0c7h,0c7h,0c7h,0c7h,0c7h
	db	0c7h,0c7h,0c7h,0c7h,0c7h,0c7h,0c7h,0c7h,0c7h,0c7h
istk:	ds	0	; main stack
	dw	$-$	; not used
	; data area for process... template for extra procs.
?base:	; "local" process variables, on stack
?srvno:	db	0	; server process ID, 0..F
?usrno:	db	0	; user number
?drvno:	db	0	; current drive number
?spact:	db	0	; LST: spool file active/dirty

	; Search params, saved from other process activity
?srchp:	dw	0	; PROC.DCNT
	db	0	; PROC.SEARCHL
	dw	0	; PROC.SEARCHA

?procd:	dw	0	; our process descriptor
?msgqi:	dw	0	; pointer to CP/NET msgbuf
	; search first/next pattern buffer, 15 bytes
?srcha:	db	0,0,0,0,0,0,0,0,0,0,0,0,0,0,0

	; command/msg buffer for spooler queue:
	; (D)(L)FILENAME.TEX[D(cr)(nul) [18 chars]
?spcmd:	db	0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0

	; UQCB for spooler, w/o NAME field (pre-fab, not opened)
?uqcbs:	dw	0,0	; UQCB POINTER, MSGADR

	; FCB for spool file
?spfcb:	db	0, 0,0,0,0,0,0,0,0, 0,0,0, 0,0,0,0
	db	0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
	db	0,0,0,0

	; UQCB for messages from NetWrkIF
?uqcbi:	db	0,0,0,0,0,0,0,0,0,0,0,0
	; UQCB for messages to NetWrkIF
?uqcbo:	db	0,0,0,0,0,0,0,0,0,0,0,0	; not used
stack0:	ds	0

@init	equ	stack0-?base-2
@srvno	equ	?srvno-?base
@usrno	equ	?usrno-?base
@drvno	equ	?drvno-?base
@spact	equ	?spact-?base
@srchp	equ	?srchp-?base
@procd	equ	?procd-?base
@srcha	equ	?srcha-?base
@spcmd	equ	?spcmd-?base
@uqcbs	equ	?uqcbs-?base
@spfcb	equ	?spfcb-?base
@msgqi	equ	?msgqi-?base
@uqcbi	equ	?uqcbi-?base
@uqcbo	equ	?uqcbo-?base	; not used

	; the rest...
	ds	(nmb$rqstrs-1)*srvr$stk$len

srvr0pd: dw	$-$

; Template for network message queue (input)
qtmplt:	db	'NtwrkQIx'	; 'x' replaced by 0..F, also 'O' for "NtwrkQOx"

maxcon:	db	0	; max num requesters allowed (logged in)
spoolf:	db	0	; flag to indicate spoolq is valid

; command tail used for spooling a file
texcmd:	db	'.TEX[D',0dh,0

spoolfcb:	; template spool file FCB (not actually used here)
tmpdrv:	db	1,'xxSPOOLF','TEX',0,0,0,0
	db	0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
	db	0,0,0,0

; UQCB for the spooler, in present.
spoolq:	dw	0,0
	db	'SPOOLQ  '

; Masks for drives A-P
drvmsk:	dw	1111111111111110b	; A:
	dw	1111111111111101b	; B:
	dw	1111111111111011b	; C:
	dw	1111111111110111b	; D:
	dw	1111111111101111b	; E:
	dw	1111111111011111b	; F:
	dw	1111111110111111b	; G:
	dw	1111111101111111b	; H:
	dw	1111111011111111b	; I:
	dw	1111110111111111b	; J:
	dw	1111101111111111b	; K:
	dw	1111011111111111b	; L:
	dw	1110111111111111b	; M:
	dw	1101111111111111b	; N:
	dw	1011111111111111b	; O:
	dw	0111111111111111b	; P:

	; what is this for? (64 bytes)
	dw	0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
	dw	0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0

; FNC handler op codes...
fnctab:	db	0	; 00
	db	0	; 01 - conin
	db	0	; 02 - conout
	db	1	; 03 - auxin
	db	2	; 04 - auxout
	db	3	; 05 - lstout
	db	0	; 06 - direct con I/O
	db	0	; 07 - auxst
	db	0	; 08 - auxost
	db	0	; 09 - print
	db	0	; 10 - line input
	db	4	; 11 - const
	db	0	; 12 - get version
	db	0	; 13 - reset
	db	5	; 14 - seldsk
	db	16	; 15 - open
	db	16	; 16 - close
	db	8	; 17 - search first
	db	8	; 18 - search next
	db	7	; 19 - delete
	db	16	; 20 - read seq
	db	16	; 21 - write seq
	db	16	; 22 - make
	db	7	; 23 - rename
	db	9	; 24 - get login vector
	db	0	; 25 - get cur dsk
	db	0	; 26 - set dma adr
	db	11	; 27 - get addr (alloc)
	db	5	; 28 - write-prot disk
	db	9	; 29 - get R/O vector
	db	7	; 30 - set file attrs
	db	11	; 31 - get addr (DPB)
	db	0	; 32 - set/get user num
	db	16	; 33 - read rand
	db	16	; 34 - write rand
	db	16	; 35 - comp file size
	db	16	; 36 - set rand rec
	db	5	; 37 - reset drive(s) (vector)
	db	5	; 38 - access drive(s) (vector)
	db	5	; 39 - free drive(s) (vector)
	db	16	; 40 - write rand w/zero
	db	0	; 41 - test and write record
	db	16	; 42 - lock record
	db	16	; 43 - unlock record
	db	0	; 44 - set multi-sec count
	db	0	; 45 - set bdos err mode
	db	0	; 46 - get disk free space
	db	0	; 47 - chain to program
	db	0	; 48 - flush buffers
	db	0	; 49 - get/set SCB
	db	0	; 50 = 100 (BIOS calls)  Set DIR label
	db	0	; 51 = 101 - Get DIR label
	db	0	; 52 = 102 - Get File date/pwd mode
	db	0	; 53 = 103 - Write file XFCB
	db	0	; 54 = 104 - Set Time/Date
	db	0	; 55 = 105 - Get Time/Date
	db	12	; 56 = 106 - Set Default Password
	db	0	; 57 = 107 - Get serial number
	db	0	; 58 = 108 - Get/Set program return code
	db	0	; 59 = 109 (load overlay) Get/Set console mode
	db	0	; 60 = 110 (call RSX) Get/Set output delimiter
	db	0	; 61 = 111 - Print block (to CON:) 
	db	0	; 62 = 112 - Print block (to LST:)
	db	0	; 63
	db	13	; 64 - LOGIN
	db	14	; 65 - LOGOUT
	db	0	; 66
	db	0	; 67
	db	0	; 68
	db	0	; 69
	db	15	; 70 - Set Compatibility Attributes
	db	6	; 71 - Get Server Config
	db	0	; 72
	db	0	; 73
	db	0	; 74

; Function op code routines
fncptr:	dw	neterr	; 0
	dw	conout	; 1 - CON: output direct
	dw	lstout	; 2 - LST: output direct (AUX:)
	dw	lstspo	; 3 - LST: output to spooler
	dw	conin	; 4 - CON: input direct
	dw	seldsk	; 5 - select disk
	dw	getcfg	; 6 - get srv cfg
	dw	smpfcb	; 7 - delete,rename,set-attr
	dw	search	; 8 - search first/next
	dw	drvvec	; 9 - get drive vectors
	dw	netnul	; 10 - not used
	dw	getadr	; 11 - get DPB/ALV
	dw	defpwd	; 12 - set def pwd
	dw	login	; 13 - login requester
	dw	logout	; 14 - logout requester
	dw	cmpatr	; 15 - set compat attr
	dw	stdfcb	; 16 - std FCB functions

; 16-bit bit-wise AND of DE with (HL)
; Returns DE=result, HL incremented once, A=D
andM:	mov	a,m
	ana	e
	mov	e,a
	inx	h
	mov	a,m
	ana	d
	mov	d,a
	ret

; Check if NID is logged in
; C=NID
; Returns 0ffh if not, A=index in table otherwise
chklog:	lxi	d,00001h
	mvi	b,-1
chk0:	inr	b
	lhld	cfgadr
	inx	h
	inx	h
	mov	a,m
	sub	b
	jnz	chk1
	dcr	a	; 0ffh
	ret

chk1:	inx	h
	inx	h
	push	d
	call	andM
	ora	e
	pop	d
	jz	chk2
	inx	h
	push	d
	mov	e,b
	mvi	d,0
	dad	d
	pop	d
	mov	a,m
	cmp	c
	jnz	chk2
	mov	a,b	; success: we are logged in
	ret

chk2:	xchg
	dad	h
	xchg
	jmp	chk0

; Validate the CP/NET request
; BC=msgbuf
; Returns 0ffh if error
valid:	mov	d,b
	mov	e,c
	inx	d		; DID == us?
	ldax	d
	lhld	cfgadr
	inx	h
	cmp	m
	jz	val0
	mvi	a,0ffh		; error if server ID wrong
	ret

val0:	xchg
	inx	h	; SID
	inx	h	; FNC
	mov	a,m
	sui	loginf	; LOGIN
	rz		;
	mov	a,m
	cpi	100
	jc	val1
	sui	50
	mov	m,a	; fold 100.. => 50..
val1:	push	h
	dcx	h
	mov	c,m	; SID
	call	chklog
	pop	h
	inr	a
	jnz	val2
	mvi	a,0ffh	; error, not logged in
	ret

val2:	mov	a,m
	cpi	netend	; valid FNC range?
	jnc	val3
	xra	a
	ret

val3:	mvi	a,0ffh
	ret

; copy B bytes from DE to HL
moveb:	ldax	d
	mov	m,a
	inx	h
	inx	d
	dcr	b
	jnz	moveb
	ret

; multiply B * DE
; Returns DE=result
multDE:	mov	a,b
	mvi	b,8
	lxi	h,0
mult0:	rar
	jnc	mult1
	dad	d
mult1:	xchg
	dad	h
	xchg
	dcr	b
	jnz	mult0
	xchg
	ret

; Perform a BIOS call...
; C=BIOS vector page address (00=warm boot)
; A=value for C (param) in call to BIOS
; HL=location of device number
; This is a bit convoluted for MP/M, and may
; have dependencies on specific BIOS/XIOS implementations.
biosv:	mov	h,m	; pick up value for D (dev num)
	xchg		; D=device number
	lhld	cpm+1	; address of "direct BIOS jump vectors" #0
	inx	h
	inx	h
	mov	h,m	; page for jump vectors?
	mov	l,c	; offset in page for routine
	mov	c,a	; param (for output)
	pchl

; Set user number in OS
; stack depth +2 for call... already +2
setusr:	lxi	h,@usrno+2+2
	dad	sp
	cmp	m
	rz
	mov	m,a
	mov	e,a
	mvi	c,userf
	jmp	bdos

; Set current drive in OS
; stack depth +2 for call... already +2
seldrv:	lxi	h,@drvno+2+2
	dad	sp
	cmp	m
	rz
	mov	m,a
	mov	e,a
	mvi	c,drivef
	jmp	bdos

; setup return code or error.
; A=ret code or 0ffh for error, D=error code
; Returns CY for error cases.
setret:	mov	m,a
	inr	a
	ora	a
	rnz
	ora	d
	rz
	inr	a
	ora	a
	rz
	inx	h
	mov	m,d
	dcx	h
	dcx	h
	mvi	m,2-1
	stc
	ret

; Open a queue, wait until success
openq:	dad	sp
	xchg
opq0:	push	d
	mvi	c,openqf
	call	bdos
	ora	a
	pop	d
	rz
	push	d
	lxi	d,1
	mvi	c,delayf
	call	bdos
	pop	d
	jmp	opq0

; Perform CP/NET server loop.
; C=srv num
; does not return.
cpnet:	lxi	h,-@init
	dad	sp	;
	sphl		; reserve space on stack
	push	b	; save C=id num of server process, 0..F
	; baseline stack depth, +0
	mvi	c,getpdf
	call	bdos
	xchg		; DE = our proc descr
	lxi	h,@procd+0
	dad	sp	; HL=?procd
	mov	m,e	;
	inx	h
	mov	m,d	; ?procd=our-proc-desc
	inx	h
	xchg		; DE=?msgqi, HL=pdadr
	push	d	; off=2
	lxi	d,P$ATTR
	dad	d
	mvi	m,def$prot
	pop	d	; off=0
	lxi	h,@uqcbi+Q$MSG+0
	dad	sp	; HL=?uqcbi.MSGADR
	mov	m,e
	inx	h
	mov	m,d	; ?uqcbi.MSGADR = ?msgqi
	inx	h	; HL=?uqcbi.NAME
	push	d	; off=2 (save ?msgqi)
	lxi	d,qtmplt
	push	d	; off=4
	mvi	b,7
	call	moveb	; ?uqcbi.NAME = "NtwrkQI"
	xchg		; DE=?uqcbi.NAME[7]
	SRVNUM	4
	stax	d	; set 'x' in "NtwrkQIx"
	lxi	h,@uqcbi+4+2	; our private queue, (+2 for call)
	call	openq
	pop	d	; off=2 (DE=qtmplt)
	pop	b	; off=0 (BC=?msgqi)
	mvi	c,userf
	mvi	e,0ffh
	call	bdos
	lxi	h,@usrno+0
	dad	sp
	mov	m,a	; save current user num
	lxi	h,@spact+0
	dad	sp
	mvi	m,0
	lda	spoolf
	rar
	jnc	ntloop
	; we have a spoolq...
	lhld	spoolq
	xchg		; DE=spoolq
	lxi	h,@uqcbs+0
	dad	sp	; HL=?uqcbs (spooler msg queue)
	mov	m,e
	inx	h
	mov	m,d	; ?uqcbs.POINTER = spoolq
	inx	h
	xchg		; DE=?uqcbs.MSGADR
	lxi	h,@spcmd+0
	dad	sp
	xchg		; DE=?spcmd (spooler msg buffer)
	mov	m,e
	inx	h
	mov	m,d	; ?uqcbs.MSGADR = ?spcmd
; wait for CP/NET message...
; This is the main CP/NET Server loop
ntloop:	lxi	h,@uqcbi+0
	dad	sp	; HL=?uqcbi (network input queue)
	xchg
	mvi	c,readqf
	call	bdos
	lxi	h,@msgqi+0
	dad	sp	; HL=?msgqi (input msg buffer)
	mov	c,m
	inx	h
	mov	b,m	; BC=ptr to CP/NET MSG buffer
	push	b	; off=2
	call	valid
	rar
	jnc	net0
	pop	h	; off=0
	; set CP/NET server error code 12...
	inx	h
	inx	h
	inx	h
	inx	h
	mvi	m,2-1
	inx	h
	mvi	m,0ffh
	inx	h
	mvi	m,00ch
	jmp	sndbak

; CP/NET message looks OK - proceed to execute request
net0:	pop	h	; off=0
	push	h	; off=2 (HL=MSGBUF)
	inx	h
	inx	h
	inx	h
	mov	c,m	; FNC
	mvi	b,0
	lxi	h,fnctab
	dad	b
	mov	c,m	; op code
	lxi	h,fncptr
	dad	b
	dad	b
	mov	e,m
	inx	h
	mov	d,m
	xchg		; HL=op code handler routine
	pchl		; (off=2) execute handler

; Generic "not implemented" CP/NET error (or "not logged in")
neterr:	pop	h	; off=0
	inx	h
	inx	h
	inx	h
	inx	h
	mvi	m,2-1
	inx	h
	mvi	m,0ffh
	inx	h
	mvi	m,00ch
	jmp	sndbak

; Console output via BIOS
conout:	pop	h	; off=0 (HL=MSGBUF)
	lxi	b,DAT
	dad	b
	push	h	; MSGBUF.DAT
	mvi	c,3*3	; conout BIOS vector
	call	biosv
	pop	h
	mov	m,a
	jmp	sndbak

; List output via BIOS
lstout:	pop	h	; off=0
	lxi	b,DAT+1
	dad	b
	mov	a,m
	mvi	c,4*3	; lstout BIOS vector
	dcx	h
	dcx	h
	dcr	m
	inx	h
	call	biosv
	jmp	sndbak

; LST: output to spooler
; Create a unique temporary file...
lstspo:	mvi	a,0	; (off=2)
	call	setusr
	lxi	h,@spact+2
	dad	sp
	mov	a,m
	rar
	jc	sp3
	mvi	m,0ffh
	lda	spoolf
	rar
	jnc	sp2
	lxi	d,spoolfcb
	lxi	h,@spfcb+2
	dad	sp
	push	h	; off=4
	mvi	b,F$LEN
	call	moveb
	SRVNUM	4	; get srvno as hex digit
	pop	h	; off=2 (HL=?spfcb)
	pop	d	; off=0 (DE=MSGBUF)
	push	d	; off=2
	push	h	; off=4
	inx	h
	mov	m,a	; set 'x'
	inx	h
	mvi	m,'0'
	lxi	h,TMP	; safe space, during searchf/nextf functions
	dad	d
	xchg
	mvi	c,dmaf
	call	bdos
sp0:	pop	d	; off=2 (DE=?spfcb)
	push	d	; off=4
	mvi	c,searchf
	call	bdos
	inr	a
	jz	sp1
	pop	h	; off=2 (HL=?spfcb)
	push	h	; off=4
	inx	h
	inx	h
	inr	m
	jmp	sp0

sp1:	pop	d
	mvi	c,makef
	call	bdos
	jmp	sp3

sp2:	pop	h	; off=0 (HL=MSGBUF)
	push	h	; off=2
	lxi	d,DAT
	dad	d
	mov	e,m	; DAT[0] = LST: number
	mvi	c,setlstf
	call	bdos
	mvi	c,attlstf
	call	bdos
sp3:	lda	spoolf
	rar
	jnc	sp6
	pop	h	; off=0 (HL=MSGBUF)
	lxi	d,DAT+1
	dad	d	; DAT[1]... chars for printer
	push	h	; off=2
	xchg
	mvi	c,dmaf	; data for spool file - incl. EOF or full 128 bytes
	call	bdos
	pop	h	; off=0 (HL=DAT[1])
	dcx	h
	dcx	h	; SIZ
	push	h	; off=2 (save MSGBUF.SIZ)
	mov	a,m
	mvi	m,1-1	; return msg 1 byte
	inr	a
	add	l
	mov	l,a
	mov	a,h
	aci	0
	mov	h,a	; HL=DAT[SIZ]
	mov	a,m
	inr	a	; is 0FFH?
	push	psw	; off=4
	jnz	sp4
	mvi	m,eof	; if 0FFH, replace with ^Z EOF
sp4:	lxi	h,@spfcb+4
	dad	sp
	push	h	; off=6
	xchg
	mvi	c,wrndf
	call	bdos
	pop	d	; off=4 (DE=?spfcb)
	lxi	h,F$RREC	; point to rand record in fcb
	dad	d
	inr	m	; increment rand record
	jnz	sp5	;
	inx	h	;
	inr	m	;
	jnz	sp5	;
	inx	h	;
	inr	m	;
sp5:	pop	psw	; off=2 (0FFH seen)
	pop	h	; off=0 (HL=MSGBUF.SIZ)
	jnz	sndbak	; leave LST: open if no EOF
	push	h	; off=2
	lxi	h,@procd+2
	dad	sp	; HL=?procd
	mov	c,m
	inx	h
	mov	b,m	; BC=proc desc
	lxi	h,P$ATTR
	dad	b
	mov	a,m
	push	h	; off=4
	push	psw	; off=6
	mvi	m,0	; set compat attrs to "0", temporarily
	mvi	c,closef ; close spool file
	call	bdos
	pop	psw	; off=4 (A=PD ext val)
	pop	h	; off=2 (HL=PD extent)
	mov	m,a	; restore normal compat attrs
	lda	tmpdrv
	dcr	a
	add	a
	add	a
	add	a
	add	a
	mov	b,a	; B = DDDD0000b
	pop	h	; off=0 (HL=MSGBUF.SIZ)
	inx	h
	mov	a,m	; DAT[0] = LST: number
	add	a
	add	a
	add	a
	add	a	; A = LLLL0000b
	lxi	h,@spcmd+0	; spooler command buffer?
	dad	sp
	mov	m,b	; drive code
	inx	h
	mov	m,a	; lst: num code
	inx	h
	xchg
	lxi	h,@spfcb+0
	dad	sp
	xchg
	inx	d	; point to filename
	mvi	b,8
	call	moveb	; copy base name
	lxi	d,texcmd
	mvi	b,8
	call	moveb	; append rest of command
	lxi	h,@uqcbs+0
	dad	sp
	xchg
	mvi	c,writqf
	call	bdos	; send spool command to spooler
	jmp	sp9

; No spooler, output directly to LST:
sp6:	pop	h	; off=0 (HL=MSGBUF)
	inx	h
	inx	h
	inx	h
	inx	h
	mvi	m,1-1	; response SIZ is 1 byte
	inx	h
	inx	h	; DAT[1] = first LST: char
	mvi	b,128
sp7:	mov	e,m
	mov	a,e
	inr	a	; is 0FFH?
	jz	sp8
	push	h	; off=2
	push	b	; off=4
	mvi	c,listf
	call	bdos	; send one char to LST:
	pop	b	; off=2
	pop	h	; off=0
	inx	h
	dcr	b
	jnz	sp7
	jmp	sndbak	; all done, no detach

; (off=0) End of LST: "job"
sp8:	mvi	c,detlstf
	call	bdos
sp9:	lxi	h,@spact+0
	dad	sp
	mvi	m,0	; LST: not active
	jmp	sndbak

; Console input via BIOS
conin:	pop	h
	lxi	d,DAT
	dad	d
	push	h
	mvi	c,2*3	; conin BIOS vector
	call	biosv
	pop	h
	mov	m,a
	jmp	sndbak

; functions with drive vectors
seldsk:	pop	h	; off=0 (HL=MSGBUF)
	inx	h
	inx	h
	inx	h
	mov	a,m	; FNC
	cpi	freef
	jnz	sel0
	; Func 39 - Free Drive
	xchg
	lda	spoolf
	lxi	h,@spact+0
	dad	sp
	ana	m	; spool-avail .AND. spool-active
	rar
	push	psw	; off=2
	xchg
	jnc	sel1	; continue with normal processing
	pop	psw	; off=0 (A=spool flag)
	push	h	; off=2
	xra	a
	call	setusr	; force user 0
	pop	h	; off=0 (HL=MSGBUF.FNC)
	stc
	push	psw	; off=2
	push	h	; off=4
	mvi	c,closef
	lxi	h,@spfcb+4
	dad	sp
	xchg
	call	bdos	; close spool file
	pop	h	; off=2 (HL=MSGBUF.FNC)
	jmp	sel1	; continue with normal processing

sel0:	ora	a	; NC = no spool
	push	psw	; off=2
	cpi	wprotf
	jnz	sel1	; continue with normal processing
	; Func 28 - Write Protect Drive
	push	h	; off=4
	inx	h
	inx	h	; DAT[0]
	mov	a,m
	call	seldrv
	pop	h	; off=2 (HL=MSGBUF.FNC)
; common code using drive vector - call function...
sel1:	mov	c,m	; FNC
	inx	h
	mvi	m,1-1	; response SIZ is 1 byte
	inx	h
	mov	e,m	; DE=param
	push	h	; off=4
	inx	h
	mov	d,m
	call	bdos	; perform function
	xchg		; DE=return value
	pop	h	; off=2 (HL=MSGBUF.DAT[0])
	call	setret
	pop	psw	; off=0 (CY=spool flag)
	jnc	sndbak	; done if no spooler
	mvi	c,openf
	lxi	h,@spfcb
	dad	sp
	xchg
	call	bdos	; re-open spool file
	jmp	sndbak

; Get Server Config
getcfg:	pop	h	; off=0 (HL=MSGBUF)
	inx	h
	inx	h
	inx	h
	inx	h
	mvi	m,G$LEN+1-1	; srv cfg tbl resp SIZ is 23 bytes
	inx	h
	xchg
	lda	tmpdrv
	dcr	a
	stax	d	; TMP drive (not in srv cfg tbl)
	inx	d
	lhld	cfgadr	; plus rest of internal config table
	xchg
	mvi	b,G$LEN
	call	moveb
	jmp	sndbak

; simple  FCB funcs: delete,rename,set-attrs
smpfcb:	pop	h	; off=0 (HL=MSGBUF)
	lxi	d,DAT
	dad	d	; HL=MSGBUF.DAT
	push	h	; off=2
	mov	a,m
	call	setusr
	pop	h	; off=0 (HL=MSGBUF.DAT)
	push	h	; off=2
	mov	d,h
	mov	e,l
	inx	d	; DE=FCB
	dcx	h	;
	mvi	m,1-1	; response SIZ?
	dcx	h
	mov	c,m	; FNC
	call	bdos	; execute function
	xchg		; DE=return code
	pop	h	; off=0 (HL=MSGBUF.DAT)
	call	setret
	jmp	sndbak

; search first/next (return is DIRENT)
search:	pop	h	; off=0 (HL=MSGBUF)
	lxi	d,DAT+1
	dad	d	; HL=MSGBUF.DAT[1]
	push	h	; off=2
	mov	a,m
	call	setusr
	pop	d	; off=0 (HL=MSGBUF.DAT[1])
	push	d	; off=2
	mvi	c,dmaf
	call	bdos	; set DMA in MSGBUF for DIRENT
	pop	h	; off=0 (HL=MSGBUF.DAT[1])
	push	h	; off=2
	dcx	h
	dcx	h
	mvi	m,1-1	; resp SIZ is 1 byte
	dcx	h
	mov	a,m	; FNC
	cpi	searchf
	jnz	srch1
	; search first - initialize
	pop	h	; off=0 (HL=MSGBUF.DAT[1])
	push	h	; off=2
	inx	h
	mov	a,m	; FCB drive byte
	cpi	'?'	; special "everything" search
	jnz	srch0
	dcx	h
	dcx	h
	mov	a,m	; MSGBUF.DAT[0]
	call	seldrv
srch0:	pop	d	; off=0 (DE=MSGBUF.DAT[1])
	push	d	; off=2
	inx	d
	lxi	h,@srcha+2
	dad	sp
	mvi	b,15
	call	moveb
	jmp	srch2

srch1:	lxi	h,@srchp+2
	dad	sp
	mov	c,m
	inx	h
	mov	b,m
	push	b	; off=4
	dcx	h
	xchg		; DE=?srchp
	lxi	h,@procd+4
	dad	sp
	mov	c,m
	inx	h
	mov	b,m
	lxi	h,P$DCNT
	dad	b	; HL=PROC.DCNT (SEARCHL, SEARCHA)
	push	h	; off=6
	mvi	b,5
	call	moveb	; restore PROC DCNT,SEARCHL,SEARCHA
	pop	h	; off=4 (HL=PROC.DCNT)
	pop	d	; off=2 (DE=prev DCNT)
	mov	a,e
	ani	003h
	cpi	003h	; last in record?
	jz	srch2
	; already have dirent, just return it
	push	d	; off=4
	push	h	; off=6
	mov	a,e
	sui	4
	mov	e,a
	mov	a,d
	sbi	0
	mov	d,a	; DCNT -= 4
	mov	a,e
	ori	003h	; set PROC.DCNT to end of previous record
	mov	m,a
	inx	h
	mov	m,d
	mvi	c,nextf
	call	bdos	; search next
	pop	h	; off=4 (HL=PROC.DCNT)
	pop	d	; off=2 (DE=prev DCNT
	mov	m,e
	inx	h
	mov	m,d	; restore PROC.DCNT
srch2:	lxi	h,@srcha+2
	dad	sp
	xchg
	pop	h	; off=0 (HL=MSGBUF.DAT[1])
	dcx	h
	push	h	; off=2
	dcx	h
	dcx	h
	mov	c,m	; FNC
	call	bdos
	xchg
	mov	b,a
	pop	h	; off=0 (HL=MSGBUF.DAT[0])
	call	setret
	jc	sndbak
	mov	a,b
	cpi	0ffh
	jz	sndbak
	push	h	; off=2
	dcx	h
	mvi	m,D$LEN+1-1	; response SIZ is 33
	ani	003h
	mov	b,a
	lxi	d,D$LEN
	call	multDE	; index into DMA buf
	xchg
	pop	d	; off=0 (DE=MSGBUF.DAT)
	inx	d
	dad	d
	xchg
	mvi	b,D$LEN
	call	moveb	; move DIRENT into MSGBUF
	lxi	h,@procd+0
	dad	sp
	mov	e,m
	inx	h
	mov	d,m
	lxi	h,P$DCNT
	dad	d
	xchg
	lxi	h,@srchp+0
	dad	sp
	mvi	b,5
	call	moveb	; save PROC.DCNT,SEARCHL,SEARCHA
	jmp	sndbak

; functions that return drive vector (get login,R/O)
drvvec:	pop	h	; off=0 (HL=MSGBUF)
	inx	h
	inx	h
	inx	h
	mov	c,m	; FNC
	inx	h
	mvi	m,2-1	; response SIZ is 2
	push	h	; off=2
	call	bdos
	xchg
	pop	h	; off=0 (HL=MSGBUF.SIZ
	inx	h
	mov	m,e	; MSGBUF.DAT[0]
	inx	h
	mov	m,d	; MSGBUF.DAT[1]
	jmp	sndbak

; functions that do nothing at all (not used)
netnul:	pop	h	; off=0
	jmp	sndbak

; misc small buffer return: get DPB/ALV
getadr:	pop	h	; off=0 (HL=MSGBUF)
	inx	h
	inx	h
	inx	h
	mov	a,m	; FNC
	inx	h
	cpi	getalvf
	jz	geta0
	mvi	m,16-1	; DPB resp SIZ is 16 bytes
	jmp	geta1
geta0:	mvi	m,256-1	; ALV resp is max (256 bytes)
geta1:	push	h	; off=2
	inx	h
	mov	a,m
	call	seldrv
	pop	h	; off=0 (HL=MSGBUF.SIZ)
	push	h	; off=2
	dcx	h
	mov	c,m	; FNC
	call	bdos
	xchg		; DE=addr
	pop	h	; off=0 (HL=MSGBUF.SIZ)
	mov	a,d
	ana	e
	inr	a	; BDOS returned FFFF?
	jnz	geta2
	mvi	m,2-1	; error SIZ is 2 bytes
	inx	h
	mov	m,d
	inx	h
	mov	m,e	; resp val is FFFF
	jmp	sndbak
; no error, copy from addr to MSGBUF
geta2:	mov	b,m	; SIZ
	inr	b
	inx	h
	call	moveb	; move data into MSGBUF
	jmp	sndbak

; set default password
defpwd:	pop	h	; off=0 (HL=MSGBUF)
	inx	h
	inx	h
	inx	h
	inx	h
	mvi	m,1-1	; resp SIZ is 1 byte
	inx	h
	push	h	; off=2
	xchg
	mvi	c,defpwdf
	call	bdos
	pop	h	; off=0 (HL=MSGBUF.DAT)
	mov	m,a	; set return code
	jmp	sndbak

; login to server
login:	pop	h	; off=0 (HL=MSGBUF)
	inx	h
	inx	h
	mov	c,m	; SID - requester NID
	inx	h
	inx	h
	xra	a
	mov	m,a	; resp SIZ is 1 byte
	inx	h
	push	h	; off=2
	call	chklog
	pop	d	; off=0 (DE=MSGBUF.DAT)
	inr	a
	jz	lgi0
	xra	a	; already logged in... success
	stax	d
	jmp	sndbak

lgi0:	push	d	; off=2
	di	;------------------- begin crit sect
	lhld	cfgadr
	inx	h
	inx	h
	mov	a,m	; G$MAX
	inx	h
	cmp	m	; G$NUM
	jnz	lgi1
	pop	h	; off=0 (HL=MSGBUF.DAT)
	mvi	m,0ffh	; non-descript failure code
	; BUG? needs "ei"?
	jmp	sndbak

lgi1:	push	h	; off=4
	lxi	b,G$PWD-G$NUM	; login password
	dad	b
	mvi	b,8
lgi2:	ldax	d	; MSGBUF.DAT[x]
	cmp	m
	jnz	lgi5	; passwords don't match...
	inx	h
	inx	d
	dcr	b
	jnz	lgi2
	; passwords match...
	pop	h	; off=2 (HL=cfgadr.G$NUM)
	inr	m	; one more requestor logged in...
	inx	h	; cfgadr.G$VEC
	; find "0" in G$VEC bitmap
	; there must be a spot since G$NUM < G$MAX
	lxi	d,00001h
	lxi	b,0
lgi3:	push	d	; off=4
	call	andM
	ora	e
	pop	d	; off=2
	dcx	h
	jz	lgi4	; found a spot...
	xchg		; DE <<= 1
	dad	h
	xchg
	inr	c	; bit number, 0..15
	jmp	lgi3

lgi4:	mov	a,e	; set G$VEC bitmap
	ora	m
	mov	m,a
	inx	h
	mov	a,d
	ora	m
	mov	m,a
	inx	h	; G$LOG
	dad	b	; G$LOG[bit]
	pop	d	; off=0 (DE=MSGBUF.DAT)
	xra	a
	stax	d	; resp "success"
	dcx	d
	dcx	d
	dcx	d	; SID
	ldax	d	; requester NID from MSGBUF
	mov	m,a	; record login NID at G$LOG[bit]
	jmp	lgi6

lgi5:	pop	h	; off=2
	pop	h	; off=0 (HL=MSGBUF.DAT)
	mvi	m,0ffh	; error resp
lgi6:	ei	;------------------- end crit sect
	lxi	d,0ffffh	; clean slate
	mvi	c,freef
	call	bdos
	jmp	sndbak

; logout requester
logout:	pop	h	; off=0 (HL=MSGBUF)
	inx	h
	inx	h
	mov	a,m	; SID - requester NID
	inx	h
	inx	h
	inx	h
	mvi	m,0	; resp code success
	call	srvlgo
	jmp	sndbak	;

; Remove requester from server config.
; A=requester NID
srvlgo:	lhld	cfgadr
	inx	h
	inx	h
	mov	c,m	; G$MAX
	mov	b,c
	inx	h
	inx	h
	inx	h
	inx	h	; G$LOG
lgo0:	cmp	m	; search for this NID
	jz	lgo1
	inx	h
	dcr	c
	jnz	lgo0
	ret	; not logged in, just return

lgo1:	mov	a,b
	sub	c	; position of requester in array/bitmap
	di	;------------------- begin crit sect
	lhld	cfgadr
	inx	h
	inx	h
	inx	h
	dcr	m	; G$NUM, one less requester logged in
	inx	h
	push	h	; G$VEC
	mov	e,m
	inx	h
	mov	d,m
	mov	c,a
	mvi	b,0
	lxi	h,drvmsk
	dad	b
	dad	b
	call	andM	; clear requester's bit
	pop	h	; G$VEC
	mov	m,e
	inx	h
	mov	m,d
	ei	;------------------- end crit sect
	ret

cmpatr:	mvi	c,sysdatf
	call	bdos
	lxi	d,96	; enable compat attrs
	dad	d
	mov	a,m	; attrs enabled?
	ora	a	; ZR (disabled) tested later...
	pop	h	; off=0, HL=MSGBUF
	lxi	d,DAT
	dad	d
	mov	a,m	; MSGBUF.DAT[0]
	lxi	h,@procd+0
	dad	sp
	mov	e,m
	inx	h
	mov	d,m	; DE=proc desc
	lxi	h,P$ATTR
	dad	d
	jz	cmpa0
	ani	11110000b
	mov	e,a
	mov	a,m
	ani	00001111b
	ora	e
	mov	m,a	; set compat attrs
cmpa0:	ora	a
	jnz	sndbak
	xchg
	lda	spoolf
	lxi	h,@spact+0
	dad	sp
	ana	m
	rar
	push	d	; off=2
	jnc	cmpa1
	xra	a
	call	setusr	;(off=2)
	lxi	h,@spfcb+2
	dad	sp
	xchg
	mvi	c,closef
	call	bdos
	stc
cmpa1:	pop	h	; off=0 (HL=proc desc)
	push	psw	; off=2
	lxi	d,P$DSEL
	dad	d
	mvi	m,0	; drive A:, user 0
	pop	psw	; off=0
	jnc	sndbak
	lxi	h,@spfcb+0
	dad	sp
	xchg
	mvi	c,openf
	call	bdos
	jmp	sndbak

stdfcb:	pop	h	; off=0 (HL=MSGBUF)
	lxi	d,DAT
	dad	d
	push	h	; off=2
	mov	a,m	; MSGBUF.DAT[0]
	call	setusr
	pop	h	; off=0 (HL=MSGBUF.DAT)
	push	h	; off=2
	lxi	d,F$LEN+1	; skip past FCB
	dad	d	; record data in MSGBUF
	xchg
	mvi	c,dmaf
	call	bdos
	pop	h	; off=0 (HL=MSGBUF.DAT)
	push	h	; off=2
	dcx	h
	dcx	h
	mov	c,m	; FNC
	mov	a,c
	inx	h
	cpi	rseqf
	jz	sfcb0
	cpi	rrndf
	jnz	sfcb1
sfcb0:	mvi	m,getlstf
	jmp	sfcb2

; neither read seq nor rand, just do it.
sfcb1:	mvi	m,F$LEN+1-1	; FCB and usrnum only
; common FCB handling
sfcb2:	inx	h
	inx	h	; FCB at MSGBUF.DAT[1]
	xchg
	call	bdos	; perform function
	xchg
	pop	h	; off=0 (MSGBUF.DAT)
	call	setret
; reverse DID/SID and send message back to requester
sndbak:	lxi	h,@msgqi+0	; off=0
	dad	sp
	mov	e,m
	inx	h
	mov	d,m
	push	d
	xchg			; HL=MSGBUF
	inr	m		; FMT 00 -> 01
	inx	h	; DID
	mov	b,m		; swap DID, SID
	inx	h	; SID
	mov	a,m
	mov	m,b		; SID = DID
	mov	b,a		; save SID (requester) for later
	inx	h	; FNC
	mov	c,m		; save FNC for later
	dcx	h	; SID
	dcx	h	; DID
	mov	m,a		; DID = SID
	; B=requester NID, C=FNC
	; check for logoff
	mvi	a,logoutf	; a.k.a. "logoff"
	sub	c	; 00=logoff
	sui	1	; CY=logoff
	mov	a,b
	push	psw	; CY means A=requester NID to log off
	call	nlock
	pop	psw
	pop	b	; BC=MSGBUF
	push	b
	push	psw
	call	SNDMSG
	; TODO: handle error?
	pop	psw
	push	psw
	cc	NWLOGO	; log out requester
	call	nunlock
	pop	psw
	; free requester slot
	cc	rqfree
	pop	h	; HL=MSGBUF
	call	bffree
	jmp	ntloop		; get (wait for) next message

; Process/procedure initialization. cfgadr already setup.
; HL=SERVR0PR
pinit:
	shld	srvr0pd
	lxi	d,spoolq
	mvi	c,openqf
	call	bdos
	ora	a
	jz	ps0
	lxi	d,5	; sleep for 5 ticks
	mvi	c,delayf
	call	bdos
	; try once more, only
	lxi	d,spoolq
	mvi	c,openqf
	call	bdos
	cma		; 0ffh if success
	sta	spoolf
	jmp	ps1

ps0:	mvi	a,0ffh
	sta	spoolf
ps1:
	lhld	cfgadr
	inx	h
	inx	h
	mov	a,m	; max num requesters
	sta	maxcon
	mvi	c,sysdatf
	call	bdos
	mvi	l,S$TEMP	; temp drive
	mov	a,m
	sta	tmpdrv
	lhld	srvr0pd
	mvi	b,0	; loop counter
	lda	maxcon
	mov	c,a	; C=max num requesters
	lxi	d,stacks+srvr$stk$len-2
	jmp	ps2	; first PD is already setup
; -------------------------
; create SERVRxPR processes
ps4:	; DE=proc-desc, HL=stack-end
	push	h
	push	d
	lhld	srvr0pd
	xchg		; DE=srvr0pd, HL=proc-desc
	push	b
	mvi	b,P$LEN
	call	moveb
	pop	b	; loop vars
	pop	h	; HL=proc-desc
	pop	d	; DE=stack-end
ps2:	; DE=stack-end, HL=proc-desc
	push	d
	push	h
	push	b
	xra	a
	mov	m,a
	inx	h
	mov	m,a	; PD.LINK=0
	inx	h
	inx	h
	inx	h	; PD.STKPTR
	mov	m,e	; stack pointer/start...
	inx	h
	mov	m,d	;
	inx	h	; PD.NAME[0]
	inx	h
	inx	h
	inx	h
	inx	h
	inx	h	; PD.NAME[5], 'x' in "SERVRxPR"
	mov	a,b
	adi	90h
	daa
	aci	40h
	daa
	mov	m,a	; set 'x' in "SERVRxPR"
	xchg		; HL=stack-end
	lxi	b,cpnet	; start PC for extra processes
	mov	m,c
	inx	h
	mov	m,b
	pop	b	; loop vars
	inx	d	; PD.NAME[6]
	inx	d	; PD.NAME[7]
	inx	d	; PD.CONSOLE/LIST
	xra	a	; same console/list for all
	stax	d	; set con/lst
	lxi	h,P$BC-P$CONLST
	dad	d	; HL=PD.BC
	mov	m,b	; index in C reg
	pop	d	; DE=proc-desc
	push	d	;
	push	b	;
	; process create will zero compat attr,
	; must setup write-protect later.
	mvi	c,makepf
	call	bdos	; create new process
	pop	b
	pop	h	; HL=proc-desc
	lxi	d,P$LEN
	dad	d	; next proc descr slot
	xthl		; HL=stack-end
	lxi	d,srvr$stk$len
	dad	d	; HL=stack-end(next)
	pop	d	; DE=proc-desc(next)
	inr	b
	mov	a,b
	cmp	c
	jnz	ps4
	; we're not running in a server process, so just return
	xra	a
	ret

	end
