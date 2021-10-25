	title 'Requester Network I/O System for ULCnet'
	page	54

;***************************************************************************
;***************************************************************************
;**                                                                       **
;**                        SNIOS FOR ULCNET                               **
;**                                                                       **
;***************************************************************************
;***************************************************************************

;	Developed jointly by:
;
;		Digital Research, Inc.
;		P.O. Box 579
;		Pacific Grove, CA 93950
;	and
;		Keybrook Business Systems, Inc.
;		2035 National Avenue
;		Hayward, CA 94545

;	This SNIOS was written for a Xerox 820 attached to Orange 
;	Compuco's ULCnet network adaptor.  This module transports
;	messages between the NDOS and the low-level data-link software
;	provided by Orange Compuco.  It also contains the physical drivers
;	usually contained in the NIOD module.  This version is not 
;	interrupt-driven and must be linked with PBMAIN.REL.



false	equ	0
true	equ	not false

interrupts	equ	false		; false=polled, true=interrupt-driven
netstats	equ	true		; switch to gather network statistics
slfclkd		equ	true		; supports self-clocked operation

; Linkage information

	public	setbaud,xmit,recv,initu	; NIOD routines called by IPBMAIN
	public	inituart,pgmuart
	public	chkstat,netidle,initrecv
	public	wait,restuart,csniod
	public	dsblxmit
	public	dllbau,netadr

	if	interrupts
	public	enblrecv,dsblrecv
	endif

	extrn	transmit,receive	; IPBMAIN routines and objects
	extrn	gettcode,getrcode
	extrn	csdll,dllon,regshrt
	extrn	terrcnt,parcntr,ovrcntr
	extrn	frmcntr,inccntr

	if	interrupts
	extrn	rtmochk			; IPBMAIN interrupt routines
	extrn	dlisr,reisr,niisr
	endif


; Hardware definitions for the Z80-SIO channel A - For the Xerox 820.

baudsl	equ	03h		; Usable baud rates: 9600, 19.2K asynch.,
baudsh	equ	2ah		; 76.8K, 153.6K, 307.2K self-clocked

				; baud rate capability mask
bauds	equ	(baudsh*100h)+baudsl

baudgen	equ	0		; External baud rate generator register
siocmd	equ	6		; Command/Mode register
siostat	equ	6		; Status register
sioxmit	equ	4		; Transmit register
siorecv	equ	4		; Receive register

xrdybit	equ	2		; Transmit buffer empty status bit
xrdymsk	equ	4		; transmit buffer empty status mask
rrdybit	equ	0		; Receive buffer full status bit
rrdymsk	equ	1		; receive buffer full status mask
carbit	equ	3		; Net Idle detect bit position
carmsk	equ	8		; Net Idle detect mask
errst	equ	030h		; Error flag reset
errbits	equ	070h		; Error bit position mask
pbit	equ	4		; Parity error bit position
pmsk	equ	10h		; parity error mask
obit	equ	5		; Overrun error bit position
omsk	equ	20h		; overrun error mask
fbit	equ	6		; Framing error bit position
fmsk	equ	40h		; framing error mask
selfbit	equ	3		; Self clock bit position
selfmsk	equ	8		; slef clock bit mask
dtron	equ	0eah		; Turn on DTR
dtroff	equ	06ah		; Turn off DTR
enarcv	equ	0c1h		; Enable receive-clock
disrcv	equ	0c0h		; Disable receive clock
enaslf	equ	00fh		; Enable Self-clock mode
disslf	equ	04fh		; Disable Self-clock mode 

; SIO Mode 2 interrupts vector table

siov4	equ	0ff08h		; SIO port A xmit buffer empty
siov5	equ	0ff0ah		; SIO port A external status change
siov6	equ	0ff0ch		; SIO port A receive
siov7	equ	0ff0eh		; SIO port A special receive condition


; Message Buffer Offsets

fmt		equ	0		; format
did		equ	fmt+1		; destination ID
sid		equ	did+1		; source ID
fnc		equ	sid+1		; server function number
siz		equ	fnc+1		; size of message (normalized to 0)
msg		equ	siz+1		; message
buf$len		equ	msg+257		; length of total message buffer

; ULCnet Packet Offsets

