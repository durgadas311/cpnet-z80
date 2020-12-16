; A config util for WizNET 550 devices, attached in parallel-SPI interface
; Sets config into NVRAM, unless 'w' option prefix to set to WIZ850io directly.
;
; Commands:
;	[w] n <id>		Set node ID
;	[w] g <ip>		Set gateway IP addr
;	[w] s <ip>		Set sub-network mask
;	[w] i <ip>		Set node IP addr
;	[w] m <ma>		Set node h/w addr
;	[w] 0 <id> <ip> <pt>	Set sock 0
;	r			Restore WIZ850io config from NVRAM

	maclib	config

	extrn	wizcfg, wizcmd, wizget, wizset, wizclose, setsok, settcp
	extrn	gkeep,skeep

if (SPIDEV eq H8xSPI)
	extrn	cksum32, vcksum, scksum, nvget
endif

	public	nvbuf	; for wizcfg routine

	maclib	z80

CR	equ	13
LF	equ	10

cpm	equ	0
bdos	equ	5
cmd	equ	0080h

print	equ	9
getver	equ	12
cfgtbl	equ	69

	cseg

	jmp	start

	dseg
idmsg:	db	'Node ID:  $'
gwmsg:	db	'Gateway:  $'
ntmsg:	db	'Subnet:   $'
mcmsg:	db	'MAC:      $'
ipmsg:	db	'IP Addr:  $'

usage:	db	'WIZCFG version 1.4',CR,LF
	db	'Usage: WIZCFG {G|I|S} ipadr',CR,LF
	db	'       WIZCFG M macadr',CR,LF
	db	'       WIZCFG N cid',CR,LF
	db	'       WIZCFG {0..7} sid ipadr port [keep]',CR,LF
if ( (SPIDEV eq MT011) OR (SPIDEV eq Z180CSIO) )
	db	'Sets network config in W5500',CR,LF
if (SPIDEV eq Z180CSIO)
	db	'Built for SC126 Z180 CSIO',CR,LF
endif
else
	db	'       WIZCFG R',CR,LF
	db	'       WIZCFG L {A:..P:,LST:}',CR,LF
	db	'       WIZCFG T {A:..P:}={A:..P:}[sid]',CR,LF
	db	'       WIZCFG T LST:=idx[sid]',CR,LF
	db	'       WIZCFG X {A:..P:,LST:}',CR,LF
	db	'Sets network config in NVRAM',CR,LF
	db	'Prefix cmd with W to set WIZ850io directly',CR,LF
	db	'R cmd sets WIZ850io from NVRAM',CR,LF
endif
	db	'$'
done:	db	'Set',CR,LF,'$'
sock:	db	'Socket '
sokn:	db	'N: $'
ncfg:	db	'No Sockets Configured',CR,LF,'$'
ndcfg:	db	'No Devices Configured',CR,LF,'$'
nocpn:	db	'CP/NET is running! Restoring config anyway...',CR,LF,'$'
nverr:	db	'NVRAM block not initialized',CR,LF,'$'
newbuf:	db	'Initializing new NVRAM block',CR,LF,'$'
nowerr:	db	'"W" prefix not allowed',CR,LF,'$'

ldrv:	db	'Local '
l0:	db	'_:',CR,LF,'$'
ndrv:	db	'Network '
n0:	db	'_: = '
n1:	db	'_:['
n2:	db	'__]',CR,LF,'$'

llst:	db	'Local LST:',CR,LF,'$'
nlst:	db	'Network LST: = '
nl1:	db	'_['
nl2:	db	'__]',CR,LF,'$'

	cseg
start:
	sspd	usrstk
	lxi	sp,stack
	mvi	c,getver
	call	bdos
	mov	a,h
	ani	02h
	jz	nocpnt
	ori	0ffh
	sta	cpnet
	mvi	c,cfgtbl
	call	bdos
	shld	netcfg
