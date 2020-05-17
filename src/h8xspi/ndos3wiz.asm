; Initialization code for NDOS3 on WIZ850io
; Checks for CP/NET already running, then initializes WIZ850io
;
	maclib	z80

	extrn	wizcfg
	extrn	cpnsetup
	public	nvbuf

cr	equ	13
lf	equ	10

; System page-0 constants
cpm	equ	0
bdos	equ	5

; BDOS functions
print	equ	9
vers	equ	12
; NDOS functions
cfgtbl	equ	69

; RSX is already linked-in, but might be a duplicate

	cseg
	lxi	sp,stack

	lixd	bdos+1	; this should be our NDOS3
	sixd	us
	ldx	l,+4	; next RSX...
	ldx	h,+5	;
	shld	next
	mvi	c,vers
	call	bdose	; by-pass ourself
	mov	a,h
	ani	02h
	jz	ldr3
	lixd	us
	mvix	0ffh,+8	; set remove flag
	; also short-circuit it
	ldx	l,+4	; next RSX...
	ldx	h,+5	;
	stx	l,+1	; by-pass duplicate
	stx	h,+2	;
	; report what happened
	lxi	d,dupmsg
	mvi	c,print
	call	bdos
	jmp	cpm

; hit LOADER3 RSX, no dup found...
ldr3:
	call	wizcfg
	jrc	wizerr
	; This will also cold-start NDOS...
	; hopefully, no bad effects.
	mvi	c,cfgtbl
	call	bdos
	; HL=cfgtbl (check error?)
	lxi	d,nvbuf+288	; 64 bytes for cfgtbl template
	call	cpnsetup
	jmp	cpm
wizerr:
	call	nocfg	; report error, but continue...
	jmp	cpm	; let RSX init itself

nocfg:	lxi	d,ncfg
	mvi	c,print
	jmp	bdos

bdose:	lhld	next
	pchl

	dseg
us:	dw	0	; our copy of NDOS3 (remove if dup)
next:	dw	0

dupmsg:	db	'CP/NET already loaded',cr,lf,'$'
ncfg:	db	'NVRAM not configured',cr,lf,'$'

	ds	64
stack:	ds	0

nvbuf:	ds	512

	end
