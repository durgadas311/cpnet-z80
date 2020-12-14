# cpnet-z80
[CPNET-Z80](CPNET-Z80.md) is a port/implementation of DRI CP/NET with drivers for the following
environments:

NIC | HBA | Description
----|-----|------------
[w5500](W5500.md) | [h8xspi](H8XSPI.md) | Heathkit H8/H89 with WIZ850io and NVRAM
[w5500](W5500.md) | [mt011](MT011.md) | RC2014 with MT011 and Featherwing W5500
[w5500c](W5500.md) | [z180csio](Z180CSIO.md) | SC126 Z180 with W5500 breakout board
[serial](SERIAL.md) | [ft245r](FT245R.md) | Serial over FT245R USB module, simple protocol
[serial](SERIAL.md) | [rc-siob](RC-SIOB.md) | Serial support via FTDI cable for SC131
[ser-dri](SER-DRI.md) | [ft245r](FT245R.md) | Serial over FT245R USB module, DRI protocol
[ser-dri](SER-DRI.md) | [ins8250](INS8250.md) | DRI serial protocol over INS8250-like UART
[ser-dri](SER-DRI.md) | [kaypro](KAYPRO.md) | DRI serial protocol on Kaypro Z80-SIO UART
[vcpnet](VCPNET.md) | null | Virtual CP/NET pseudo device

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

Prebuilt packages for the Heathkit H8/H89 W5500 are available
[here](http://sebhc.durgadas.com/mms89/wiz850io/).

Prebuilt packages for the Kaypro (Serial Data port) are available
[here](http://sebhc.durgadas.com/kaypro/).

Prebuilt packages for other architectures are TBD.

## [Running CP/NET3](CPNET3.md)

## [Running CP/NET 1.2](CPNET12.md)

## How to [build](BUILD.md) your own.

## How to [develop](DEVEL.md) a new platform.

### [Running CP/NET](RUN-RC2014.md) on RC2014.

## CP/NET on SC131 and friends (serial port) *

The SC131 and for that matter all Z180 solutions that use the onboard ACSI sio ports will run into trouble with the
missing modem control signals for port b.  They are simply not supplied to the out side world, (sort of), the important
one is hijacked by the SD driver (RomWBW) and the way the board is layed out.

Good news is it works at 57600, so to run cpnet on your SC131, do the following.
Install and build as above.  make NIC=serial HBA=rc-siob

Your next test is to configure the B port as follows. b:mode com1: 57600,n,8,1

Then set up the ~/cpnet-z80/contrib/CpnetSerialServer config file. 
cpnet_tty=/dev/ttyUSB2 57600 
cpnet_proto=BINARY
cpnet_cid=01
cpnet_server03=HostFileBdos

Start the server with ./serialserver conf=config
then start the CP/M network with the following.
b:pip a:=c:ccp.spr
cpnetldr
network k:=c:[3]

See server documentation for further details.


From here you can copy/run/what ever the files on your pseudo drives.  You can also
copy/install from the pseudo drive.  In addition any file you copy to the pseudo drive
on your server system will be accessable instantly on your CP/M system.