ulc$fmt		equ	0		; packet format
ulc$v$circ	equ	ulc$fmt+1	; virtual circuit number
ulc$len$lo	equ	ulc$v$circ+1	; low order of length
ulc$len$hi	equ	ulc$len$lo+1	; high order of length
ulc$fnc		equ	ulc$len$hi+1	; start of message: function code
ulc$msg		equ	ulc$fnc+1	; CP/NET message

; Network Status Byte Equates

active		equ	0001$0000b	; slave logged in on network
rcverr		equ	0000$0010b	; error in received message
senderr		equ	0000$0001b	; unable to send message



	CSEG
BDOS	equ	0005h

NIOS:
	public	NIOS

; Jump vector for SNIOS entry points

	jmp	ntwrkinit	; network initialization
	jmp	ntwrksts	; network status
	jmp	cnfgtbladr	; return config table addr
	jmp	sendmsg		; send message on network
	jmp	receivemsg	; receive message from network
	jmp	ntwrkerror	; network error
	jmp	ntwrkwboot	; network warm boot


rqstr$id	equ	1	; requester ID: must be between 1 and 4
fmt$byte	equ	4bh	; format byte: short format with data-link
				; acknowledge, 153.6K baud self-clocked

	DSEG

; Transport Layer Data

network$error$msg:

	db	0dh,0ah
	db	'Network Error'
	db	0dh,0ah
	db	'$'


; Requester Configuration Table

configtbl:
Network$status:

	ds	1		; network status byte
	db	rqstr$id	; slave processor ID number
	ds	2		; A:  Disk device
	ds	2		; B:   "
	ds	2		; C:   "
	ds	2		; D:   "
	ds	2		; E:   "
	ds	2		; F:   "
	ds	2		; G:   "
	ds	2		; H:   "
	ds	2		; I:   "
	ds	2		; J:   "
	ds	2		; K:   "
	ds	2		; L:   "
	ds	2		; M:   "
	ds	2		; N:   "
	ds	2		; O:   "
	ds	2		; P:   "
	ds	2		; console device
	ds	2		; list device:

; List Buffer Data

	ds	1		;	buffer index

	db	0		;	FMT
	db	0		;	DID
	db	rqstr$id	;	SID 
	db	5		;	FNC
	ds	1		;	SIZ
	ds	1		;	MSG(0)  List number
	ds	128		;	MSG(1) ... MSG(128)


; ULCnet Data Definitions

netadr:	ds	3		;ULCnet network address
dllbau:	ds	2		;baud rate mask

timeval	equ	22		; WAIT routine time constant
				; 12 for 2.5 megahertz Z80
				; 22 for 4.0 megahertz Z80 	

curbaud db	0ffh		; Current baud rate

				
				; table to convert baud number codes
				;   into a bit mask

btbl:	db	1,2,4,8,16,32,64,128


baudtbl:			; async baud rate table

	db	0eh		; 9600 Baud
	db	0fh		; 19200

scbaudt:			; self-clock baud rate table

	db	0		;  62500 Baud - Not implemented
	db	0dh		;  76800 Baud
	db	0		; 125000 Baud - Not implemented
	db	0eh		; 153600 Baud
	db	0		; 250000 Baud - Not implemented
	db	0fh		; 307200 Baud

	if	interrupts
sioiblk	db	030h,14h,4fh,15h,06ah,13h,0c1h,11h,01h,10h,10h,30h
	else
sioiblk	db	030h,14h,4fh,15h,06ah,13h,0c1h,11h,00h,10h,10h,30h
	endif

sioilen	equ	$-sioiblk


	page
;	Network Initialization Routine

ntwrkinit:

	call	csdll			; cold start the data link
	call	dllon			; initialize the SIO drivers
	mvi	a,rqstr$id		; register the id with the data link
	call	regshrt
	xra	a			; return with no error
	ret


;	Return network status byte

ntwrksts:

	lda	network$status
	mov	b,a
	ani	not (rcverr or senderr)
	mov	a,b
	ret


;	Return configuration table address

cnfgtbladr:

	lxi	h,configtbl
	ret

;	Network error routine


ntwrkerror:

	mvi	c,9
	lxi	d,network$error$msg
	call	bdos

	ret

;	Network Warm Boot Routine

ntwrkwboot:				; this entry is unused in this version

	ret


;	Send a Message on the Network
;	Input:  
;		BC=pointer to message buffer
;	Output:
;		A = 0 if successful
;		    1 if failure

