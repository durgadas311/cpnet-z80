; nil SNIOS
;
	public	NTWKIN, NTWKST, CNFTBL, SNDMSG, RCVMSG, NTWKER, NTWKBT, NTWKDN, CFGTBL

	cseg

;	Slave Configuration Table
CFGTBL:
	db	0

;	Utility Procedures
;
CNFTBL:
	lxi	h,0
NTWKIN:
NTWKST:
SNDMSG:
RCVMSG:
NTWKER:
NTWKBT:
NTWKDN:
	xra	a
	ret

	end
