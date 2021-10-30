;***************************************************************************
;***************************************************************************
;**									  **
;**	S e r v e r   N e t w o r k   I n t e r f a c e   M o d u l e	  **
;**		RESIDET PORTION						  **
;**									  **
;***************************************************************************
;***************************************************************************

;***************************************************************************
;***************************************************************************
;**									  **
;**	This module performs communication operations on a server	  **
;**	equipped with a WizNET W5500 Ethernet network adaptor.  	  **
;**									  **
;***************************************************************************
;***************************************************************************
	maclib cfgnwif

; Items required in common memory...
bdosadr:
	dw	$-$		; RSP XDOS entry point

; NETWRKIF Process Descriptors and Stack Space
networkio:			; Receiver Process
	dw	0		; link
	db	0		; status
	db	66		; priority
	dw	0		; stack pointer - in banked portion
	db	'NETWRKIO'	; name
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

; Input queue control blocks

qcb$in$0:
	ds	2		; link
	db	'NtwrkQI0'	; name
	dw	2		; msglen
	dw	1		; nmbmsgs
	ds	2		; dqph
	ds	2		; nqph
	ds	2		; msgin
	ds	2		; msgout
	ds	2		; msgcnt
	ds	2		; buffer
 if $-qcb$in$0 <> qcb$in$len
	error	'qcb$in$len wrong'
 endif

qcb$in$1:
	ds	2		; link
	db	'NtwrkQI1'	; name
	dw	2		; msglen
	dw	1		; nmbmsgs
	ds	2		; dqph
	ds	2		; nqph
	ds	2		; msgin
	ds	2		; msgout
	ds	2		; msgcnt
	ds	2		; buffer

qcb$in$2:
	ds	2		; link
	db	'NtwrkQI2'	; name
	dw	2		; msglen
	dw	1		; nmbmsgs
	ds	2		; dqph
	ds	2		; nqph
	ds	2		; msgin
	ds	2		; msgout
	ds	2		; msgcnt
	ds	2		; buffer

qcb$in$3:
	ds	2		; link
	db	'NtwrkQI3'	; name
	dw	2		; msglen
	dw	1		; nmbmsgs
	ds	2		; dqph
	ds	2		; nqph
	ds	2		; msgin
	ds	2		; msgout
	ds	2		; msgcnt
	ds	2		; buffer

qcb$in$4:
	ds	2		; link
	db	'NtwrkQI4'	; name
	dw	2		; msglen
	dw	1		; nmbmsgs
	ds	2		; dqph
	ds	2		; nqph
	ds	2		; msgin
	ds	2		; msgout
	ds	2		; msgcnt
	ds	2		; buffer

qcb$in$5:
	ds	2		; link
	db	'NtwrkQI5'	; name
	dw	2		; msglen
	dw	1		; nmbmsgs
	ds	2		; dqph
	ds	2		; nqph
	ds	2		; msgin
	ds	2		; msgout
	ds	2		; msgcnt
	ds	2		; buffer

qcb$in$6:
	ds	2		; link
	db	'NtwrkQI6'	; name
	dw	2		; msglen
	dw	1		; nmbmsgs
	ds	2		; dqph
	ds	2		; nqph
	ds	2		; msgin
	ds	2		; msgout
	ds	2		; msgcnt
	ds	2		; buffer

; Output queue control blocks

qcb$out$0:
	ds	2		; link
	db	'NtwrkQO0'	; name
	dw	2		; msglen
	dw	nmb$bufs	; nmbmsgs
	ds	2		; dqph
	ds	2		; nqph
	ds	2		; msgin
	ds	2		; msgout
	ds	2		; msgcnt
	ds	qcb$out$buf	; buffer

; Server Configuration Table
CFGTBL:
	db	0		; Server status byte
	db	0		; Server processor ID
	db	nmb$rqstrs	; Max number of requesters supported at once
	db	0		; Number of currently logged in requesters
	dw	0000h		; 16 bit vector of logged in requesters
	ds	16		; Logged In Requester processor ID's
	db	'PASSWORD' 	; login password

	end
