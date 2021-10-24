# For the 'vcpm' (VirtualCpm.jar) emulation
export CPMDrive_D = $(PWD)
export CPMDefault = d:

.SECONDARY:

CRLFP = unix2dos
CRLF2 = unix2dos -n
VCPM = vcpm

all: server.rsp

%0.asm: %.asm
	unix2dos -n $^ $@

%.rsp: %0.rel
	$(VCPM) link $@=$*0"[os,nr]"

%.rel: %.asm
	$(VCPM) rmac $< '$$SZ'
