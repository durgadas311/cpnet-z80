### Description

This NIC (serial protocol driver) implements the CP/NET
serial protocol designed as a simple protocol for fast
transports such as USB.

The protocol uses ASCII printable characters only.
Synchronization is provided by "++" (begin) and "--" (end)
sequences, with the CP/NET packet (header and data)
in between, encoded in hexadecimal ASCII. The message includes
a 16-bit CRC.

For example, a message from client 1F to server 02
for BDOS function 0E (select disk) for drive D: would be
(including CRC16):

    ++00021F0E0003204D--

### Building

make NIC=serial HBA=xxx

### Using

Use with CpnetSerialServer.jar with the **cpnet_protocol** property
(or **proto=** commandline option) set to **ASCII**.

### Caveat's

There is no ACK/NAK protocol, so this protocol is
best suited for error-free transports such as USB.

This protocol requires twice as many characters be
transmitted compared to a binary protocol.