nocpnt:
	lda	cmd
	ora	a
	jz	show

	lxi	h,cmd
	mov	b,m
	inx	h
pars0:
	mov	a,m
	cpi	' '
	jnz	pars1
	inx	h
	djnz	pars0
	jmp	show

pars1:
if (SPIDEV eq H8xSPI)
	cpi	'W'
	jnz	notw
	sta	direct
	inx	h
	djnz	pars0
	jmp	show
notw:
	; All require pre-read of NVRAM, if not direct
	push	h
	push	b
	lda	direct
	ora	a
	cz	nvgetb	; init buf if needed
	pop	b
	pop	h
	mov	a,m	; restore cmd
	; These have no params...
	cpi 	'R'
	jz	pars5
else
	mov	a,m	; restore cmd
endif
	;
	mov	c,a
	call	skipb1
	jc	help
	mov	a,c
	cpi 	'G'
	lxix	gw
	lxi	d,GAR
	jz	pars2
	cpi 	'I'
	lxix	ip
	lxi	d,SIPR
	jz	pars2
	cpi 	'S'
	lxix	msk
	lxi	d,SUBR
	jz	pars2
	cpi 	'M'
	jz	pars3
	cpi 	'N'
	jz	pars4
if (SPIDEV eq H8xSPI)
	cpi 	'L'
	jz	locdv
	cpi 	'X'
	jz	locdv
	cpi 	'T'
	jz	netwk
endif
	cpi	'0'
	jc	help
	cpi	'7'+1
	jnc	help

; Parse new Socket config
	sta	sokn
	; parse <srvid> <ipadr> <port>
	mvi	c,0	; NUL won't ever be seen
	call	parshx
	jc	help
	mvi	a,31h
	sta	nskpt
	mov	a,d	; server ID
	sta	nskpt+1
	call	skipb
	jc	help
	lxix	nskip
	call	parsadr
	jc	help
	call	skipb
	jc	help
	call	parsnm
	jc	help
	mov	a,d
	sta	nskdpt
	mov	a,e
	sta	nskdpt+1
	; optional keep-alive timeout
	xra	a
	sta	nskkp
	call	skipb
	jc	nokp
	mov	a,b
	ora	a
	cnz	parsnm
	jc	help
	call	div5
	mov	a,d
	ora	a
	jz	nokp0
	mvi	e,0ffh	; max keepalive
nokp0:	mov	a,e
	sta	nskkp
nokp:
; Now prepare to update socket config
if (SPIDEV eq H8xSPI)
	lda	direct
	ora	a
	jz	nvsok
endif
	; set Sn_MR separate, to avoid writing CR and SR...
	call	getsokn
	mov	d,a
	push	d
	call	settcp	; force TCP mode
	lda	nskkp
	call	skeep	; set keep-alive
	; Get current values, cleanup as needed
	lxi	h,sokregs
	mvi	e,SnMR
	mvi	b,soklen
	call	wizget
	lxi	h,sokmac
	lxi	d,nskmac
	lxi	b,6
	ldir
	lda	sokpt
	cpi	31h
	jnz	ntcpnet	; don't care about sockets not configured
	lda	cpnet
	ora	a
	jz	ntcpnet	; skip CFGTBL cleanup if not CP/NET
	; remove all refs to this server...
	lda	sokpt+1	; server node ID
	mov	c,a
	lhld	netcfg
	mvi	b,18	; 16 drives, CON:, LST:
	inx	h
	inx	h
cln0:	mov	a,m
	ora	a
	jp	ntnet	; device not networked
	inx	h
	mov	a,m
	cmp	c	; same server?
	jnz	ntnet1
	xra	a
	mov	m,a
	dcx	h
	mov	m,a
ntnet:	inx	h
ntnet1:	inx	h
	djnz	cln0
ntcpnet:
	lda	sokmr+SnSR
	cpi	CLOSED
	jz	ntopn
	pop	d
	push	d
	mvi	a,DISCON
	call	wizcmd
	; don't care about results?
