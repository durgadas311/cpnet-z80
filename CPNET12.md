On CP/M 2.2, CP/NET is started by typing the command "cpnetldr".
This should result in a load map being printed and return to the command prompt.

Once CP/NET is loaded, the normal CP/NET commands are used to map drives, etc.

CP/NET 1.2 cannot be unloaded.
A RESET (or power cycle) and reboot is required to return to normal CP/M.
This means that (on w5500 systems) the sockets are not cleanly shutdown.
On some systems, RESET leaves the sockets initialized and open.

Type the command "netdown" to close all server connections.
At that point, the system may be RESET or powered off without leaving
any open connections on servers. Pressing any key will resume CP/NET, and
re-open connections as needed.
