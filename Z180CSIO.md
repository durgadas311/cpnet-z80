### Description
This module implements the SPI-to-W5500 interface
using a W5500 breakout board connected to the second SPI
interface on the SC126 Z180 board, the communication uses
the Z180 CSIO

### Building

 make NIC=w5500c HBA=z180csio

The w5500c NIC device is a modified copy of the w5500 driver to work with the
Z180 CSIO interface. It works with the same socket server on the host.
Currently, the only HBA supported on w5500c is z180csio.

### Board wiring

The W5500 breakout board needs to be connected to the SC126 second SPI port.
Connections are:

SC126-SPI-2 | W5000 |
----|-----|
1 | CS|
2 |SCK|
3 |MOSI|
4 |MISO|
5 |Vcc|
6 |Gnd|
N/C |3.3V
N/C |RST|
N/C |INT|
N/C |N/C|
Unused connections are marked N/C.

There is a red power LED on the W5500 module,
There are the usual Ethernet LEDs on the ethernet Jack.

### Using

The distribution files need to be copied onto the target system before use.
Kermit, xmodem, or FAT file copy are suitable tools available from CP/M on RomWBW

There is sufficient room to copy the files onto the boot drive if needed.

The W5500 retains settings during system RESET-reboot.
The W5500 may be reset by software, when required.

The supplied utility wizcfg is used to set the operating settings into the W5500 devece befor use
the format of commands used is show in its help screen:
```
B>wizcfg --version
WIZCFG version 1.4
Usage: WIZCFG {G|I|S} ipadr
       WIZCFG M macadr
       WIZCFG N cid
       WIZCFG {0..7} sid ipadr port [keep]
Sets network config in W5500
Built for SC126 Z180 CSIO
```
If no command line tail is given the a summary of the present settings are shown.
Note the socket IP parameters are not visible until after the socket has been used.

Note, socketserver needs an older version of Java for the
LST: redirection to work properly. JAVA 8 works, but JAVA 11 does not (yet).

I found a link to download Java8 in this article here:
https://tecadmin.net/install-oracle-java-8-ubuntu-via-ppa/
I installed it and modified the socketserver command to use it by invoking it
withthe full path name of the V8 version instead of just java using the default version
see socketserver example in contrib folder

Windows needs an alternative socketserver invocation command,
simple batch files for this are in contrib too.
The java version on my Windows 10 laptop is fine with the defanlt java installation.

## On your CP/M console:
###CP/M 2.2
```
c:wizcfg 0 0 <host ip address> 31100 45
c:cpnetldr
c:network k:=c:[0]
```

###CP/M 3.0
```
c:wizcfg 0 0 <host ip address> 31100 45
c:network k:=c:[0]
```

Note, I found that the CP/M 2.2 version would also work
on CP/M 3 but its better and easier to use the corect version.
This may help to deploy a syemstem initailly where both sets
of files could be copied onto the target system.

## Compatability

The default microsd adapter card used by the SC126
does not release the SPI MISO line when the device
is de-selected, this prevents two SPI devices being used.
A small modification is needed to the
micro sd adapter card to fix this problem.

See discussion here for details:
https://groups.google.com/g/retro-comp/c/fcGZEa91NSc
Another kind of micro SD card or SC126 modifications are alternative solotions.
If no micro SD card is used then no modifications are needed,
the W5500 board can always be used as is.

No modification are needed to the stock RomWBW configuration,
the default single SD drive should
be used allowing the W5500 driver to use the second port.

## Enhancement

A small non volatile memory device could be used to store the w5500 configuration
instead of needing to issue a wizcfg command after a power off reset. On the SC126
an IIC device may be more suitable than the SPI device used on other boards due to
lack of available spare chip select lines.

## Caveats

The above assumes you have a server running on a host machine somewhere.
See cpnet-z80/doc/CpnetSocketServer.pdf for information on running the
server.

David Richards, December 2020.
