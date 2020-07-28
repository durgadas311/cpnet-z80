### Description

This NIC (serial protocol driver) implements the CP/NET
serial protocol defined by the Digital Research reference
implementation of the SNIOS.

In this protocol, the CP/NET header is sent
separately, with a separate checksum and sync/acknowledge.

### Building

make NIC=ser-dri HBA=xxx

### Using

Use with CpnetSerialServer.jar with the **cpnet_protocol** property
(or **proto=** commandline option) set to **DRI**.

### Caveat's

The timing for this protocol can be
difficult to tune. It is also highly dependent on
CPU speed. As yet there is no automated method
to configurev the timing, each new platform
may require some trial-and-error.
