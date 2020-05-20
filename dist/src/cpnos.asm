; Stub to jump to bootstrap for CP/NOS
; Typical link:
;	;  example for ROM at F000 and RAM data at EC000 (excluded from iamge)
;	LINK CPNOS,CPNDOS,CPNIOS,CPBDOS,CPBIOS[LF000,DEC000]

	extrn	bios

boot:	jmp	bios

	end	boot
