On CP/M 2.2, CP/NET is started by typing the command "cpnetldr".
This should result in a load map being printed and return to the command prompt.

Once CP/NET is loaded, the normal CP/NET commands are used to map drives, etc.

CP/NET 1.2 cannot be unloaded.
A RESET (or power cycle) and reboot is required to return to normal CP/M.
This means that (on w5500 systems) the sockets are not cleanly shutdown.
On some systems, RESET leaves the sockets initialized and open.
The command "netdown" is provided to close all server connections
(shut down the network).
At that point, the system may be RESET or powered off without leaving
any open connections on servers. Pressing any key will resume CP/NET
(return to the prompt), and re-open connections as needed.

A sample CP/NET 1.2 session follows, where local drive P: is mapped to
server 00 drive C: and file details are printed.

```
A>cpnetldr


CP/NET 1.2 Loader
=================

BIOS         EB00H  1500H
BDOS         DD00H  0E00H
SNIOS   SPR  D900H  0400H
NDOS    SPR  CD00H  0C00H
TPA          0000H  CD00H

CP/NET 1.2 loading complete.

A>network p:=c:

A>dir p:
P: PRE422   ASM : ROM422   SYM : ROM422   ASM : ROM422   PRN
P: SUF422   ASM : NET422   ASM : ROM422   HEX
A>stat p:*.*

 Recs  Bytes  Ext Acc
  180    32k    1 R/W P:NET422.ASM
   90    16k    1 R/W P:PRE422.ASM
  423    64k    1 R/W P:ROM422.ASM
  102    16k    1 R/W P:ROM422.HEX
  843   112k    1 R/W P:ROM422.PRN
   37    16k    1 R/W P:ROM422.SYM
  154    32k    1 R/W P:SUF422.ASM
Bytes Remaining On P: 2048k

A>netdown
Ready for RESET/power-off
(press any key to resume CP/NET)
```
