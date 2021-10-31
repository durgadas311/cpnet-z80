; Reconstruction of SERVER.RSP for the CP/NET Server.
; Contains code optimizations (macros) that cause a slight
; variation in one code sequence, compared to original SERVER.RSP.
;
	maclib	cfgnwif

; Each SERVRxPR process keeps it's local data on it's stack.
; A template of that data is shown between '?base' and 'stack0'.
;
; References to stack data must take into account the current
; stack depth. Each push/pop must be accounted for to compute
; the correct offset to use when referencing stack variables.

	cseg
; RSP link - "call bdos" address
bdose:	dw	0
; Main process descriptor - "SERVR0PR"
SERVR0PR:
	dw	0		; link
	db	0		; status
	db	100		; priority
	dw	0		; stack pointer - in banked portion
	db	'SERV','R'+80h,'0P','R'+80h ; name "SERVR0PR" with
				; "return errors" (N4') and
				; "no abort" (N7') options.
	db	0		; console
	db	0		; memseg - banked portion exists...
	ds	2		; b
	ds	2		; thread
	ds	2		; buff
	ds	1		; user code & disk slct
	ds	2		; dcnt
	ds	1		; searchl
	ds	2		; searcha
	ds	2		; active drives
	dw	0		; HL'
	dw	0		; DE'
	dw	0		; BC'
	dw	0		; AF'
	dw	0		; IY
	dw	0		; IX
	dw	0		; HL
	dw	0		; DE
	dw	0		; BC
	dw	0		; AF, A = ntwkif console dev #
	ds	2		; scratch

	; the additional processes...
	ds	(nmb$rqstrs-1)*P$LEN

	end
