### Description

Virtual CP/NET Device in a fictitious device for emulators.
It provides a simple client software interface using OUTIR/INIR.
Due to the nature of the transport, no CRC or checksum is used
and data is transfered in binary.

While not strictly enforced, the CP/NET header is generally sent
(or received) in a separate block I/O transfer than the data.
Basically, the receiving end must determine how many characters
are in the data block in order to properly terminate the message.

The device uses two port addresses, data (+0) and control/status (+1).
An output to the control port resets/resyncs the interface, and
the next read of the data port returns the node ID assigned
to the client.

Reading the status port, bit 0 indicates a message is ready
for INIR. The device is always ready for the client to send
a message, however it is possible to get out of sync.
Status bit 1 indicates that the OUTIR has overrun the expected data.
Status bit 2 indicates that the INIR has overrun the available data.

#### Example code for sendmsg:

    ; message address in HL
    sendmsg:
            push    hl
            pop     ix
            ld      c,PORT+0
            ld      b,5 ; CP/NET hdr len
            outir   ; send header
            ld      b,(ix+4) ; msg SIZ field
            inc     b ; len is SIZ+1
            outir   ; send payload
            inc     c ; status port
            inp     a
            and     02h ; send overrun?
            ret     z ; send was OK
            or      0ffh ; flag error
            ret

#### Example code for recvmsg:

    ; buffer address in HL
    recvmsg:
            push    hl
            pop     ix
            ld      c,PORT+0
            inc     c ; status port
            ; this loop should timeout
    recv0:  inp     a
            and     01h ; data available?
            jr      z,recv0
            dec     c ; data port
            ld      b,5 ; CP/NET hdr len
            inir    ; get header
            ; could check overrun, extra sanity
            ld      b,(ix+4) ; msg SIZ field
            inc     b ; len is SIZ+1
            inir    ; get payload
            inc     c ; status port
            inp     a
            and     04h ; recv overrun?
            ret     z ; recv was OK
            or      0ffh ; flag error
            ret

### Building

    make NIC=vcpnet HBA=null

### Using

The message transfer is between two components in
a virtual machine (emulation), and so there is no
server/proxy component provided here as each emulator would
typically require it's own solution.

### Caveat's

