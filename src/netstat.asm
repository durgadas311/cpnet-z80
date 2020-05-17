; A version of CPNETSTS that minimizes output

	org	00100h

	jmp	start

l0103h:	db	13,10,'CP/NET Status'
	db	13,10,'============='
	db	13,10,'$'
l012ch:	db	'Requester ID = $'
l013ch:	db	13,10,'Network Status Byte = $'
l0155h:	db	13,10,'Device status:'
	db	13,10,'$'
l016dh:	db	'  Drive $'
l0176h:	db	' = Drive $'
l0180h:	db	' on Network Server ID = $'
l01a2h:	db	'  Console Device = $'
l01b4h:	db	'Console #$'
l01ddh:	db	'  List Device = $'
l01ech:	db	'List #$'
l01hhh:	db	'  All LOCAL$'
l0212h:	db	13,10,'CP/NET has not been loaded.$'

start:
	lxi	h,0
	dad	sp
	shld	usrstk
	lxi	sp,stack
	call	getver
	mov	a,h
	ani	02h
	jz	nocpnt

	lxi	b,l0103h	; Intro
	call	msgout
	call	getcfg
	shld	nettbl
	lxi	b,l012ch	; Req ID (client ID)
	call	msgout
	lhld	nettbl
	inx	h
	mov	c,m
	call	hexout
	lxi	b,l013ch	; Net Sts Byte
	call	msgout
	call	getsts
	mov	c,a
	call	hexout
	lxi	b,l0155h	; Disk device status:
	call	msgout
	xra	a
	sta	count
	sta	curdrv
drvlup:
	lda	curdrv
	cpi	16
	jnc	trycon	; Done with drives A-P...

	mov	l,a
	mvi	h,0
	dad	h	; *2 - 2 bytes per drive
	inx	h
	inx	h	; +2 - 2 bytes before drives
	xchg
	lhld	nettbl
	dad	d
	mov	a,m
	ani	080h
	jz	locdrv	; drive is local...

	push	h
	lda	count
	ora	a
	cnz	crlf
	lxi	h,count
	inr	m
	lxi	b,l016dh	; Drive...
	call	msgout
	lda	curdrv
	adi	'A'
	mov	c,a
	call	chrout
	mvi	c,':'
	call	chrout
	lxi	b,l0176h	; = Drive... i.e. REMOTE
	call	msgout
	pop	h
	push	h
	mov	a,m
	ani	00fh	; remote drive number
	adi	'A'
	mov	c,a
	call	chrout
	mvi	c,':'
	call	chrout
	lxi	b,l0180h	; on server...
	call	msgout
	pop	h
	inx	h
	mov	a,m	; server ID
	mov	c,a
	call	hexout
locdrv:	; Drive is LOCAL...
	lxi	h,curdrv
	inr	m
	jmp	drvlup

trycon:
	lxi	b,00022h
	lhld	nettbl
	dad	b
	mov	a,m
	ani	080h
	jz	trylst

	push	h
	lda	count
	ora	a
	cnz	crlf
	lxi	h,count
	inr	m
	lxi	b,l01a2h	; Console Device = ...
	call	msgout
	lxi	b,l01b4h	; Console #
	call	msgout
	pop	h
	push	h
	mov	a,m
	call	hexdig
	lxi	b,l0180h	; on Network Server ID = 
	call	msgout
	pop	h
	inx	h
	mov	a,m
	mov	c,a
	call	hexout

trylst:
	lxi	b,00024h
	lhld	nettbl
	dad	b
	mov	a,m
	ani	080h
	jz	done

	push	h
	lda	count
	ora	a
	cnz	crlf
	lxi	h,count
	inr	m
	lxi	b,l01ddh	; List Device = 
	call	msgout
	lxi	b,l01ech	; List #
	call	msgout
	pop	h
	push	h
	mov	a,m
	call	hexdig
	lxi	b,l0180h	; on Network Server ID = 
	call	msgout
	pop	h
	inx	h
	mov	a,m
	mov	c,a
	call	hexout
done:
	lda	count
	ora	a
	jnz	exit
	lxi	b,l01hhh
	call	msgout
	jmp	exit

nocpnt:
	lxi	b,l0212h	; CP/NET has not been loaded
	call	msgout
exit:
	lhld	usrstk
	sphl
	ret

chrout:
	mov	e,c
	mvi	c,002h
	call	00005h
	ret

msgout:
	mov	d,b
	mov	e,c
	mvi	c,009h
	call	00005h
	ret

getver:
	mvi	c,12
	call	00005h
	ret

getsts:
	mvi	c,044h
	call	00005h
	ret

getcfg:
	mvi	c,045h
	call	00005h
	ret

crlf:
	mvi	c,13
	call	chrout
	mvi	c,10
	call	chrout
	ret

hexout:
	push	b
	mov	a,c
	rrc
	rrc
	rrc
	rrc
	call	hexdig
	pop	b
	mov	a,c
	call	hexdig
	mvi	c,'H'
	call	chrout
	ret

hexdig:
	ani	0fh
	adi	90h
	daa
	aci	40h
	daa
	mov	c,a
	jmp	chrout

	ds	40
stack:	ds	0
usrstk:	dw	0
count:	db	0
curdrv:	db	0
nettbl:	dw	0

	end