ntopn:	lxi	h,newsok
	pop	d
	mvi	e,SnPORT
	mvi	b,soklen-SnPORT
	jmp	setit

if (SPIDEV eq H8xSPI)
nvsok:
	lda	sokn
	sui	'0'	; 00000sss
	rrc
	rrc
	rrc		; sss00000 or sokn * 32
	mov	e,a
	mvi	d,0
	lxix	nvbuf+32	; socket 0 buffer
	dadx	d
	lhld	nskpt	; big endian data, little endian load...
	stx	l,SnPORT
	stx	h,SnPORT+1
	lhld	nskip	; little endian load...
	stx	l,SnDIPR
	stx	h,SnDIPR+1
	lhld	nskip+2	; little endian load...
	stx	l,SnDIPR+2
	stx	h,SnDIPR+3
	lhld	nskdpt	; big endian data, little endian load...
	stx	l,SnDPORT
	stx	h,SnDPORT+1
	lda	nskkp
	stx	a,NvKPALVTR	; force to 00 if not set
	jmp	nvsetit
endif

pars4:
	call	parshx
	jc	help
	mov	a,d
	sta	wizmag
	lxi	h,wizmag
	lxi	d,PMAGIC
	mvi	b,1
	jmp	setit0

pars3:
	lxix	mac
	pushix
	call	parsmac
	pop	h
	jc	help
	lxi	d,SHAR
	mvi	b,6
	jmp	setit0

pars2:
	pushix
	push	d
	call	parsadr
	pop	d
	pop	h
	jc	help
	mvi	b,4
	; got it...
setit0:
if (SPIDEV eq H8xSPI)
	lda	direct
	ora	a
	jnz	setit
	push	h
	lxi	h,nvbuf
	dad	d
	xchg
	pop	h
	mov	c,b
	mvi	b,0
	ldir
	jmp	nvsetit
endif
setit:
	call	wizset

	;lxi	d,done
	;mvi	c,print
	;call	bdos
	jmp	exit

if (SPIDEV eq H8xSPI)
nvshow:	; show config from NVRAM
	lxix	nvbuf
	lxi	h,0
	lxi	d,512
	call	nvget
	call	vcksum
	jnz	cserr
	lda	nvbuf+PMAGIC
	call	shid
	lxi	h,nvbuf+SIPR
	lxi	d,ipmsg
	call	ship
	lxi	h,nvbuf+GAR
	lxi	d,gwmsg
	call	ship
	lxi	h,nvbuf+SUBR
	lxi	d,ntmsg
	call	ship
	lxi	h,nvbuf+SHAR
	call	shmac
	lxi	h,nvbuf+32	; socket 0 buffer
	mvi	b,nsock
shnvsk0:
	push	b
	lxi	d,sokregs
	lxi	b,soklen
	ldir
	lxi	d,NvKPALVTR-soklen
	dad	d
	mov	a,m
	sta	sokkp
	lxi	d,32-NvKPALVTR
	dad	d	; next socket buf
	pop	b
	push	b
	push	h
	mvi	a,nsock
	sub	b	; 0..7
	mov	e,a
	call	showsok
	pop	h
	pop	b
	djnz	shnvsk0
	lda	count
	ora	a
	cz	nocfg
	; Now show any preset cfgtbl entries
	xra	a
	sta	count
	lxi	h,nvbuf+288	; cfgtbl template
	mvi	b,16
shnvcf0:
	inx	h
	inx	h
	mov	a,m
	cpi	0ffh
	cnz	shdrv
	djnz	shnvcf0
	inx	h	; skip CON:
	inx	h
	inx	h
	inx	h
	call	shlst
	lda	count
	ora	a
	cz	nodcfg
	jmp	exit

