### Description

This module implements the SPI-to-W5500 interface
used on Heathkit H8/H89 computers. This interface
includes an NVRAM chip for storing network configuration.

See also [H8XSPI](http://koyado.com/Heathkit/H8_CP_NET_SPI_Wiznet_Network.html)

### Building

make NIC=w5500 HBA=h8xspi

### Using

A compatible server is implemented in CpnetSocketServer.jar.
The utility WIZCFG.COM is used to setup the NVRAM,
and the CP/NET startup code will program the W5500
from NVRAM.

The H8XSPI resets the W5500 during system RESET,
so its settings are lost during system RESET-reboot.
The NVRAM will retain the settings and is automatically
used during CP/NET startup.

### Caveat's

