; This program can be used to remove an RSX that is persistent.
; The RSX must trap function 60 (CALL RSX) and honor sub function 113.
; The RSXPB is defined as:
;
; rsxpb:	db	113	; function code
;		db	1	; num params
;		db	name	; param: name of RSX to remove
;
;	name:	db	'TOREMOVE'	; must be 8 chars, blank padded
;
; This program expects the CCP to format the single commandline
; parameter into the default FCB, which will produce an 8-char
; (actually, 11) blank padded field.
;
; Usage:	RSXRM <name>
; Example:	RSXRM RSXTEST
;
; A compatible RSX must accept BDOS Function 60 RSX Function 113,
; compare it's name to the parameter, and if matching then set
; it's own REMOVE flag.
;
; See RSXTEST.ASM for an example, in the RSXFUN routine.
;
	org	100h
start:
	lxi	d,rsxpb
	mvi	c,60
	call	5
	jmp	0

rsxpb:	db	113
	db	1
	dw	005dh

	end