sendmsg:

	push	b
	mov	h,b
	mov	l,c

	mvi	m,fmt$byte		;set ulc$net format byte

	inx	h			;reformat source to virtual circuit
	inx	h
	mov	d,m
	dcx	h
	mov	m,d


	inx	h
	inx	h
	mov	b,m			;save function

	inx	h
	mov	e,m			;get size
	mov	m,b			;function=msg(0) in ULC format

	mvi	d,0
	inx	d
	inx	d			;normalize CP/NET to ULC sizes

	dcx	h
	mov	m,d
	dcx	h
	mov	m,e

	pop	b			;restore buffer pointer

	jmp	dl$send			;blast away


;	Receive a Message on the Network
;
;	This routine calls the data-link routine to receive the message,
;	then converts it into ULCnet format.
;
;	Input:
;		BC = pointer to buffer to receive the message
;	Output:
;		A  = 0 if successful
;		     1 if failure

receivemsg:

	push	b			;save buffer pointer

	call	dl$receive		;slurp the message

	pop	h
	mvi	m,1			;FMT = 0 (requester to server)

	inx	h			;DID already = virtual circuit #

	inx	h			;get length
	mov	e,m
	inx	h
	mov	d,m

	dcx	d
	dcx	d			;normalize ULC to CP/NET format

	inx	h
	mov	a,m			;save FNC

	mov	m,e			;format SIZ (<256)

	dcx	h
	mov	m,a			;format FNC

	dcx	h
	xra	a			;set success
	mov	m,a			;assume server always 0

	ret				;CP/NET message formatted form ULCnet



; Data Link Interface Routines


; DL$RECEIVE:  Network Receive Function.
;	Input:
;		BC = Buffer address


dl$receive:

	mov	d,b		; Buffer address in DE for data link
	mov	e,c

rretry:

	xra	a		; Packet mode
	lxi	b,257		; Buffer size
	lxi	h,0		; Infinite wait	
	push	d		; Save buffer address for retry

	call	psrecv		; Initiate Receive and wait for completion

	pop	d		; Restore buffer address
	ora	a
	rz			; Return if no error

	jmp	rretry		; Jump to try again if error 


; DL$SEND: Network Transmit Function
;	Input:
;		BC = Buffer address

dl$send:

	mov	d,b		; Buffer address in DE for data link
	mov	e,c

tretry:	
	
	xra	a		; Packet mode, wait for Net Idle
	push	d		; Save buffer address for retry
	
	call	psxmit		; Initiate Transmit, wait for completion

	pop	d		; Restore buffer address
	ora	a
	rz			; Return if no error

	jmp	tretry		; Jump to retry if error

; PSXMIT:  Transmit the packet pointed at by DE.  If carry flag is set
; 	   then don't wait for the Net to become idle.
;
;	   Returns the completion code in A 
;		0	- Transmission ok and Data Link Ack Received
;			  (In the case of multicast, no Ack required)
;		2	- Transmission OK but no Data Link Ack received.
;
;		4	- Other error.

psxmit:

	call	transmit		; This will transmit, set return code

twait:

	call	gettcode		; A := GETTCODE - Xmit return code
	mov	e,a
	mvi	d,0
	lxi	h,trtbl			; dispatch on the return code
	dad	d
	mov	e,m
	inx	h
	mov	h,m
	mov	l,e
	pchl 

trtbl:

	dw	psxret			; Good transmission
	dw	psxret			; No Data Link Ack
	dw	psxret			; Too many collisions
	dw	psxret			; Transmitter is disabled
	dw	twait			; Transmitter is idle
	dw	twait			; Transmitter is in progress
	dw	twait			; Transmitter is waiting for ack
	
psxret:	

	ret

; PSRECV:  Receive a packet into buffer pointed at by DE.  Length of
; 	   packet must be less than length of buffer in BC. HL is the receive
; 	   timeout count. 
;
;	   Upon return clear the carry bit if a packet received and ACKed.
; 	   Set the carry flag if any error occured.

psrecv:

	call	receive			; Receive.  Return code will be set
	
rwait:

	call	getrcode		; A := GETRCODE

	mov	e,a
	mvi	d,0
	lxi	h,rrtbl			; dispatch on the return code
	dad	d
	mov	e,m
	inx	h
	mov	h,m
	mov	l,e
	pchl

rrtbl:

	dw	rgood			; Good receive
	dw	rbad			; Bad receive
	dw	rbad			; Disabled

	if	not interrupts
	dw	rbad			; Still idle after timeout
	else
	dw	ridle			; Idle
	endif

	dw	rwait			; Inprogress
	dw	rwait			; In progress and for us.
	
	if	interrupts
