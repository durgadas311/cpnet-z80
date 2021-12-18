; default SYSTEM.DAT file for single-console system (e.g. CP/NET Server).
; Based on default$system$data in GENSYS.PLM
;
; If the XIOS support per-process drive protection (R/O vec),
; then the temp$file$drive must not be A: (or any protected drive).
;
; This should be assembled into the binary SYSTEM.DAT,
; and may be used as input to GENSYS (e.g. GENSYS $AR).

; Start of MP/M system data area
mem$top:		db	0ffh	; 64K address space
nmb$cns:		db	1	; 1 console
brkpt$RST:		db	6
sys$call$stks:		db	0ffh	; system call stacks?
bank$switched:		db	0ffh	; bank-switch RAM
z80$cpu:		db	0ffh	; Z80 CPU
banked$bdos:		db	0ffh	; BNKBDOS
xios$jmp$tbl$base:	db	0
resbdos$base:		db	0
mstr$cfg$tbl$addr:	dw	0
xdos$base:		db	0
rsp$base:		db	0
bnkxios$base:		db	0
bnkbdos$base:		db	0
nmb$mem$seg:		db	8	; Max possible memory
			;	base,size,attr,bank
mem$seg$tbl:		db	   0,0c0h,   0,   0
			db	   0,0c0h,   0,   1
			db	   0,0c0h,   0,   2
			db	   0,0c0h,   0,   3
			db	   0,0c0h,   0,   4
			db	   0,0c0h,   0,   5
			db	   0,0c0h,   0,   6
			db	   0,0c0h,   0,   7
breakpoint$vector:	dw	0,0,0,0,0,0,0,0
			ds	16
user$stacks:		dw	0,0,0,0,0,0,0,0
compat$attrs:		db	0ffh	; CP/NET typically needs compat attrs
			ds	23
nmb$records:		dw	0	; filled in by GENSYS
ticks$per$second:	db	50
system$drive:		db	1	; A:
common$base:		db	0c0h
nmb$rsps:		db	0
listcpadr:		dw	0
submit$flags:		dw	0,0,0,0,0,0,0,0
copyright:		db	'COPYRIGHT (C) 1981, DIGITAL RESEARCH '
serial$number:		db	'654321'
max$locked$records:	db	16
max$open$files:		db	16
total$list$items:	dw	0
lock$free$space$adr:	dw	0
total$system$locked$records: db	32
total$system$open$files: db	32
day$file:		db	0ffh
temp$file$drive:	db	'H'-40h	; H: is temp drive
nmb$printers:		db	1	; 1 printer
			ds	43
cmnxdos$base:		db	0
bnkxdos$base:		db	0
tmpd$base:		db	0
console$dat$base:	db	0
bdos$xdos$adr:		dw	0
tmp$base:		db	0
nmb$brsps:		db	0
brsp$base:		db	0
brspl:			dw	0
			dw	0
rspl:			dw	0

			end