pars5:	; restore config from NVRAM
	lda	direct
	ora	a
	jnz	now
	lda	cpnet
	ora	a
	jz	xocpnt
	lxi	d,nocpn
	mvi	c,print
	call	bdos
xocpnt:
	call	wizcfg
	jc	cserr
	jmp	exit
	;...

now:	lxi	d,nowerr
	mvi	c,print
	call	bdos
	jmp	exit

locdv:	; skipb already called
	push	psw	; 'X' or 'L'
	lda	direct
	ora	a
	jnz	now
	mvi	c,0
	call	parsdv
	jc	help
	pop	psw
	sui	'L'	; 0C or 00
	jrz	locdv0
	mvi	a,0ffh
locdv0:
	; E= 0-15, or 17 (LST:)
	inr	e
	mvi	d,0
	lxi	h,nvbuf+288
	dad	d
	dad	d
	mov	m,a
	inx	h
	mov	m,a
	jmp	nvsetit

netwk:	; skipb already called
	lda	direct
	ora	a
	jnz	now
	call	parsdv
	jc	help
	mvi	a,'='
	call	check1
	jc	help
	; E= 0-15, or 17 (LST:)
	mov	a,e
	inr	e
	mvi	d,0
	lxix	nvbuf+288
	dadx	d
	dadx	d
	cpi	17	; LST:
	jrz	netlst
	call	parsdv
	jc	help
	mvi	a,'['
	call	check1
	push	psw
	mov	a,e
	cpi	16
	jnc	help
netwk1:
	ori	080h
	stx	a,+0
	pop	psw
	mvi	d,0
	jrc	netwk2
	mvi	c,']'
	call	parshx	; get SID
	jc	help
	mov	a,d
	cpi	0ffh
	jz	help
netwk2:
	stx	d,+1
	jmp	nvsetit
netlst:
	mvi	c,'['
	call	parshx	; get LST: num
	jc	help
	mov	a,d
	cpi	16
	jnc	help
	mvi	a,'['
	call	check1
	push	psw
	mov	a,d
	jr	netwk1

nvsetit:
	lxix	nvbuf
	call	scksum
	lxi	h,0	; WIZNET uses 512 bytes at 0000 in NVRAM
	lxi	d,512
	call	nvset
	;lxi	d,done
	;mvi	c,print
	;call	bdos
	;jmp	exit
endif
exit:
	jmp	cpm

if 0
trace:
	push	h
	push	d
	push	b
	mov	a,h
	call	hexout
	mov	a,l
	call	hexout
	mvi	a,' '
	call	chrout
	mov	a,d
	call	hexout
	mov	a,e
	call	hexout
	mvi	a,' '
	call	chrout
	mov	a,b
	call	hexout
	mov	a,c
	call	hexout
	call	crlf
	pop	b
	pop	d
	pop	h
	ret

endif
cserr:	lxi	d,nverr
	jr	xtmsg

help:
	lxi	d,usage
xtmsg:	mvi	c,print
	call	bdos
	jmp	exit

; Convert 'sokn' (ASCII digit) to socket BSB
getsokn:
	lda	sokn
	sui	'0'
	rrc
	rrc
	rrc		; xxx00000
	ori	SOCK0	; xxx01000
	ret

show:
if (SPIDEV eq H8xSPI)
	lda	direct
	ora	a
	jz	nvshow
endif
	lxi	h,comregs
	lxi	d,GAR
	mvi	b,comlen
	call	wizget
	lxi	h,wizmag
	lxi	d,PMAGIC
	mvi	b,1
	call	wizget

	lda	wizmag
	call	shid

	lxi	h,ip
	lxi	d,ipmsg
	call	ship

	lxi	h,gw
	lxi	d,gwmsg
	call	ship

	lxi	h,msk
	lxi	d,ntmsg
	call	ship

	lxi	h,mac
	call	shmac

	lxi	d,SOCK0 shl 8	; E=0
	mvi	b,nsock
