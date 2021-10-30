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
	dw	0	; link
	db	0	; status
	db	100	; priority
	dw	$-$	; initial SP set from BNKSRVR.BRS
	; extended errors and no abort options
	db	'SERV','R'+80h,'0P','R'+80h
	db	0,0ffh,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
	db	0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0

	; the additional processes...
	ds	(nmb$rqstrs-1)*P$LEN

	end
