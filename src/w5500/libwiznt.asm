; Basic WIZNET routines

	public	wizcfg,wizcf0,wizcmd,wizget,wizset,wizclose,setsok,settcp
	public	gkeep,skeep

	maclib	config

	; Caller must supply 'nvbuf'
	extrn	nvbuf
if (SPIDEV eq H8xSPI)
	; Requires linking with NVRAM.REL, for 'wizcfg'...
	extrn	nvget, vcksum
endif

if (SPIDEV eq z180spi)   
	maclib	z180
else
	maclib	z80
endif

; WIZNET CTRL bit for writing
WRITE	equ	00000100b

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
SnRESV1	equ	20	; 0x14 reserved
SnRESV2	equ	23	; 0x17 reserved
SnRESV3	equ	24	; 0x18 reserved
SnRESV4	equ	25	; 0x19 reserved
SnRESV5	equ	26	; 0x1a reserved
SnRESV6	equ	27	; 0x1b reserved
SnRESV7	equ	28	; 0x1c reserved
SnRESV8	equ	29	; 0x1d reserved
SnTXBUF	equ	31	; TXBUF_SIZE

NvKPALVTR equ	SnRESV8	; where to stash keepalive in NVRAM
SnKPALVTR equ	47	; Keep alive timeout, 5s units

; Socket SR values
CLOSED	equ	00h

; Socket CR commands
DISCON	equ	08h

	cseg


;------------------------------------------------------------------------------
if (SPIDEV eq z180spi)   

RTCIO	EQU	0Ch		; RTC LATCH REGISTER ADR
Z180BASE equ	40h
Z180CNTR EQU	Z180BASE + 0Ah	; CSI/O CONTROL
Z180TRDR EQU	Z180BASE + 0Bh	; CSI/O TRANSMIT/RECEIVE


;SD_DEVCNT EQU SDCNT		; NUMBER OF PHYSICAL UNITS (SOCKETS)
OPRREG	EQU	RTCIO		; USES RTC LATCHES FOR OPERATION
OPRDEF	EQU	00001100b	; QUIESCENT STATE (/CS1 & /CS2 DEASSERTED)
OPRMSK	EQU	00001100b	; MASK FOR BITS WE OWN IN RTC LATCH PORT
CS0	EQU	00000100b	; RTC:2 IS SELECT FOR PRIMARY SPI CARD
CS1	EQU	00001000b	; RTC:3 IS SELECT FOR SECONDARY SPI CARD
CNTR	EQU	Z180CNTR
CNTRTE	equ	10h
CNTRRE	equ	20h
TRDR	EQU	Z180TRDR
IOBASE	EQU	OPRREG		; IOBASE
IOSYSTEM equ	0Ch


; reverse or mirror the bits in a byte
; 76543210 -> 01234567
;
; 18 bytes / 70 cycles
;
; from http://www.retroprogramming.com/2014/01/fast-z80-bit-reversal.html
;
; enter :  a = byte
;
; exit  :  a, l = byte reversed
; uses  : af, l

	
lmirror:
	mov	l,a		; a = 76543210
	rlc
	rlc			; a = 54321076
	xra	l
	ani	0AAh
	xra	l		; a = 56341270
	mov	l,a
	rlc
	rlc
	rlc			; a = 41270563
	rrcr	l		; l = 05634127
	xra	l
	ani	66h
	xra	l		; a = 01234567
	mov	l,a
	ret
 
;Lower the SC130 SD card CS using the GPIO address
;
;input (H)L = SD CS selector of 0 or 1
;uses AF

cslower:
	in0	a,(CNTR)	;check the CSIO is not enabled
	ani	CNTRTE+CNTRRE
	jrnz	cslower

	mov	a,l
	ani	01h		;isolate SD CS 0 and 1 (to prevent bad input).    
	inr	a		;convert input 0/1 to SD1/2 CS
	xri	03h		;invert bits to lower correct I/O bit.
	rlc
	rlc			;SC130 SD1 CS is on Bit 2 (SC126 SD2 is on Bit 3).
	out	IOSYSTEM
	ret

;Raise the SC180 SD card CS using the GPIO address
;
;uses AF

csraise:
	in0	a,(CNTR)	;check the CSIO is not enabled
	ani	CNTRTE+CNTRRE
	jrnz	csraise

	mvi	a,0Ch		;SC130 SC1 CS is on Bit 2 and SC126 SC2 CS is on Bit 3, raise both.
	out	IOSYSTEM
	ret


;Do a write bus cycle to the SD drive, via the CSIO
;
;input L = byte to write to SD drive
	
writebyte:
	mov	a,l
	call	lmirror		; reverse the bits before we busy wait
writewait:
	in0	a,(CNTR)
	tsti	CNTRTE+CNTRRE	; check the CSIO is not enabled
	jrnz	writewait

	ori	CNTRTE		; set TE bit
	out0	l,(TRDR)	; load (reversed) byte to transmit
	out0	a,(CNTR)	; enable transmit
	ret

;Do a read bus cycle to the SD drive, via the CSIO
;  
;output L = byte read from SD drive

