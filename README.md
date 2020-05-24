# cpnet-z80
CPNET-Z80 is a port/implementation of DRI CPNET with drivers for the following
environments:

NIC | HBA | Description
----|-----|------------
w5500 | h8xspi | Heathkit H8/H89 with WIZ850io and NVRAM
w5500 | mt011 | RC2014 with MT011 and Featherwing W5500
serial | ft245r | Serial over FT245R USB module, simple protocol
ser-dri | ft245r | Serial over FT245R USB module, DRI protocol
vcpnet | null | Virtual CP/NET pseudo device

Included is support for CP/M 3.

In the case of RC2014 the added ethernet support board is the
[MT011 board](https://github.com/markt4311/MT011) with the
[Featherwing](https://learn.adafruit.com/adafruit-wiz5500-wiznet-ethernet-featherwing)
W5500 module.

If you don't know about the RC2014 you can find info at tindi.com (to buy parts), 
Google group [RC2014-z80](https://groups.google.com/forum/#!forum/rc2014-z80)
and the creator of the RC2014 at www.rc2014.co.uk.

For the Heathkit H8/H89, the board is the H8xSPI with the
[WIZ850io](https://www.wiznet.io/product-item/wiz850io/) W5500 module
and includes an NVRAM chip as well,
used for storing network configuration.
See [H8_CP_NET_SPI](http://koyado.com/Heathkit/H8_CP_NET_SPI_Wiznet_Network.html).

The file [doc/dri-cpnet.pdf](/doc/dri-cpnet.pdf)
contains the original Digital Research CP/NET documentation,
modified to add the CP/M 3 extensions.

The file [doc/CPNET-WIZ850io.pdf](/doc/CPNET-WIZ850io.pdf)
contains specific instructions for the Heathkit H8/H89
CP/NET environment, but it also contains a lot of general information about how
CP/NET is being used on a W5500-based TCP/IP network.

There are also server implementations in the 'contrib' directory, with
documention in 'doc'.

To avoid conflicts of CP/NET node IDs on the internet, a registry scheme is
proposed in [CPNET-registry.md](/CPNET-registry.md).

## Prebuilt packages

Prebuilt packages for the Heathkit H8/H89 are available
[here](http://sebhc.durgadas.com/mms89/wiz850io/).

Prebuilt packages for other architectures are TBD.

## [Running CP/NET3](CPNET3.md)

## [Running CP/NET 1.2](CPNET12.md)

## Build Setup
Here is the setup requirments for building a release package

To setup the build environment:

1. Install the dos2unix package, or otherwise provide the 'unix2dos'
   command.  Alternatives that add CR to the lines may be used, but
   require customization of the Makefile (CRLFP and CRLF2 variables).
1. Copy tools/vcpm to a directory on your PATH, and edit it to change
   the JAR variable to match the path to tools/VirtualCpm.jar.
1. Copy tools/vcpmrc into ~/.vcpmrc, and edit it if you want to customize
   the top level (vcpm_root_dir) directory used for the system drives
   (default: ~/HostFileBdos). If you are running the JAVA CP/NET server
   on this system, you should make certain you use a different top-level
   directory or at least ensure the usage is compatible.
1. Create the VCPM root dir, and the "a" subdir.
1. Copy rmac.com, mac.com, link.com, gencom.com, and hexcom.com from
   a known-good CP/M distribution into the "a" subdir. Filenames must
   be lower-case.

To test this setup, type the command "vcpm dir" and you should get a
CP/M directory listing of the "a" subdir.

## Building CP/NET
And to build the release package:

### H8/H89
To build for the Heathkit H8/H89 with the H8xSPI adapter with WIZ850io and NVRAM:

1. 'cd' into the repository top-level directory
1. type the command "make" (or "make NIC=w5500 HBA=h8xspi")

Results will be placed in a "bld" subdirectory:
* CP/NET 1.2 files in "bld/w5500/h8xspi/bin/cpnet12"
* CP/NET 3 files in "bld/w5500/h8xspi/bin/cpnet3".

### RC2014
To build for the RC2014 with the MT011 adapter with Feathwing WizNET module:

1. 'cd' into the repository top-level directory
1. type the command "make HBA=mt011" (or make NIC=w5500 HBA=mt011")

Results will be placed in a "bld" subdirectory:
* CP/NET 1.2 files in "bld/w5500/mt011/bin/cpnet12"
* CP/NET 3 files in "bld/w5500/mt011/bin/cpnet3".

### Virtual CP/NET Device
A fictitious device for emulators. Simple software interface using OUTIR/INIR.

* make NIC=vcpnet HBA=null

### FT245R USB (serial)
[FT245R](https://www.ftdichip.com/Products/ICs/FT245R.htm) FIFO/parallel to USB chip,
using an ASCII hex-encoded protocol with CRC.

* make NIC=serial HBA=ft245r

## Additional Notes
The destination build directory (default "./bld") may be specified using the
'make' variable BUILD. For example:

* make BUILD=/path/to/build/top [...]

### Running CPNET on RC2014.

First, required hardware.  RC2014 with ROM/RAM board, RomWBW installed, RTC or a CTC to generate
time keeping interupts, MT011 wiznet board.

The following assume that you are running CP/M 2.2 or ZSDOS.

Here is a submit file helpful for starting cpnet on your CP/M 2.2 system.  Pay attention to the
notes.
```
C>type cpnet.sub
c:ifconfig
^^^^^^^^^^^^  this is a program that sets up the MT011 board, find it at 
	      https://github.com/jayacotton/inettools-z80
b:pip a:=c:ccp.spr
^^^^^^^^^  I assume that the cpnet kit is installed on your c drive.
c:cpnetldr
c:wizcfg 0 0 192.168.0.120 31100 45
^^^^^^^^^^^^^^this address will need to adjusted for your local server.
c:network k:=c:[0]
^^^^^^^^^^^^^^ I publish 2 pseudo drives on my local server.
c:network l:=d:[0]
^^^^^^^^^^^^^^  And these drive letters are not going to work for everyone.
```
After running the submit file, you should be configured for CPNET.  You can run cpnetsts
to check that everything is working.  You will also see activity on your local server
talking about the connection.

C>cpnetsts
```
CP/NET 1.2 Status
=================
Requester ID = 03H
Network Status Byte = 13H
Disk device status:
  Drive A: = LOCAL
  Drive B: = LOCAL
  Drive C: = LOCAL
  Drive D: = LOCAL
  Drive E: = LOCAL
  Drive F: = LOCAL
  Drive G: = LOCAL
  Drive H: = LOCAL
  Drive I: = LOCAL
  Drive J: = LOCAL
  Drive K: = Drive C: on Network Server ID = 00H
  Drive L: = Drive D: on Network Server ID = 00H
  Drive M: = LOCAL
  Drive N: = LOCAL
  Drive O: = LOCAL
  Drive P: = LOCAL
Console Device = LOCAL
List Device = LOCAL
```

From here you can copy/run/what ever the files on your pseudo drives.  You can also
copy/install from the pseudo drive.  In addition any file you copy to the pseudo drive
on your server system will be accessable instantly on your CP/M system.

