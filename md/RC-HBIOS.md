### Description:

This HBA target implements a serial transport over the device provided by
RomWBW as "SIOB".  Specifics of the serial port are configured in RomWBW.
This version uses direct ROM calls, as opposed to using the standard
RomWBW "rst 1" interfaces. It significantly improves performance.

Direct calls are accomplished by querying RomWBW for specific function
addresses during init, and saving those in the routines that use them.
It is required that those calls be done when the ROM bank is mapped in,
which must be done separately prior to calling. This also requires that
anything in low memory that needs to be accessed must be copied to high
memory prior to switching banks. Hooks are added to SNIOS.ASM that allow
rc-hbios to define a macro that switches banks before invoking the rest
of the code (and switches back to caller's bank after). The includes
copying the msgbuf as needed if in low memory.

### Building

make NIC=ser-dri HBA=rc-hbios

### Using

Use with CpnetSerialServer.jar with the **cpnet_protocol** property
(or **proto=** commandline option) set to **DRI**.

### Caveat's



