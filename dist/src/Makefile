# Makefile for CP/NET 1.2 dist components
# TODO: create CCP.ASM
# Invoked from dist/src

BUILD = ../../bld


BLD_TOP = $(BUILD)/dist

BLD_SRC = $(BLD_TOP)/src
BLD_LIB = $(BLD_TOP)/lib
BLD_BIN = $(BLD_TOP)/bin

# For the 'vcpm' (VirtualCpm.jar) emulation
export CPMDrive_D = $(BLD_SRC)
export CPMDrive_L = $(BLD_LIB)
export CPMDefault = d:

LIBS = z80.lib config.lib
DIRS = $(BLD_SRC) $(BLD_LIB) $(BLD_BIN)

TARGETS = cpnetldr.com ndos.spr

.SECONDARY:

# customize for build host platform
CRLFP = unix2dos
CRLF2 = unix2dos -n
VCPM = vcpm

all: $(DIRS) $(addprefix $(BLD_LIB)/,$(LIBS)) \
	$(addprefix $(BLD_SRC)/,$(TARGETS))

$(BLD_SRC) $(BLD_LIB) $(BLD_BIN):
	@mkdir -p $@

$(BLD_LIB)/%: ../../src/%
	$(CRLF2) $^ $@

$(BLD_SRC)/%.asm: %.asm
	$(CRLF2) $^ $@

%/ndos.spr: %/ndos.rel
	$(VCPM) link "ndos[os,nr]"

# An example, really. For ROM at F000.
#cpnos.com: cpnos.rel cpndos.rel cpbdos.rel cpbios.rel cpnios.rel
#	vcpm link "cpnos,cpndos,cpnios,cpbdos,cpbios[LF000,DEC00]"

%.com: %.asm
	$(VCPM) mac "$(notdir $?)" '$$SZLL'
	$(VCPM) hexcom "$(notdir $*)"

%.rel: %.asm
	$(VCPM) rmac "$(notdir $?)" '$$SZLL'
