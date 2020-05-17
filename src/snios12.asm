; SNIOS Prefix (jump table) for CP/NET 1.2 on CP/M 2.2

	maclib z80

	extrn	NTWKIN, NTWKST, CNFTBL, SNDMSG, RCVMSG, NTWKER, NTWKBT, NTWKDN

	cseg
;	Jump vector for SNIOS entry points
	jmp	NTWKIN	; network initialization
	jmp	NTWKST	; network status
	jmp	CNFTBL	; return config table addr
	jmp	SNDMSG 	; send message on network
	jmp	RCVMSG	; receive message from network
	jmp	NTWKER	; network error
	jmp	NTWKBT	; network warm boot
	jmp	NTWKDN	; network shutdown - extension

	end
