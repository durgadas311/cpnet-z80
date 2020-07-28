### Description

Virtual CP/NET Device in a fictitious device for emulators.
It provides a simple client software interface using OUTIR/INIR.
Due to the nature of the transport, no CRC or checksum is used
and data is transfered in binary.

While not strictly enforced, the CP/NET header is generally sent
(or received) in a separate block I/O transfer than the data.
Basically, the receiving end must determine how many characters
are in the data block in order to properly terminate the message.

### Building

make NIC=vcpnet HBA=null

### Using

The message transfer is between two companents in
a virtual machine (emulation), and so there is no
component provided here as each emulator would
typically require it's own solution.

### Caveat's