ridle:

	call	rtmochk			; Check for timeout
	jc	ridle1			; Jump if timeout
	call	wait1			; Wait 1 ms
	jmp	rwait			; Continue to wait if no timeout

ridle1:	

	call	dsblrecv		; Disable the receiver
	stc
	ret				; Return with error
	endif
 	
rgood:

	ana	a
	ret

rbad:

	stc				; Indicate error
	ret	 
	page

; NIOD routines



; SETBAUD:  Set the baud rate based on the baud rate code in A.  Do special 
; 	    logic for self-clocked mode.
;
;	 	0 = 9600 baud
;		1 = 19200 baud
;		9 = 76800 baud self-clock
;		11= 153600 baud self-clock
;		13= 307200 baud self-clock
; 
; If this station cannot handle the requested baud rate, then set
; the carry flag.

setbaud:

	ani	0fh		; mask all but the baud bits
	lxi	h,curbaud	; are we at the current baud rate?
	cmp	m
	rz			; yes-->all done

	mov	b,a		; else-->get baud rate generator value
	ani	7
	mov	e,a
	mvi	d,0

	lxi	h,btbl		; point to vertical-to-horizontal decode
	dad	d		;   table

	if	slfclkd
	mov	a,b
	ani	selfmsk		; is this a self-clocked value?
	jnz	selfclkd
	endif

	mvi	a,baudsl	; get legal baud rate mask
	ana	m
	stc
	rz			; return with error if its an illegal rate

	if	slfclkd
	mvi	a,5		; else-->switch off possible self-clock mode
	out	siocmd
	mvi	a,dtroff	; disable DTR in SIO register 5
	out	siocmd

	mvi	a,4		; disable sync mode in register 4
	out	siocmd
	mvi	a,disslf
	out	siocmd
	endif

	lxi	h,baudtbl	; point to async baud rate table

outbau:

	dad	d		; get async baud rate value
	mov	a,m
	out	baudgen		; load it into the baud rate generator
				; NOTE: This is not a CTC

	lxi	h,curbaud
	mov	m,b		; set current baud byte

	call	wait		; allow the system to reach equilibrium

	ana	a		; return success
	ret

	if	slfclkd
; Throw SIO into self-clocked mode

selfclkd:

	mvi	a,baudsh	; Is this a legal rate?
	ana	m
	stc
	rz			; return an error if not

	mvi	a,4		; enable sync mode in register 4
	out	siocmd
	mvi	a,enaslf
	out	siocmd

	mvi	a,5		; enable DTR in register 5
	out	siocmd
	mvi	a,dtron
	out	siocmd

	lxi	h,scbaudt	; point to baud rate table for self-clock mode
	jmp	outbau		; program the baud rate generator
	endif


; DSBLXMIT:  Disable the transmitter if in self clocked mode

dsblxmit:

	if	slfclkd
	lda	curbaud		; are we in self-clocked mode?
	ani	selfmsk
	rz			; no-->don't bother

	mvi	a,5		; disable SIO from transmitting by disabling 
	out	siocmd		; DTR in register 5
	mvi	a,dtroff
	out	siocmd

	mvi	a,5		; Enable receive by re-enabling DTR
	out	siocmd
	mvi	a,dtron
	out	siocmd
	endif

	ret


; XMIT:  Transmit the byte in A on network A.


xmit:

	if	not interrupts
	push	psw

xmit1:

	in	siostat		; don't overrun the transmitter if we're
	ani	xrdymsk		;  interrupt-driven; wait for TxReady
	jz	xmit1

	pop	psw
	endif

	out	sioxmit		; blast that byte
	ret


; RECV:  Receive a byte from Network A. Set the carry flag if there was
; 	 a receive error.
;
;	 For Z80-SIO receive errors are handled by the special receive
; 	 condition interrupts.

recv:

	if	not interrupts
	call	netidle	
	jc	rto		; set error condition if the net went idle

	in	siostat		; else-->wait until a character is in the
	ani	rrdymsk		;    buffer
	jz	recv

	call	chkstat		; check for receive errors

	else
	ana	a		; clear carry flag
	endif

	in	siorecv		; input the character
	ret

rto:				; set an error

	xra	a
	stc
	ret
	

