On CP/M 3, CP/NET is starting by typing the command "ndos3".
This should result in the message "NDOS3 Started." and return to the command prompt.

With the NDOS3 RSX loaded, the normal CP/NET commands are used to map drives, etc.

CP/NET3 may be shutdown by typing the command "rsxrm ndos3".
This is currently the only way to cleanly close
all connections to servers on w5500 systems.
RESET or power-off will leave connections open,
pending keepalive timeout on the servers.