show0:	push	b
	push	d
	mvi	e,0
	lxi	h,sokregs
	mvi	b,soklen
	call	wizget
	call	gkeep
	sta	sokkp
	pop	d
	push	d
	call	showsok
	pop	d
	pop	b
	inr	e
	mvi	a,001$00$000b	; socket BSB incr value
	add	d
	mov	d,a
	djnz	show0
	lda	count
	ora	a
	cz	nocfg

	jmp	exit

; Do not show unconfigured sockets
showsok:
	lda	sokpt
	cpi	31h
	rnz
	lda	count
	inr	a
	sta	count
	mov	a,e
	adi	'0'
	sta	sokn
	lxi	d,sock
	mvi	c,print
	call	bdos
	lda	sokpt+1
	call	hexout
	mvi	a,'H'
	call	chrout
	mvi	a,' '
	call	chrout
	lxi	h,sokip
	call	ipout
	mvi	a,' '
	call	chrout
	lda	sokdpt
	mov	d,a
	lda	sokdpt+1
	mov	e,a
	call	dec16
	mvi	a,' '
	call	chrout
	lda	sokkp
	call	mult5
	call	dec16
	call	crlf
	ret

nocfg:	lxi	d,ncfg
	mvi	c,print
	call	bdos
	ret

nodcfg:	lxi	d,ndcfg
	mvi	c,print
	call	bdos
	ret

hwout:
	mvi	b,6
	mvi	c,':'
hw0:	mov	a,m
	call	hexout
	dcr	b
	rz
	mov	a,c
	call	chrout
	inx	h
	jmp	hw0

ipout:
	mvi	b,4
	mvi	c,'.'
ip0:	mov	a,m
	call	decout
	dcr	b
	rz
	mov	a,c
	call	chrout
	inx	h
	jmp	ip0

chrout:
	push	h
	push	d
	push	b
	mov	e,a
	mvi	c,002h
	call	bdos
	pop	b
	pop	d
	pop	h
	ret

getsts:
	mvi	c,044h
	call	bdos
	ret

getcfg:
	mvi	c,045h
	call	bdos
	ret

crlf:
	mvi	a,CR
	call	chrout
	mvi	a,LF
	call	chrout
	ret

dec16:
	xchg	; remainder in HL
	mvi	c,0
	lxi	d,10000
	call	div16
	lxi	d,1000
	call	div16
	lxi	d,100
	call	div16
	lxi	d,10
	call	div16
	mov	a,l
	adi	'0'
	call	chrout
	ret

div16:	mvi	b,0
dv0:	ora	a
	dsbc	d
	inr	b
	jrnc	dv0
	dad	d
	dcr	b
	jrnz	dv1
	bit	0,c
	jrnz	dv1
	ret
dv1:	setb	0,c
	mvi	a,'0'
	add	b
	call	chrout
	ret

; A=number to print
; leading zeroes blanked - must preserve B
decout:
	push	b
	mvi	c,0
	mvi	d,100
	call	divide
	mvi	d,10
	call	divide
	adi	'0'
	call	chrout
	pop	b
	ret

divide:	mvi	e,0
div0:	sub	d
	inr	e
	jrnc	div0
	add	d
	dcr	e
	jrnz	div1
	bit	0,c
	jrnz	div1
	ret
div1:	setb	0,c
	push	psw	; remainder
	mvi	a,'0'
	add	e
	call	chrout
	pop	psw	; remainder
	ret

; brute-force divide DE by 5
; Return: DE=quotient (remainder lost)
div5:	push	h
	push	b
	xchg
	lxi	b,5
	lxi	d,0
	ora	a
div50:	dsbc	b
	jc	div51
	inx	d
	jmp	div50
div51:	pop	b
	pop	h
	ret

; Multiply A by 5, result in DE
mult5:	xchg	; save HL
	mov	l,a
	mvi	h,0
	dad	h	; *2
	dad	h	; *4
	add	l	; *5
	mov	l,a
	mvi	a,0
	adc	h
	mov	h,a
	xchg	; result to DE, restore HL
	ret