; CHKSTAT:  Check error status bits of a receive error.  If not error then
; 	    clear the carry flag and return.  Otherwise figure out which
; 	    error occured and increment its counter and set the carry flag.
; 	    Issue an error reset command to the UART.


chkstat:

	mvi	a,1		; get error status from SIO read register 1
	out	siocmd
	in	siostat

	ani	errbits
	rz			; no error occurred-->all done

	if	netstats	; gather statistics on the type of error
	mov	b,a
	ani	pmsk
	jz	np		; not a parity error

	lxi	h,parcntr	; else-->
	call	inccntr		; increment parity error counter

np:

	mov	a,b
	ani	obit
	jz	no		; not an overrun

	lxi	h,ovrcntr	; else-->
	call	inccntr		; increment overrun counter

no:

	mov	a,b
	ani	fbit
	jz	nf		; not a framing error

	lxi	h,frmcntr	; else-->
	call	inccntr		; increment framing error counter

nf:
	endif

	mvi	a,errst		; reset error condition
	out	siocmd
	stc			; signal an error
	ret
		


; NETIDLE:  See if network A is idle. If idle then set the carry flag.

netidle:

	mvi	a,10h		; reset interrupts
	out	siocmd
	out	siocmd		; do it twice to reject glitches on DCD

	in	siostat		; is there a data-carrier detect?
	ani	carmsk
	rz			; yes-->net is in use-->carry flag cleared

	xra	a
	call	setbaud		; net is idle-->reset to hailing rate (9600)
	stc			; set net idle to true
	ret


	if	interrupts

; ENBLRECV:  Enable the channel A receiver interrupts.

enblrecv:

	mvi	a,1		; enable interrupts on all characters
	out	siocmd
	mvi	a,011h		; NOTE: This mask would have to be 015h on
	out	siocmd		;  channel B
	ret

; DSBLRECV:  Disable the channel A receiver interrupts.

dsblrecv:

	mvi	a,1		; Disable interrupts on received characters
	out	siocmd		;   (Keep status interrupts enabled)
	out	siocmd		; NOTE:  Channel B mask is 05h
	ret

	endif


; PGMUART:  Program the Network UART channel

pgmuart:

	if	interrupts
				; The 820 already has the SIO vector address
				; programmed from channel B.  Other 
				; implementations will have to provide linkage
				; to the vector area in the main XIOS, and 
				; load the vector offset into SIO write 
				; register 2

	lxi	h,niisr		; load status interrupt service routine vector
	shld	siov5
	lxi	h,dlisr		; load transmit ISR vector
	shld	siov6
	lxi	h,reisr		; load receiv ISR vector
	shld	siov7
	endif

	lxi	h,sioiblk	; point to SIO initialization block
	mvi	b,sioilen	; length of block
	di

pgm1:

	mov	a,m		; output the block to the SIO
	out	siocmd
	inx	h
	dcr	b
	jnz	pgm1

	ei
	xra	a		; set up hailing baud rate = 9600
	call	setbaud
	ret


; INITUART:  Initialize the uart for network A by issuing a reset command
; 	     and clearing out the receive buffer.

inituart:

	mvi	a,3		; disable the receiver through register 3
	out	siocmd
	mvi	a,disrcv
	out	siocmd

	in	siostat		; is there a garbage byte?
	ani	rrdymsk
	jz	initu		; no-->continue initialization

	in	siorecv		; else-->eat the character
	jmp	inituart	; try again

initu:

	mvi	a,errst		; reset error conditions
	out	siocmd

	mvi	a,3		; re-enable the receiver
	out	siocmd
	mvi	a,enarcv
	out	siocmd

	ret

; INITRECV:  Initialize a receive operation

initrecv:

	call	inituart

	if	interrupts
	call	enblrecv	; enable receiver interrupts
	endif

	ret


; WAIT - Wait 100 micro seconds

wait:

	mvi	a,timeval

w:

	dcr	a		; 04
	ana	a		; 04
	jnz	w		; 12
				; ---
	ret			; 30 T-States total


; RESTUART:  Reinitialize the UART to the way it was in the
;	     original BIOS after completing the network operations


restuart:
	ret			; UART not used except by network


; CSNIOD:  Do any cold start initialization which is necessary.
;	   Must at least return the value of BAUDS
; 	   If the network uses the printer port then set theh carry flag
;	   otherwise clear it.

csniod: 
	
	lxi	b,bauds		; return the legal baud rates
	ora	a		; not using a printer port
	ret


	end
