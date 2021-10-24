; Reconstruction of SERVER.RSP for the CP/NET Server.
; Contains code optimizations (macros) that cause a slight
; variation in one code sequence, compared to original SERVER.RSP.
;
; ASCII control characters
cr	equ	13
lf	equ	10
eof	equ	26

; BDOS function numbers
listf	equ	5
drivef	equ	14
openf	equ	15
closef	equ	16
searchf	equ	17
nextf	equ	18
rseqf	equ	20
wseqf	equ	21
makef	equ	22
dmaf	equ	26
getalvf	equ	27
wprotf	equ	28
userf	equ	32
rrndf	equ	33
wrndf	equ	34
freef	equ	39
defpwdf	equ	106

; XDOS function numbers
openqf	equ	135
readqf	equ	137
writqf	equ	139
delayf	equ	141
makepf	equ	144
sysdatf	equ	154
getpdf	equ	156
attlstf	equ	158
detlstf	equ	159
setlstf	equ	160
getlstf	equ	164

cpm	equ	0
deffcb	equ	005ch

; UQCB elements
Q$PTR	equ	0
Q$MSG	equ	2
Q$NAME	equ	4	; 8 bytes long

; some macros to simplify shared code.
HEXASCII macro	; convert 0..F in A to ASCII hex digit
	local	?1,?2
	cpi	10
	jnc	?1
	adi	'0'
	jmp	?2
?1:	adi	'A'-10
?2:	equ	$
	endm

SRVNUM	macro	?o	; get srvno and convert to ASCII hex
	lxi	h,@srvno+?o
	dad	sp
	mov	a,m
	HEXASCII
	endm

; Each SERVRxPR process keeps the following data on it's stack:
;
;
; References to stack data must take into account the current
; stack depth.

	cseg
; RSP link - "call bdos" address
bdose:	dw	0
; Main process descriptor - "SERVR0PR"
SERVR0PR:
	dw	0	; link
	db	0	; status
	db	100	; priority
	dw	istk	; initial stack pointer, proc 0 start
	; extended errors and no abort options
	db	'SERV','R'+80h,'0P','R'+80h
	db	0,0ffh,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
	db	0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0

	; same stack depth (stack0-$) as reserved in netwrkif.asm for extra procs
	db	0c7h,0c7h,0c7h,0c7h
	db	0c7h,0c7h,0c7h,0c7h,0c7h,0c7h,0c7h,0c7h,0c7h,0c7h,0c7h,0c7h
	db	0c7h,0c7h,0c7h,0c7h,0c7h,0c7h,0c7h,0c7h,0c7h,0c7h,0c7h,0c7h
	db	0c7h,0c7h,0c7h,0c7h,0c7h,0c7h,0c7h,0c7h,0c7h,0c7h
istk:	ds	0	; main stack
	dw	pstart	; setup - procedure start address (overwritten)
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
?uqcbo:	db	0,0,0,0,0,0,0,0,0,0,0,0

stack0:	ds	0	; extended stack

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
@uqcbo	equ	?uqcbo-?base

	db	'COPYRIGHT (C) 1982, DIGITAL RESEARCH '
	db	0,0ch,0,2,4,0c4h	; serial number

; Template for network message queue (input)
qtmplt:	db	'NtwrkQIx'	; 'x' replaced by 0..F

srvcfg:	dw	0
maxcon:	db	0
spoolf:	db	0

texcmd:	db	'.TEX[D',0dh,0

tmpdrv:	db	1,'xxSPOOLF','TEX',0,0,0,0
	db	0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
	db	0,0,0,0

spoolq:	db	0,0,0,0,'SPOOLQ  '

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

	; what is this for?
	db	0,0,0,0,0,0,0,0,0,0,0
	db	0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
	db	0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0

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
	lhld	srvcfg
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
	lhld	srvcfg
	inx	h
	cmp	m
	jz	val0
	mvi	a,0ffh		; error if server ID wrong
	ret

val0:	xchg
	inx	h	; SID
	inx	h	; FNC
	mov	a,m
	sui	64	; LOGIN
	rz		;
	mov	a,m
	cpi	100
	jc	val1
	sui	50
	mov	m,a	; 100.. => 50..
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
	cpi	76	; valid FNC range?
	jnc	val3
	xra	a
	ret