hexout:
	push	psw
	rrc
	rrc
	rrc
	rrc
	call	hexdig
	pop	psw
	;jmp	hexdig
hexdig:
	ani	0fh
	adi	90h
	daa
	aci	40h
	daa
	jmp	chrout

hexbuf:	push	psw
	rrc
	rrc
	rrc
	rrc
	call	hexdbf
	pop	psw
hexdbf:	ani	0fh
	adi	90h
	daa
	aci	40h
	daa
	mov	m,a
	inx	h
	ret

skipb1:	; skip character, then skip blanks
	inx	h
	dcr	b
skipb:	; skip blanks
	mov	a,b
	ora	a
	stc
	rz
skip0:	mov	a,m
	cpi	' '
	rnz	; no carry?
	inx	h
	djnz	skip0
	stc
	ret

; IX=destination
parsmac:
	mvi	c,':'
pm00:
	call	parshx
	rc
	jz	pm1	; hit term char
	; TODO: check for 6 bytes...
	stx	d,+0
	ora	a	; NC
	ret
pm1:
	stx	d,+0
	inxix
	inx	h
	djnz	pm00
	; error if ends here...
	stc
	ret


; C=term char
; returns CY if error, Z if term char, NZ end of text
; returns D=value
parshx:
	mvi	d,0
pm0:	mov	a,m
	cmp	c
	rz
	cpi	' '
	jrz	nzret
	sui	'0'
	rc
	cpi	'9'-'0'+1
	jrc	pm3
	sui	'A'-'0'
	rc
	cpi	'F'-'A'+1
	cmc
	rc
	adi	10
pm3:
	ani	0fh
	mov	e,a
	mov	a,d
	add	a
	rc
	add	a
	rc
	add	a
	rc
	add	a
	rc
	add	e	; carry not possible
	mov	d,a
	inx	h
	djnz	pm0
nzret:
	xra	a
	inr	a	; NZ
	ret

; IX=destination
parsadr:
	mvi	c,'.'
pa00:
	mvi	d,0
pa0:	mov	a,m
	cmp	c
	jz	pa1
	cpi	' '
	jz	pa2
	cpi	'0'
	rc
	cpi	'9'+1
	cmc
	rc
	ani	0fh
	mov	e,a
	mov	a,d
	add	a	; *2
	add	a	; *4
	add	d	; *5
	add	a	; *10
	add	e
	rc
	mov	d,a
	inx	h
	djnz	pa0
pa2:
	; TODO: check for 4 bytes...
	stx	d,+0
	ora	a
	ret

pa1:
	stx	d,+0
	inxix
	inx	h
	djnz	pa00
	; error if ends here...
	stc
	ret

; Parse a 16-bit (max) decimal number
parsnm:
	lxi	d,0
pd0:	mov	a,m
	cpi	' '
	rz
	cpi	'0'
	rc
	cpi	'9'+1
	cmc
	rc
	ani	0fh
	push	h
	mov	h,d
	mov	l,e
	dad	h	; *2
	jc	pd1
	dad	h	; *4
	jc	pd1
	dad	d	; *5
	jc	pd1
	dad	h	; *10
	jc	pd1
	mov	e,a
	mvi	d,0
	dad	d
	xchg
	pop	h
	rc
	inx	h
	djnz	pd0
	ora	a	; NC
	ret

pd1:	pop	h
	ret	; CY still set

; Parse device, A:..P: or LST:
; returns E=0..15,17 or CY if error
parsdv:
	mov	a,b	; chars left
	cpi	2
	rc
	mov	a,m
	sui	'A'
	rc
	mov	e,a
	inx	h
	mov	a,m
	dcr	b
	cpi	':'
	jrnz	pv1	; LST: or error
	inx	h
	dcr	b
	mov	a,e	; must be 0..15
	cpi	16
	cmc
	ret
