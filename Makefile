# Makefile for cpnet-z80.
# General usage: make NIC=xxx HBA=yyy
# Creates build results in $(BUILD)/$(NIC)/$(HBA)

# Some default values.
# Use NIC=xxx HBA=yyy on commandline to override.
HBA = h8xspi
NIC = w5500

# Known NICs:
#	w5500		WizNET W5500 via SPI, various modules.
#	w5500c		WizNET W5500 via z180 CSIO, SC126
#	mms77422	Magnolia Microsystems MagNET, ca. 1983, deprecated.
#	vcpnet		Fictitious device for emulations.
#	serial		Simple serial protocol for reliable transports.
#	ser-dri		Original DRI reference serial protocol, error checking/retry.
# W5500 HBAs:
#	h8xspi		Heathkit SPI to WIZ850io and NVRAM.
#	mt011		RC2014 SPI to Featherwing W5500 module.
#	z180csio	SC126 SPI to W5500 module, NIC=w5500c
# Serial protocol HBAs:
#	rc-siob		RC2014 main serial port
#	ins8250		Serial port via INS8250 (or equiv) UART.
#	kaypro		Kaypro Z80-SIO "serial data" port.
#	ft245r		FTDI USB fifo adapter.
# Null HBA:
#	null		Provides no additional dependencies.

# customize for build host platform
CRLFP = unix2dos
CRLF2 = unix2dos -n
VCPM = vcpm

# Output/build directory.
# Override on commandline using BUILD=/some/path.
BUILD = bld

#############################################################
# Generally, nothing below here should require customization.
# Furthermore, all the above may be done on the commandline.
#############################################################

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

# Files in dist subdir:
CPNET = cpnetsts.com dskreset.com endlist.com local.com \
	login.com logoff.com mail.com network.com xsubnet.com
CPN2 = ndos.spr ccp.spr cpnetldr.com $(CPNET)
CPN3 = $(CPNET)
XCPN3 = ntpdate.com rsxrm.com rsxls.com
XCPN2 = netdown.com cpnboot.com

-include src/$(NIC)/makevars
-include src/$(HBA)/makevars

.SECONDARY:

all: $(DIRS) $(addprefix $(BLD_LIB)/,$(LIBS)) \
	cpnet2 cpnet3

cpnet2: $(addprefix $(BLD_BIN2)/,$(TARGETS) $(CPN2) snios.spr $(XCPN2))

cpnet3: $(addprefix $(BLD_BIN3)/,$(TARGETS) $(CPN3) ndos3.com $(XCPN3))

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

$(BLD_SRC)/platform.asm:
	/bin/echo -e " public platfm\r\nplatfm: db '$(NIC):$(HBA)$$'\r\n end\r" >$@

%/wizcfg.com: $(addprefix %/,$(WZCDEPS))
	$(VCPM) link $(WZCLINK)'[oc,nr]'

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

%/cpnboot.com: %/cpnboot.rel %/platform.rel $(addprefix %/,$(SNDEPS))
	$(VCPM) link "cpnboot=cpnboot,platform,$(SNLINK)[oc,nr]"

$(BLD_BIN2)/cpnetldr.com: $(CPNLDR)
	cp -v --update $^ $@

%/cpnldr-w.com: %/cpnldr-w.rel %/libwiznt.rel %/libnvram.rel %/libcpnet.rel
	$(VCPM) link cpnldr-w,libwiznt,libnvram,libcpnet'[oc,nr]'

%.com: %.asm
	$(VCPM) mac "$(notdir $?)" '$$SZLL'
	$(VCPM) hexcom "$(notdir $*)"

%.rel: %.asm
	$(VCPM) rmac "$(notdir $?)" '$$SZLL'
