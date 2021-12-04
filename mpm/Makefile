# For the 'vcpm' (VirtualCpm.jar) emulation
export CPMDrive_D = $(PWD)
export CPMDrive_E = $(PWD)/tmp
export CPMDefault = d:

.SECONDARY:

CRLFP = unix2dos
CRLF2 = unix2dos -n
VCPM = vcpm

PREREQ = tmp/z80.lib tmp/cfgnwif.lib

all: $(PREREQ) \
	netservr.rsp netservr.brs srvstart.com srvstop.com
#	netwrkif.brs netwrkif.rsp \
#	server.brs server.rsp

tmp/%.asm: %.asm
	@mkdir -p tmp
	unix2dos -n $^ $@

tmp/z80.lib: ../src/z80.lib
	@mkdir -p tmp
	unix2dos -n $^ $@

tmp/%.lib: %.lib
	@mkdir -p tmp
	unix2dos -n $^ $@

%.com: %.hex
	$(VCPM) hexcom $*

netservr.rsp: resntsrv.rel
	$(VCPM) link $@=resntsrv"[os,nr]"

netservr.brs: bnkntsrv.rel ntwrkrcv.rel servers.rel nios.rel
	$(VCPM) link $@=bnkntsrv,ntwrkrcv,servers,nios"[os,nr]"

netwrkif.brs: bnknwif.rel nios.rel
	$(VCPM) link $@=bnknwif,nios"[os,nr]"

server.brs: bnksrvr.rel
	$(VCPM) link $@=bnksrvr"[os,nr]"

netwrkif.rsp: resnwif.rel
	$(VCPM) link $@=resnwif"[os,nr]"

server.rsp: ressrvr.rel
	$(VCPM) link $@=ressrvr"[os,nr]"

%.hex: tmp/%.asm
	$(VCPM) mac $* '$$AEHDPDSZLE'

%.rel: tmp/%.asm
	$(VCPM) rmac e:$* '$$RDPDSZLE'