val3:	mvi	a,0ffh
	ret

bdos:	lhld	bdose
	pchl

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
biosv:	mov	h,m
	xchg
	lhld	cpm+1
	inx	h
	inx	h
	mov	h,m
	mov	l,c
	mov	c,a
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
	lhld	bdose
	pchl

; Set current drive in OS
; stack depth +2 for call... already +2
seldrv:	lxi	h,@drvno+2+2
	dad	sp
	cmp	m
	rz
	mov	m,a
	mov	e,a
	mvi	c,drivef
	lhld	bdose
	pchl

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
; C=? A=?
; does not return.
cpnet:	lxi	h,-@init	;
	dad	sp	;
	sphl		; reserve space on stack
	push	b	; save C=id num of server process, 0..F
	; baseline stack depth, +0
	mvi	c,getpdf
	call	bdos
	xchg		; DE = our proc descr
	lxi	h,@procd
	dad	sp	; HL=?procd
	mov	m,e	;
	inx	h
	mov	m,d	; set our proc descr addr
	inx	h
	xchg		; DE=?msgqi
	lxi	h,@uqcbi+Q$MSG+0
	dad	sp	; HL=?uqcbi.MSGADR
	mov	m,e
	inx	h
	mov	m,d	; ?uqcbi.MSGADR = ?msgqi
	push	d	; off=2 (save ?msgqi)
	inx	h	; HL=?uqcbi.NAME
	lxi	d,qtmplt
	push	d	; off=4
	mvi	b,7
	call	moveb	; ?uqcbi.NAME = "NtwrkQI"
	xchg
	SRVNUM	4
	stax	d	; set 'x' in "NtwrkQIx"
	lxi	h,@uqcbi+4+2	; our private queue, (+2 for call)
	call	openq
	pop	d	; off=2 (qtmplt)
	pop	b	; off=0 (BC=?msgqi)
	lxi	h,@uqcbo+Q$MSG+0
	dad	sp	;
	mov	m,c
	inx	h
	mov	m,b	; ?msgqo.MSGADR = ?msgqi : same msg buffer both queues
	inx	h
	mvi	b,6
	call	moveb
	mvi	a,'O'
	mov	m,a	; "NtwrkQOx"
	inx	h
	xchg
	SRVNUM	0	; get srvno as hex digit
	stax	d	; set 'x' in "NtwrkQOx"
	lxi	h,@uqcbo+0+2	; +2 for call
	call	openq
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
	xchg
	lxi	h,@uqcbs+0
	dad	sp	; HL=?uqcbs (spooler msg queue)
	mov	m,e
	inx	h
	mov	m,d	; UQCB.POINTER = spoolq
	inx	h
	xchg		; DE=UQCB.MSGADR
	lxi	h,@spcmd+0
	dad	sp
	xchg		; DE=?spcmd (spooler msg buffer)
	mov	m,e
	inx	h
	mov	m,d	; UQCB.MSGADR = ?spcmd
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
conout:	pop	h	; off=0
	lxi	b,5
	dad	b
	push	h
	mvi	c,3*3	; conout BIOS vector
	call	biosv
	pop	h
	mov	m,a
	jmp	sndbak

; List output via BIOS
lstout:	pop	h	; off=0
	lxi	b,6
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
	lxi	d,tmpdrv
	lxi	h,@spfcb+2
	dad	sp
	push	h	; off=4
	mvi	b,36
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
	lxi	h,134	; what is here?
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
	lxi	d,5
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
	lxi	d,6
	dad	d	; DAT[1]... chars for printer
	push	h	; off=2
	xchg
	mvi	c,dmaf	; data for spool file - incl. EOF or full 128 bytes
	call	bdos
	pop	h	; off=0 (HL=DAT[1])
	dcx	h
	dcx	h	; SIZ
	push	h	; off=2
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
	lxi	h,33	; point to rand record in fcb
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
	lxi	h,29	; PD extent? +1?
	dad	b
	mov	a,m
	push	h	; off=4
	push	psw	; off=6
	mvi	m,0
	mvi	c,closef ; close spool file
	call	bdos
	pop	psw	; off=4 (A=PD ext val)
	pop	h	; off=2 (HL=PD extent)
	mov	m,a
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
	inx	d	; pont to filename
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
	lxi	d,5
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
	mvi	m,23-1	; srv cfg tbl SIZ is 23 bytes
	inx	h
	xchg
	lda	tmpdrv
	dcr	a
	stax	d	; TMP drive
	inx	d
	lhld	srvcfg	; plus rest of internal config table
	xchg
	mvi	b,22
	call	moveb
	jmp	sndbak

