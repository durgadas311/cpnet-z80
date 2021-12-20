### Description:

The [MinZ-U Z180](http://www3.telus.net/public/wsm/MinZ180.pdf)
"minimal" system may be used with a CpnetSerialServer attached to
the second serial port (ASCI1).

This system contains a 512K EEPROM, 512K RAM, and the Z80S180 CPU
(with built-in peripherals).
It is neatly packaged on a 2"x2" PCB and is powered via the (single) USB
cable, which provides tty access to both serial ports.

### Building

`make NIC=ser-dri HBA=minz`

To get a binary build tree in a non standard (.bld) directory.

`make BUILD=/path/to/build/top [...]`

### Using

Use with CpnetSerialServer.jar with the **cpnet_protocol** property
(or **proto=** commandline option) set to **DRI**.
Serial speed is 115200 baud.
Tested properties are:
```
cpnet_protocol = dri
dri_ack_timeout = 100
dri_char_timeout = 100
cpnet_flow_control = rts/cts
```

The special command CPNBOOT.COM, which should be part of the
standard delivered files on the MinZ-U, may be used to
boot CP/NET off the server.
This requires additional properties to setup the network boot
feature:
```
netboot_dir = /some/path/to/boot/files
netboot_org0 = none
```

The `/some/path/to/boot/files` directory should contain the
`snios.spr` and `ndos.spr` files produced by this build.
Then, run the command "p:cpnboot" on the MinZ to start CP/NET.

### Caveat's




