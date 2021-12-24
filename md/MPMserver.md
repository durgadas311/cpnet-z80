# MPMserver

The MP/M Server implementation here uses a resident/banked design,
to minimize common memory used.
The resident portion is entirely contained in resntsrv.asm.
The banked portion is constructed from several source modules:
bnkntsrv.asm, ntwrkrcv.asm, servers.asm, and an nios.asm for
the target NIC/HBA.

The server instantiates N+1 processes, where "N" is the number
of requesters allowed to log in at the same time.
One process is for the network receive operation, and (generally) only accesses
network receive functions.
The other processes act as servers for logged-in requesters,
and only access network send functions. In addition, N message queues
are created and a single mutex queue (to prevent collisions on network hardware
and to control startup/shutdown).

When a requester logs in, it is assigned a server process.
That requester uses the same server process until it logs off
(or is otherwise disconnected).

## CP/M 3 - CP/NET3
This server does not currently support CP/M 3 clients.

## Mutual Exclusion
The server uses a mutex to delay startup of operations until
directed by the user (admin). The program SRVSTART.COM is used to start operation.
This is typically done after the network hardware has been initialized,
and any other preparation performed. The program SRVSTOP.COM may be used
to shutdown network operations (restarting is allowed).

The server also uses a mutex to prevent concurrent access to the network
hardware from multiple server processes. In the case that the network
hardware and the disk I/O system share the same adapter (SDCard and WizNET
on the same SPI adapter), disk I/O must also mutex with network operations.
This compile option causes the MP/M MXDisk mutex to be used for network
operations, which then ensures disk and network operations won't collide.

## System Drive protection
This server provides a method of protecting drive A: from being written by
CP/NET clients. A private R/O vector is maintained in the NETSERVR.RSP
and any CP/NET function that alters files (or directories) will check
this R/O vector against the drive being accessed, and return a "R/O Disk"
error if appropriate.
The server code only sets bit 0, but the value is taken from the configuration
file cfgntwrk.lib and may be changed. It is also possible to make these bits
dynamic, altered by a "protect" program (this has not been implemented).

## NIOS
The NIOS interface is similar to the client SNIOS interface, with some
notable exceptions.

### Ordering
Note that the server always calls RCVMSG and then SNDMSG,
as opposed to the clients which always call SNDMSG and then RCVMSG. This means
that any dependencies between SNDMSG and RCVMSG are reversed, for example
regarding discovery and use of network identifiers.

In addition, it is no longer guaranteed that the calls to SNDMAG and RCVMSG will be paired
(adjacent in time). Each message received is passed to a server process based
on the client node ID, and other messages may be received (or responses sent back)
before that server process completes its request.

### Entry points
In addition to the NTWKDN procedure (added for cpnet-z80),
the NIOS adds a NWPOLL and a NWLOGO entry.

#### NWPOLL
The NWPOLL routine is used to implement polling of the network for received messages.
If NWPOLL returns "true", it will always be directly followed by a call to RCVMSG.
In other words, NWPOLL and RCVMSG are called while holding the mutex. This means that
NWPOLL may setup data which RCVMSG can leverage, such as details of what is
being received. In some implementations, it may be required that NWPOLL is called
before RCVMSG may be called.

Note that MP/M device polling (XDOS function 131) is asynchronous to actually running
the process that was polling. This may preclude the use of NWPOLL for device polling,
or at least may require that NWPOLL be called again after the polling process wakes up.
It will also be necessary for the polling implementation to check the mutex
and skip the poll if it is held. Since the polling is done inside the dispatcher,
it is not possible to use XDOS function calls, so the mutex will have to be examined
directly - but it cannot change while being examined.

#### NWLOGO
The NWLOGO routine is used to shutdown one specific connection (client).
This is called, with the client node ID in A, when the client is logged off
for any reason.
This is in contrast to NTWKDN which effectively disconnects ALL clients
and the network itself (e.g. stops listening for socket connections).