; simple  FCB funcs: delete,rename,set-attrs
smpfcb:	pop	h	; off=0 (HL=MSGBUF)
	lxi	d,5
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
	lxi	d,6
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
	lxi	h,23
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
	mvi	m,33-1	; response SIZ is 33
	ani	003h
	mov	b,a
	lxi	d,32
	call	multDE	; index into DMA buf
	xchg
	pop	d	; off=0 (DE=MSGBUF.DAT)
	inx	d
	dad	d
	xchg
	mvi	b,32
	call	moveb	; move DIRENT into MSGBUF
	lxi	h,@procd+0
	dad	sp
	mov	e,m
	inx	h
	mov	d,m
	lxi	h,23	; PROC.DCNT
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
	lhld	srvcfg
	inx	h
	inx	h
	mov	a,m
	inx	h
	cmp	m
	jnz	lgi1
	pop	h	; off=0 (HL=MSGBUF.DAT)
	mvi	m,0ffh	; non-descript failure code
	jmp	sndbak

lgi1:	push	h	; off=4
	lxi	b,19	; login NID array...
	dad	b
	mvi	b,8
lgi2:	ldax	d
	cmp	m
	jnz	lgi5
	inx	h
	inx	d
	dcr	b
	jnz	lgi2
	; match...
	pop	h	; off=2 (HL=srvcfg...)
	inr	m	; one more requestor logged in...
	inx	h
	; find "0" in bitmap
	lxi	d,00001h
	lxi	b,0
lgi3:	push	d	; off=4
	call	andM
	ora	e
	pop	d	; off=2
	dcx	h
	jz	lgi4
	xchg		; DE <<= 1
	dad	h
	xchg
	inr	c
	jmp	lgi3

lgi4:	mov	a,e	; set bitmap
	ora	m
	mov	m,a
	inx	h
	mov	a,d
	ora	m
	mov	m,a
	inx	h
	dad	b	; NID in array, relative to bit in bitmap
	pop	d	; off=0 (DE=MSGBUF.DAT)
	xra	a
	stax	d	; resp "success"
	dcx	d
	dcx	d
	dcx	d	; SID
	ldax	d	; requester NID
	mov	m,a	; record login NID
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
	lhld	srvcfg
	inx	h
	inx	h
	mov	c,m
	mov	b,c
	inx	h
	inx	h
	inx	h
	inx	h
lgo0:	cmp	m
	jz	lgo1
	inx	h
	dcr	c
	jnz	lgo0
	jmp	sndbak

lgo1:	mov	a,b
	sub	c
	di
	lhld	srvcfg
	inx	h
	inx	h
	inx	h
	dcr	m
	inx	h
	push	h
	mov	e,m
	inx	h
	mov	d,m
	mov	c,a
	mvi	b,0
	lxi	h,drvmsk
	dad	b
	dad	b
	call	andM
	pop	h
	mov	m,e
	inx	h
	mov	m,d
	ei
	jmp	sndbak

cmpatr:	mvi	c,sysdatf
	call	bdos
	lxi	d,96	; reserved for MP/M-II
	dad	d
	mov	a,m
	ora	a	; ZR tested later...
	pop	h	; off=0, HL=MSGBUF
	lxi	d,5
	dad	d
	mov	a,m	; user num?
	lxi	h,@procd+0
	dad	sp
	mov	e,m
	inx	h
	mov	d,m	; DE=proc desc
	lxi	h,29	; PD extent? +1?
	dad	d
	jz	cmpa0
	mov	m,a
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
cmpa1:	pop	h	; off=0
	push	psw	; off=2
	lxi	d,22
	dad	d
	mvi	m,000h
	pop	psw	; off=0
	jnc	sndbak
	lxi	h,@spfcb+0
	dad	sp
	xchg
	mvi	c,openf
	call	bdos
	jmp	sndbak

