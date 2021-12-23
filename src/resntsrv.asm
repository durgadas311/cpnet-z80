;***************************************************************************
;***************************************************************************
;**									  **
;**	S e r v e r   N e t w o r k   I n t e r f a c e   M o d u l e	  **
;**		RESIDENT PORTION					  **
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
	maclib	config
	maclib	cfgnwif

; Each SERVRxPR process keeps it's local data on it's stack,
; so that it is re-entrant (same code shared for all procs).
; There is only one receiver process, so the code need not
; be re-entrant.
;
; References to stack data must take into account the current
; stack depth. Each push/pop must be accounted for to compute
; the correct offset to use when referencing stack variables.

; Items required in common memory...
; All must appear exactly in this order, so banked module
; can find/init/use them.

; TODO: to support polling, the NIOS poll routine
; must be in common memory. That may not be possible/practical.

bdosadr:
	dw	$-$		; RSP XDOS entry point

; Network Receive Process Descriptors and Stack Space
networkio:			; Receiver Process
	dw	0		; link
	db	0		; status
	db	66		; priority
	dw	0		; stack pointer - in banked portion
	db	'NetServr'	; name - must match BRS filename
	db	0		; console
	db	0		; memseg - 0=banked portion exists...
	ds	2		; dparm
	ds	2		; thread
	ds	2		; buff
	ds	1		; user code & disk slct
	ds	2		; dcnt
	ds	1		; searchl
	ds	2		; searcha
	ds	2		; PD extent, compat attr
	dw	0		; HL'
	dw	0		; DE'
	dw	0		; BC'
	dw	0		; AF'
	dw	0		; IY
	dw	0		; IX
	dw	0		; HL
	dw	0		; DE
	dw	0		; BC
	dw	0		; AF
	ds	2		; scratch

; Mutex used to control access to the network hardware
; (NIOS interfaces). Process must own this mutex before
; calling the NIOS. Some systems use MXDisk instead.
mx$netwrk:
	dw	0	; LINK
	db	'MXNetwrk'
	dw	0	; MSGLEN (mutex)
	dw	1	; NMBMSGS
	dw	0,0,0,0,0
	dw	0	; BUFFER (owning proc)

; Mutex used to control start/stop of the server.
; NetServr process waits on this before initializing network,
; and checks it for "messages" via G$CMD.
mx$servr:
	dw	0	; LINK
	db	'MXServer'
	dw	0	; MSGLEN (mutex)
	dw	1	; NMBMSGS
	dw	0,0,0,0,0
	dw	0	; BUFFER (owning proc)

; Process Descriptors for all servers
; (one server proc per allowed requester)
SERVR0PR:	; et al.
	dw	0		; link
	db	0		; status
	db	100		; priority
	dw	0		; stack pointer - in banked portion
	db	'SERV','R'+80h,'0P','R'+80h	; name
	db	0		; console
	db	0		; memseg - 0=banked portion exists...
	ds	2		; dparm
	ds	2		; thread
	ds	2		; buff
	ds	1		; user code & disk slct
	ds	2		; dcnt
	ds	1		; searchl
	ds	2		; searcha
	ds	2		; PD extent, compat attr
	dw	0		; HL'
	dw	0		; DE'
	dw	0		; BC'
	dw	0		; AF'
	dw	0		; IY
	dw	0		; IX
	dw	0		; HL
	dw	0		; DE
	dw	0		; BC
	dw	0		; AF
	ds	2		; scratch
	; the rest...
	ds	(nmb$rqstrs-1) * P$LEN

; Input queue control blocks - one per requester.
qcb$in$0:	; et al.
	ds	nmb$rqstrs * qcb$in$len

; Server Configuration Table
CFGTBL:
	db	0		; Server status byte
	db	0ffh		; Server processor ID
	db	nmb$rqstrs	; Max number of requesters supported at once
	db	0		; Number of currently logged in requesters
	dw	0000h		; 16 bit vector of logged in requesters
	ds	16		; Logged In Requester Node ID's
	; Not officially part of config table:
	db	'PASSWORD' 	; login password (DRI convention)
	db	0		; cmd: start/stop server
	dw	0		; exported mutex for network (may be MXDisk).
	dw	def$prot	; initial R/O vector

	end
