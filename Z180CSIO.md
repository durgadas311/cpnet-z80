### Description

T
### Building

 make NIC=w5500c HBA=z180csio

### Using

The W5500 retains settings during system RESET-reboot.
The W5500 may be reset by software, when required.

##On your CP/M console:
###CP/M 2.2

###CP/M 3.0
c:wizcfg 0 0 <host ip address> 31100 45
c:network k:=c:[0]

##Caveat's

The above assumes you have a server running on a host machine somewhere.
See cpnet-z80/doc/CpnetSocketServer.pdf for information on running the 
server.