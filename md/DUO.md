### Description

The [Duodyne](https://github.com/lynchaj/duodyne) system provides
a Disk I/O board that implements an SPI bus based on the 
[mt011](https://github.com/markt4311/MT011).  It implements an
ethernet controller based on the
[w5500](https://www.wiznet.io/product-item/w5500/) wiznet chip
and includes a 25LC512-based NVRAM chip on the same SPI bus.

### Building

 make NIC=w5500 HBA=duo

### Using

To run this board with CP/NET, a Duodyne system with a Z80 CPU
processor board and RAM/ROM board are required.  It is assumed that
the system is running [RomWBW](https://github.com/wwarthen/RomWBW) v3.4
or newer.

The Duodyne Disk I/O does not reset the W5500 during system RESET,
so it retains settings during system RESET-reboot.
The W5500 may be reset by software, when required.

## On your CP/M console:

### CP/M 2.2

```
(assumes your cpnet code is installed on the A: drive)
A>wizcfg n F0
A>wizcfg i <client ip address>
A>wizcfg g <gateway ip address>
A>wizcfg s <subnet mask>
A>wizcfg m <client mac address>
A>wizcfg 0 00 <host ip address> 31100
A>cpnetldr
A>cpnetsts
A>network k:=c:[0] (drive letters may vary)
```

### CP/M 3.0

```
(assumes your cpnet code is installed on the A: drive)
A>wizcfg n F0
A>wizcfg i <client ip address>
A>wizcfg g <gateway ip address>
A>wizcfg s <subnet mask>
A>wizcfg m <client mac address>
A>wizcfg 0 00 <host ip address> 31100
A>ndos3
A>cpnetsts
A>network k:=c:[0] (drive letters may vary)
```

## Caveat's

The above assumes you have a server running on a host machine somewhere.
See <https://github.com/durgadas311/cpnet-z80/blob/master/doc/CpnetSocketServer.pdf>
for information on running the server.