pv1:
	mov	a,e
	cpi	'L'-'A'
	stc
	rnz
	mvi	a,'S'
	call	check1
	rc
	mvi	a,'T'
	call	check1
	rc
	mvi	a,':'
	call	check1
	rc
	mvi	e,17
	xra	a
	ret

; Tests if A==curr char on cmdlin
; CY if fail, next char if true
check1:
	cmp	m
	stc
	rnz
	mov	a,b
	ora	a
	stc
	rz
	inx	h
	dcr	b
	xra	a
	ret
	

if (SPIDEV eq H8xSPI)
; Get a block of data from NVRAM to 'buf'
; Verify checksum, init block if needed.
nvgetb:
	lxix	nvbuf
	lxi	h,0
	lxi	d,512
	call	nvget
	call	vcksum
	rz	; chksum OK, ready to update/use
	lxi	d,newbuf
	mvi	c,print
	call	bdos
	lxi	h,nvbuf
	mvi	m,0ffh
	mov	d,h
	mov	e,l
	inx	h
	lxi	b,511
	ldir
	ret
endif

; NOTE: this delay varies with CPU clock speed.
msleep:
	push	h
mslp0:	push	psw
	lxi	h,79	; ~1mS at 2.048MHz (200uS at 10.24MHz)
mslp1:	dcx	h
	mov	a,h
	ora	l
	jrnz	mslp1
	pop	psw
	dcr	a
	jrnz	mslp0
	pop	h
	ret
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; These defines should be in a common file...
spi	equ	40h

spi?dat	equ	spi+0
spi?ctl	equ	spi+1
spi?sts	equ	spi+1

NVSCS	equ	10b	; H8xSPI SCS for NVRAM

; Standard W5500 register offsets
GAR	equ	1	; offset of GAR, etc.
SUBR	equ	5
SHAR	equ	9
SIPR	equ	15
PMAGIC	equ	29	; used for node ID

nsock	equ	8
SOCK0	equ	000$01$000b
SOCK1	equ	001$01$000b
SOCK2	equ	010$01$000b
SOCK3	equ	011$01$000b
SOCK4	equ	100$01$000b
SOCK5	equ	101$01$000b
SOCK6	equ	110$01$000b
SOCK7	equ	111$01$000b

SnMR	equ	0
SnCR	equ	1
SnIR	equ	2
SnSR	equ	3
SnPORT	equ	4
SnDIPR	equ	12
SnDPORT	equ	16
SnRESV1 equ     20      ; 0x14 reserved
SnRESV2 equ     23      ; 0x17 reserved
SnRESV3 equ     24      ; 0x18 reserved
SnRESV4 equ     25      ; 0x19 reserved
SnRESV5 equ     26      ; 0x1a reserved
SnRESV6 equ     27      ; 0x1b reserved
SnRESV7 equ     28      ; 0x1c reserved
SnRESV8 equ     29      ; 0x1d reserved
SnTXBUF	equ	31	; TXBUF_SIZE

NvKPALVTR equ	SnRESV8	; where to stash keepalive in NVRAM
SnKPALVTR equ	47	; Keep alive timeout, 5s units

; Socket SR values
CLOSED	equ	00h

; Socket CR commands
DISCON	equ	08h

; Standard NVRAM defines

; NVRAM/SEEPROM commands
NVRD	equ	00000011b
NVWR	equ	00000010b
RDSR	equ	00000101b
WREN	equ	00000110b
; NVRAM/SEEPROM status bits
WIP	equ	00000001b

; Put block of data to NVRAM from 'buf'
; HL = nvram address, DE = length
; Must write in 128-byte blocks (pages).
; HL must be 128-byte aligned, DE must be multiple of 128
nvset:
	push	h
	lxi	h,nvbuf	; HL = buf, TOS = nvadr
	mvi	c,spi?ctl