stdfcb:	pop	h
	lxi	d,5
	dad	d
	push	h
	mov	a,m
	call	setusr
	pop	h
	push	h
	lxi	d,37
	dad	d
	xchg
	mvi	c,dmaf
	call	bdos
	pop	h
	push	h
	dcx	h
	dcx	h
	mov	c,m
	mov	a,c
	inx	h
	cpi	rseqf
	jz	sfcb0
	cpi	rrndf
	jnz	sfcb1
sfcb0:	mvi	m,getlstf
	jmp	sfcb2

; neither read seq nor rand, just do it.
sfcb1:	mvi	m,36
; common FCB handling
sfcb2:	inx	h
	inx	h
	xchg
	call	bdos
	xchg
	pop	h
	call	setret
; reverse DID/SID and send message back to requester
sndbak:	lxi	h,@msgqi+0	; off=0
	dad	sp
	mov	e,m
	inx	h
	mov	d,m
	xchg			; HL=MSGBUF
	inr	m		; FMT 00 -> 01
	inx	h
	mov	b,m		; DID
	inx	h
	mov	a,m		; SID
	mov	m,b		; SID = DID
	dcx	h
	mov	m,a		; DID = SID
	lxi	h,@uqcbo+0
	dad	sp
	xchg
	mvi	c,writqf
	call	bdos		; hand-off response to NtwrkIPx
	jmp	ntloop		; get (wait for) next message

; Process/procedure start - all server processes
pstart:	lxi	d,spoolq
	mvi	c,openqf
	call	bdos
	ora	a
	jz	ps0
	lxi	d,5
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
ps1:	mvi	c,sysdatf
	call	bdos
	lxi	d,9	; CP/NET master config table addr
	dad	d
ps2:	mov	a,m
	inx	h
	ora	m
	dcx	h
	push	h	; ZR=no CP/NET
	jnz	ps3
	; wait for CP/NET (NTWRKIF) to appear...
	lxi	d,1
	mvi	c,delayf
	call	bdos
	pop	h
	jmp	ps2

ps3:	pop	h
	mov	e,m
	inx	h
	mov	d,m
	xchg
	shld	srvcfg	; server config table from NETWRKIF
	inx	h
	inx	h
	mov	a,m	; max num requesters
	sta	maxcon
	lxi	d,28
	dad	d
	push	h	; srvcfg+30 = slave stacks, etc.
	mvi	c,sysdatf
	call	bdos
	lxi	d,196	; temp drive
	dad	d
	mov	a,m
	sta	tmpdrv
	pop	h
	mvi	b,0	; loop counter
	lda	maxcon
	mov	c,a	; C=max num requesters
	lxi	d,148	; slave$stk$len-2
	dad	d
	mov	e,m
	inx	h
	mov	d,m	; DE = SlaveX proc descr
	dcx	h
; create additional SERVRxPR processes
ps4:	inr	b
	mov	a,b
	cmp	c
	jz	ps5	; done
	push	h
	push	d
	xchg
	lxi	d,SERVR0PR
	push	b
	mvi	b,52
	call	moveb
	pop	b
	pop	h	; SlaveX proc descr
	pop	d	; &(SlaveX proc descr)
	push	d
	push	h
	push	b
	xra	a
	mov	m,a
	inx	h
	mov	m,a	; set SlaveX link to NULL
	inx	h
	inx	h
	inx	h
	mov	m,e	; stack pointer/start...
	inx	h
	mov	m,d	;
	inx	h
	inx	h
	inx	h
	inx	h
	inx	h
	inx	h	; 'x' in "SERVRxPR"
	mov	a,b
	HEXASCII
	mov	m,a	; set 'x' in "SERVRxPR"
	xchg
	lxi	b,cpnet	; start address for extra processes
	mov	m,c
	inx	h
	mov	m,b
	pop	b
	inx	d
	inx	d
	inx	d
	mov	a,b
	stax	d	; "console id"? re-purposed?
	lxi	h,32
	dad	d
	mov	m,b	; also in A reg
	pop	d
	push	d
	push	b
	mvi	c,makepf
	call	bdos	; create new process
	pop	b
	pop	h	; proc descr addr
	lxi	d,52
	dad	d	; next proc descr slot
	xthl
	lxi	d,150
	dad	d	; next proc stack slot
	pop	d
	jmp	ps4

ps5:	lxi	h,stack0
	sphl
	mvi	c,0
	call	cpnet	; start main loop
	; does not return

	end
