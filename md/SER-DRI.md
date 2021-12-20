### Description

This NIC (serial protocol driver) implements the CP/NET
serial protocol defined by the Digital Research reference
implementation of the SNIOS.

In this protocol, the CP/NET header is sent
separately, with a separate checksum and sync/acknowledge.

The server should support the following special messages, which
are not actually sent to a CP/NET server but are processed by
the serial port proxy.

#### Initialize and get node ID:

    00 00 00 FF 00 00 (request)
    01 NN 00 FF 00 00 (response, NN=client node ID)

The proxy performs any required initialization and then responds
after filling in the client node ID.

#### Shutdown:

    00 00 00 FE 00 00 (request)
    (no response)

The proxy performs any required shutdown actions, such as closing
any open sockets to CP/NET servers and releasing resources.

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