readbyte:
	in0	a,(CNTR)
	tsti	CNTRTE+CNTRRE	; check the CSIO is not enabled
	jrnz	readbyte

	ori	CNTRRE		; set RE bit
	out0	a,(CNTR)	; enable reception
readwait:
	in0	a,(CNTR)
	tsti	CNTRRE		; check the read has completed
	jrnz	readwait

	in0	a,(TRDR)	; read byte
	jmp	lmirror		; reverse the byte, leave in L and A

 endif       
;------------------------------------------------------------------------------


; Send socket command to WIZNET chip, wait for done.
; A = command, D = socket BSB
; Destroys A
wizcmd:
	push	psw
	mvi	a,WZSCS
	out	spi$ctl
	xra	a
	out	spi$wr
	mvi	a,SnCR
	out	spi$wr
	mov	a,d
	ori	WRITE
	out	spi$wr
	pop	psw
	out	spi$wr	; start command
	xra	a	;
	out	spi$ctl
wc0:
	mvi	a,WZSCS
	out	spi$ctl
	xra	a
	out	spi$wr
	mvi	a,SnCR
	out	spi$wr
	mov	a,d
	out	spi$wr
	in	spi$rd	; prime pump
	in	spi$rd
	push	psw
	xra	a	;
	out	spi$ctl
	pop	psw
	ora	a
	jnz	wc0
	ret

; E = BSB, D = CTL, HL = data, B = length
wizget:
	mvi	a,WZSCS
	out	spi$ctl
	xra	a	; hi adr always 0
	out	spi$wr
	mov	a,e
	out	spi$wr
	mov	a,d
	out	spi$wr
	in	spi$rd	; prime pump
	mvi	c,spi$rd
	inir
	xra	a	; not SCS
	out	spi$ctl
	ret

; HL = data to send, E = offset, D = BSB, B = length
; destroys HL, B, C, A
wizset:
	mvi	a,WZSCS
	out	spi$ctl
	xra	a	; hi adr always 0
	out	spi$wr
	mov	a,e
	out	spi$wr
	mov	a,d
	ori	WRITE
	out	spi$wr
	mvi	c,spi$wr
	outir
	xra	a	; not SCS
	out	spi$ctl
	ret

; Close socket if active (SR <> CLOSED)
; D = socket BSB
; Destroys HL, E, B, C, A
wizclose:
	lxi	h,tmp
	mvi	e,SnSR
	mvi	b,1
	call	wizget
	lda	tmp
	cpi	CLOSED
	rz
	mvi	a,DISCON
	call	wizcmd
	; don't care about results?
	ret

; IX = base data buffer for socket, D = socket BSB, E = offset, B = length
; destroys HL, B, C
setsok:
	pushix
	pop	h
	push	d
	mvi	d,0
	dad	d	; HL points to data in 'buf'
	pop	d
	call	wizset
	ret

; Set socket MR to TCP.
; D = socket BSB (result of "getsokn")
; Destroys all registers except D.
settcp:
	lxi	h,tmp
	mvi	m,1	; TCP/IP mode
	mvi	e,SnMR
	mvi	b,1
	call	wizset	; force TCP/IP mode
	ret

; Get KEEP-ALIVE value
; D=socket BSB
; Return: A=keep-alive value
gkeep:
	mvi	e,SnKPALVTR
	lxi	h,tmp
	mvi	b,1
	call	wizget
	lda	tmp
	ret

; Set KEEP-ALIVE value - only for DIRECT mode
; A=keep-alive time, x5-seconds
; D=socket BSB
skeep:	ora	a
	rz	; do not set, rather than "disable"...
	sta	tmp
	mvi	e,SnKPALVTR
	lxi	h,tmp
	mvi	b,1
	call	wizset
	ret

; restore config from NVRAM
; Buffer is 'nvbuf' (512 bytes)
; Return: CY if no config
wizcfg:
if (SPIDEV eq H8xSPI)
	lxix	nvbuf
	lxi	h,0
	lxi	d,512
	call	nvget
	lxix	nvbuf
	call	vcksum
	stc
	rnz
wizcf0:
	lxix	nvbuf
	lxi	h,nvbuf+GAR
	mvi	d,0
	mvi	e,GAR
	mvi	b,18	; GAR, SUBR, SHAR, SIPR
	call	wizset
	lxi	h,nvbuf+PMAGIC
	mvi	d,0
	mvi	e,PMAGIC
	mvi	b,1
	call	wizset
	lxix	nvbuf+32
	mvi	d,SOCK0
	mvi	b,8
rest0:	push	b
	ldx	a,SnPORT
	cpi	31h
	jnz	rest1	; skip unconfigured sockets
	call	wizclose
	call	settcp	; ensure MR is set to TCP/IP
	ldx	a,NvKPALVTR
	call	skeep
	mvi	e,SnPORT
	mvi	b,2
	call	setsok
	mvi	e,SnDIPR
	mvi	b,6	; DIPR and DPORT
	call	setsok
rest1:	lxi	b,32
	dadx	b
	mvi	a,001$00$000b	; socket BSB incr value
	add	d
	mov	d,a
	pop	b
	djnz	rest0
	xra	a
else
wizcf0:
	stc
endif
	ret

	dseg
tmp:	db	0

	end
