# Assumes PWD = CPMDrive_D

# Default build platform/adapter:
#	h8x/h8xspi/w5500
#	rc2014/mt011/w5500
#	kaypro/vcpnet/vcpnet
PLAT = h8x
HBA = h8xspi
NIC = w5500
# Known NICs:
#	w5500		WizNET W5500 via SPI, various modules
#	mms77422	Magnolia Microsystems MagNET, ca. 1983, deprecated
#	ft245r		USB via Serial port
#	vcpnet		Fictitious device for emulations
# Known HBAs:
#	h8xspi		Heathkit SPI to WIZ850io and NVRAM
#	mt011		RC2014 SPI to Featherwing W5500 module

BUILD = bld

BLD_TOP = $(BUILD)/$(PLAT)/$(HBA)/$(NIC)
BLD_TOP = $(BUILD)/$(NIC)/$(HBA)

BLD_SRC = $(BLD_TOP)/src
BLD_LIB = $(BLD_TOP)/lib
BLD_BIN2 = $(BLD_TOP)/bin/cpnet12
BLD_BIN3 = $(BLD_TOP)/bin/cpnet3

# For the 'vcpm' (VirtualCpm.jar) emulation
export CPMDrive_D = $(BLD_SRC)
export CPMDrive_L = $(BLD_LIB)
export CPMDefault = d:

TARGETS = netstat.com srvstat.com rdate.com tr.com
ND3DEP = ndos3dup.com
LIBS = z80.lib config.lib
DIRS = $(BLD_SRC) $(BLD_LIB) $(BLD_BIN2) $(BLD_BIN3)
CPNLDR = dist/cpnetldr.com
SNDEPS = snios.rel
SNLINK = snios

ifeq ($(NIC),serial)
SNDEPS += chrio.rel
SNLINK = snios,chrio
endif

ifeq ($(NIC),w5500)
TARGETS += wizcfg.com wizdbg.com
WZCDEPS = wizcfg.rel libwiznt.rel
WZCLINK = wizcfg,libwiznt'[oc,nr]'
endif

ifeq ($(HBA),h8xspi)
TARGETS += nvram.com
ND3DEP = ndos3wiz.com
WZCDEPS += libnvram.rel
WZCLINK = wizcfg,libwiznt,libnvram'[oc,nr]'
CPNLDR = $(BLD_SRC)/cpnldr-w.com
endif

# Files in dist subdir:
CPNET = cpnetsts.com dskreset.com endlist.com local.com \
	login.com logoff.com mail.com network.com xsubnet.com
CPN2 = ndos.spr ccp.spr cpnetldr.com $(CPNET)
CPN3 = $(CPNET)

# customize for build host platform
CRLFP = unix2dos
CRLF2 = unix2dos -n
VCPM = vcpm

.SECONDARY:

all: $(DIRS) $(addprefix $(BLD_LIB)/,$(LIBS)) \
	cpnet2 cpnet3

cpnet2: $(addprefix $(BLD_BIN2)/,$(TARGETS) $(CPN2) snios.spr)

cpnet3: $(addprefix $(BLD_BIN3)/,$(TARGETS) $(CPN3) ndos3.com ntpdate.com rsxrm.com)

$(BLD_SRC) $(BLD_LIB) $(BLD_BIN2) $(BLD_BIN3):
	@mkdir -p $@

$(BLD_LIB)/config.lib: src/config.lib src/$(NIC)/config.lib src/$(HBA)/config.lib
	cat $^ | $(CRLFP) >$@

$(BLD_LIB)/%: src/%
	$(CRLF2) $^ $@

$(BLD_BIN3)/%: $(BLD_SRC)/%
	cp -v --update $^ $@

$(BLD_BIN2)/%: $(BLD_SRC)/%
	cp -v --update $^ $@

$(BLD_BIN3)/%: dist/%
	cp -v --update $^ $@

$(BLD_BIN2)/%: dist/%
	cp -v --update $^ $@

$(BLD_SRC)/%.asm: src/%.asm
	$(CRLF2) $^ $@

$(BLD_SRC)/%.asm: src/$(NIC)/%.asm
	$(CRLF2) $^ $@

$(BLD_SRC)/%.asm: src/$(HBA)/%.asm
	$(CRLF2) $^ $@

%/wizcfg.com: $(addprefix %/,$(WZCDEPS))
	$(VCPM) link $(WZCLINK)

%/snios.spr: $(addprefix %/,$(SNDEPS)) %/snios12.rel
	$(VCPM) link "snios=snios12,$(SNLINK)[os,nr]"

%/ndos3wiz.com: %/ndos3wiz.rel %/libwiznt.rel %/libnvram.rel %/libcpnet.rel
	$(VCPM) link ndos3wiz,libwiznt,libnvram,libcpnet'[oc,nr]'

%/ndos3.com: %/ndos3.rel $(addprefix %/,$(SNDEPS)) %/$(ND3DEP)
	$(VCPM) link "ndos3.rsx=ndos3,$(SNLINK)[op,nr]"
	@cp $*/$(ND3DEP) $*/ndos3.com
	$(VCPM) gencom ndos3.com ndos3.rsx

%/ntpdate.com: %/ntpdate.rel $(addprefix %/,$(SNDEPS))
	$(VCPM) link "ntpdate=ntpdate,$(SNLINK)[oc,nr]"

$(BLD_BIN2)/cpnetldr.com: $(CPNLDR)
	cp -v --update $^ $@

%/cpnldr-w.com: %/cpnldr-w.rel %/libwiznt.rel %/libnvram.rel %/libcpnet.rel
	$(VCPM) link cpnldr-w,libwiznt,libnvram,libcpnet'[oc,nr]'

%.com: %.asm
	$(VCPM) mac "$(notdir $?)" '$$SZLL'
	$(VCPM) hexcom "$(notdir $*)"

%.rel: %.asm
	$(VCPM) rmac "$(notdir $?)" '$$SZLL'
