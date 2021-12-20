On CP/M 3, CP/NET is starting by typing the command "ndos3".
This should result in the message "NDOS3 Started." and return to the command prompt.

Note that the Heathkit versions will automatically configure the W5500 from NVRAM.
Other platforms must perform the W5500 initialization prior to running NDOS3.

With the NDOS3 RSX loaded, the normal CP/NET commands are used to map drives, etc.

CP/NET3 may be shutdown by typing the command "rsxrm ndos3".
This is currently the only way to cleanly close
all connections to servers on w5500 systems.
RESET or power-off will leave connections open,
pending keepalive timeout on the servers.

A sample CP/NET 3 session follows, where local drive N: is mapped to
server 00 drive F: and an assembly of a file is done.
Note that shutting down CP/NET is only necessary when you are going to
power-off or RESET the system, if you need to reclaim TPA,
or are running an application that is not compatible with CP/NET.
```
A>ndos3
NDOS3 Started.

A>network n:=f:

A>dir n:
N: FMTZ89   ASM : FMT500   ASM : Z80      LIB : FMTMAIN  ASM : FMTTBL   ASM 
N: FMTDISP  ASM 
A>rmac n:fmtz89.asm $SZLN
CP/M RMAC ASSEM 1.1
0A6F
038H USE FACTOR
END OF ASSEMBLY

A>date
Mon 10/22/2018 17:05:47
A>dir n: [full]

Scanning Directory...

Sorting  Directory...

Directory For Drive N:  User  0

    Name     Bytes   Recs   Attributes   Prot      Update          Access    
------------ ------ ------ ------------ ------ --------------  --------------

FMT500   ASM    16k     77 Dir RW       None   10/22/18 09:17  10/22/18 09:17
FMTDISP  ASM    16k     46 Dir RW       None   10/22/18 09:17  10/22/18 09:17
FMTMAIN  ASM    64k    392 Dir RW       None   10/22/18 09:17  10/22/18 09:17
FMTTBL   ASM    16k     39 Dir RW       None   10/22/18 09:17  10/22/18 09:17
FMTZ89   ASM    32k    223 Dir RW       None   10/22/18 09:17  10/22/18 17:02
FMTZ89   PRN    64k    417 Dir RW       None   10/22/18 17:05  10/22/18 17:02
FMTZ89   REL    16k     27 Dir RW       None   10/22/18 17:05  10/22/18 17:02
Z80      LIB    16k     47 Dir RW       None   10/22/18 09:17  10/22/18 09:32

Total Bytes     =    240k  Total Records =    1268  Files Found =    8
Total 1k Blocks =    161   Used/Max Dir Entries For Drive N:    9/  64

A>netstat

CP/NET Status
=============
Requester ID = C9H
Network Status Byte = 10H
Device status:
  Drive N: = Drive F: on Network Server ID = 00H
A>srvstat 0

Server Status
=============
Server ID = 00H
Server Status Byte = 10H
Temp Drive = P:
Maximum Requesters = 16
Number of Requesters = 1
Requesters logged in:
  C9H

A>rsxrm ndos3
NDOS3 Ending.
RSX set to remove

A>
```
