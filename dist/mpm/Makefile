# For the 'vcpm' (VirtualCpm.jar) emulation
export CPMDrive_D = $(PWD)
export CPMDrive_E = $(PWD)/tmp
export CPMDefault = d:

.SECONDARY:

CRLFP = unix2dos
CRLF2 = unix2dos -n
VCPM = vcpm

all: server.rsp

tmp/%.asm: %.asm
	@mkdir -p tmp
	unix2dos -n $^ $@

%.rsp: %.rel
	$(VCPM) link $@=$*"[os,nr]"

%.rel: tmp/%.asm
	$(VCPM) rmac e:$* '$$RDPDSZ'
