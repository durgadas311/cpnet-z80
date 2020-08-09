## Build cpnet-z80

Builds are performed for a single, specific, target platform (NIC and HBA).
There is currently no make target to build all known/existing
platforms.

### Prerequisites

To build on linux or cygwin you need to install a few packages.

1. Install the dos2unix package, or otherwise provide the 'unix2dos'
   command.  Alternatives that add CR to the lines may be used, but
   require customization of the Makefile (CRLFP and CRLF2 variables).
1. Copy tools/vcpm to a directory on your PATH, and edit it to change
   the JAR variable to match the path to tools/VirtualCpm.jar.
1. Copy tools/vcpmrc into ~/.vcpmrc, and edit it if you want to customize
   the top level (vcpm_root_dir) directory used for the system drives
   (default: ~/HostFileBdos). If you are running the JAVA CP/NET server
   on this system, you should make certain you use a different top-level
   directory or at least ensure the usage is compatible.
1. Create the VCPM root dir, and the "a" subdir.
1. Copy rmac.com, mac.com, link.com, gencom.com, and hexcom.com from
   a known-good CP/M distribution into the "a" subdir. Filenames must
   be lower-case.

To test this setup, type the command "vcpm dir" and you should get a
CP/M directory listing of the "a" subdir.

At this point you should be able to do a make command with the
required flags and you get a `bld` directory with the runable 
binaries in it.

### Example: W5500 on H8/H89
To build for the Heathkit H8/H89 with the H8xSPI adapter with WIZ850io and NVRAM:

1. 'cd' into the repository top-level directory
1. type the command `make` (or `make NIC=w5500 HBA=h8xspi`)

Results will be placed in a `bld` subdirectory:
* CP/NET 1.2 files in `bld/w5500/h8xspi/bin/cpnet12`
* CP/NET 3 files in `bld/w5500/h8xspi/bin/cpnet3`.

### Example: W5500 on RC2014/MT011
To build for the RC2014 with the MT011 adapter with Feathwing WizNET module:

1. 'cd' into the repository top-level directory
1. type the command `make HBA=mt011` (or `make NIC=w5500 HBA=mt011`)

Results will be placed in a `bld` subdirectory:
* CP/NET 1.2 files in `bld/w5500/mt011/bin/cpnet12`
* CP/NET 3 files in `bld/w5500/mt011/bin/cpnet3`.

The location of the `bld` directory may be changed using the
`BUILD` make variable, for example:
```
make NIC=w5500 HBA=mt011 BUILD=~/cpnet-builds
```
