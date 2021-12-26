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
CP/NET requesters. A private R/O vector is maintained in NETSERVR.RSP
and any CP/NET function that alters files (or directories) will check
this R/O vector against the drive being accessed, and return a "R/O Disk"
error if appropriate.
The server by default only sets bit 0 (drive A:),
but that value is taken from the configuration
file cfgntwrk.lib and may be changed.
It is also possible to modify the
active R/O vector using the program SRVPROT.COM.

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

## Configuring the build

### Number of Requesters
The number of requesters is set by the symbol 'nmb$rqstrs' in
the NIC config.lib file, for example "src/w5500/config.lib". This number
affects the amount of common memory consumed by NETSERVR.RSP, and so needs
to be kept within reason. In the case of the WizNET W5500 NIC, the maximum
value is 7 based on the architecture of the chip. The total space used by
NETSERVR.RSP is computed as follows:
```
bytes = (nmb$rqstrs + 2) * 26 + (nmb$rqstrs + 1) * 52 + 37
```
Since NETSERVR.RSP is allocated only full pages (256 byte),
this number will be rounded up.

The absolute maximum value is 16, based on how process and queue
names are created (a single hex digit is inserted in the process or queue name).
Larger numbers are theoretically possible, but
will require changes to the initialization code that creates the processes and queues.

This number also affects memory used in the banked part of NETSERVR,
which must also be considered. The amount of banked memory used for
per-requester structures is:
```
bytes = nmb$rqstrs * 7 + (nmb$rqstrs + 1) * 263
```
This is in addition to the rest of the banked code and data for NETSERVR.BRS.

### Mutual Exclusion Granularity
On some systems, such as those using disk devices attached to the same
SPI adapter as the NIC, it is necessary to prevent MP/M from accessing disks while
server processes access the network.
In these cases the symbol 'use$mxdisk' needs to be set to "1"
in the NIC config.lib file, for example "src/w5500/config.lib".
If the network hardware is completely independent of *all* disk
hardware, then this symbol may be set to "0", providing more
concurrency between network and disk operations.

### Polling Network Driver
NOT IMPLEMENTED. A general-purpose scheme for enabling network device polling,
suitable for any/all XIOS implementations, has not been discovered yet.
The symbol 'polling' in the NIC config.lib file should be set to "0".

### Requester R/O Vector
The default drive protection (requester R/O) vector is set to only drive A:
by the symbol 'def$prot' in the file "src/cfgnwif.lib".
If it is necessary to have different drives protected by default -
i.e. if SRVPROT cannot be used to alter the protection after booting -
then this symbol value may be changed to the desired protection.
The symbol value is a 16-bit number where drive A: is represented by
bit 0 and drive P: by bit 15.

No other values should be altered in this file.

## Server Commands

### SRVSTART.COM
This command is used to start the server after boot, or after SRVSTOP.

### SRVSTOP.COM
This command is used to shutdown (stop) the server. The server is restartable.
Note that this will abruptly terminate network connections.
This may have undesirable affects on requesters, depending on the network
implementation.
Ideally, all requesters would have un-mapped all drives and logged off.

### SRVPROT.COM
This command is used to alter the requester R/O vector that protects selected
MP/M drives from being altered by requesters. This vector may be changed at any time,
however active requesters will use whatever value is in effect at the instant
they begin their current operation.

### SRVSTAT.COM
This command displays the CP/NET Server configuration table for the local system.

## Design Details

### Mutexing
NETSERVR creates two mutexes.
'MXServer' is used to "park" the server while waiting for SRVSTART.
'MXNetwrk' is used to control access to the network hardware (NIOS),
unless 'use$mxdisk' is set to "1" (in which case 'MXDisk' is used to control
access to NIOS). The actual mutex being used to control access to the
network hardware is "exported" at offset 31 in the server config table.
This may be used by utilities (e.g. WIZCFG.COM) to prevent collisions
with the server.

### Drive protection
The requester R/O vector is kept at offset 33 in the server config table.
SRVPROT accesses the R/O vector through the server config table address
obtained from the MP/M system data area.

### Server control
The server operation is controlled through a "command byte" at offset 30
in the server config table.
This byte is used in conjunction with the 'MXServer' mutex to start and shutdown
the server.