nvset0:
	; wait for WIP=0...
	mvi	a,NVSCS
	outp	a
	mvi	a,RDSR
	out	spi?dat
	in	spi?dat	; prime pump
	in	spi?dat	; status register
	push	psw
	xra	a
	outp	a	; not SCS
	pop	psw
	ani	WIP
	jrnz	nvset0
	mvi	a,NVSCS
	outp	a
	mvi	a,WREN
	out	spi?dat
	xra	a
	outp	a	; not SCS
	mvi	a,NVSCS
	outp	a
	mvi	a,NVWR
	out	spi?dat
	xthl	; get nvadr
	mov	a,h
	out	spi?dat
	mov	a,l
	out	spi?dat
	lxi	b,128
	dad	b	; update nvadr
	xchg
	ora	a
	dsbc	b	; update length
	xchg
	xthl	; get buf adr
	mov	b,c	; B = 128
	mvi	c,spi?dat
	outir		; HL = next page in 'buf'
	mvi	c,spi?ctl
	xra	a
	outp	a	; not SCS
;	mvi	a,50
;	call	msleep	; wait for WIP to go "1"?
	mov	a,e
	ora	d
	jrnz	nvset0
	pop	h
	ret
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

; A = PMAGIC
shid:	push	psw
	lxi	d,idmsg
	mvi	c,print
	call	bdos
	pop	psw
	call	hexout
	mvi	a,'H'
	call	chrout
	jmp	crlf

; HL = IP addr, DE = prefix msg
ship:	push	h
	mvi	c,print
	call	bdos
	pop	h
	call	ipout
	jmp	crlf

; HL = mac addr
shmac:	push	h
	lxi	d,mcmsg
	mvi	c,print
	call	bdos
	pop	h
	call	hwout
	jmp	crlf

shdrv:	push	h
	push	b
	lda	count
	inr	a
	sta	count
	mvi	a,16
	sub	b
	adi	'A'
	sta	l0
	sta	n0
	mov	a,m
	ani	080h
	jrnz	shdrv1
	lxi	d,ldrv
	mvi	c,print
	call	bdos
shdrv9:	pop	b
	pop	h
	ret
shdrv1:
	mov	a,m
	ani	0fh
	adi	'A'
	sta	n1
	inx	h
	mov	a,m
	lxi	h,n2
	call	hexbuf
	lxi	d,ndrv
	mvi	c,print
	call	bdos
	jr	shdrv9

shlst:	mov	a,m
	cpi	0ffh
	rz
	ani	080h
	lxi	d,llst
	jrz	shlst1
	xchg
	lxi	h,nl1
	ldax	d
	inx	d
	call	hexdbf
	lxi	h,nl2
	ldax	d
	call	hexbuf
	lxi	d,nlst
shlst1:	mvi	c,print
	call	bdos
	lda	count
	inr	a
	sta	count
	ret

	dseg
	ds	40
stack:	ds	0
usrstk:	dw	0

if (SPIDEV eq H8xSPI)
direct:	db	0
endif
cpnet:	db	0
netcfg:	dw	0
count:	db	0

wizmag:	db	0	; used as client (node) ID

comregs:
gw:	ds	4
msk:	ds	4
mac:	ds	6
ip:	ds	4
comlen	equ	$-comregs

sokregs:
sokmr:	ds	4	; MR, CR, IR, SR
sokpt:	ds	2	; PORT
sokmac:	ds	6	; DHAR
sokip:	ds	4	; DIPR
sokdpt:	ds	2	; DPORT
soklen	equ	$-sokregs
sokkp:	ds	1

newsok:
nskpt:	ds	2	; PORT
nskmac:	ds	6	; DHAR
nskip:	ds	4	; DIPR
nskdpt:	ds	2	; DPORT
nsklen	equ	$-sokregs
nskkp:	ds	1	; KPALVTR

nvbuf:	ds	512

;	end
