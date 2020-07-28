### Description:

This HBA target implements a serial transport over
the device provided by RomWBW as "SIOB".
Specifics of the serial port are configured in RomWBW.

### Building

make NIC=ser-dri HBA=rc-siob

### Using

Use with CpnetSerialServer.jar with the **cpnet_protocol** property
(or **proto=** commandline option) set to **DRI**.

### Caveat's



