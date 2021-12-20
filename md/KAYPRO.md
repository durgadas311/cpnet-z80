### Description:

This HBA target implements a serial transport over a Z80-SIO
serial port.
The default code is configured for the "serial data" Z80-SIO port on
a Kaypro (address 004H), using WD1943 BAUD generator
with a 5.0688 MHz data clock.
For most cases, the changes for different systems are
limited to SERPORT (base port address),
BAUDPRT (WD1943 port),
and SERBAUD (WD1943 value for desired BAUD).

### Building

make NIC=ser-dri HBA=kaypro

### Using

Use with CpnetSerialServer.jar with the **cpnet_protocol** property
(or **proto=** commandline option) set to **DRI**.

### Caveat's



