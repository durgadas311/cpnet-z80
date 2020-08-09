## Developing in cpnet-z80

The general source-code directory hierarchy for platform build
configuration is:
```
src/
    config.lib
    $(NIC)/
        config.lib
    $(HBA)/
        config.lib
```
`config.lib` files are required for every NIC and HBA, although they
may be empty.

The `config.lib` files are concatinated in the order:
```
src/config.lib src/$(NIC)/config.lib src/$(HBA)/config.lib
```
The resulting file in placed in the build directory and used
by various source files to define platform configuration.

The NIC subdirectory typically contains the `snios.asm` file,
since that is generally shared between different hardware implementations.
The HBA subdirectory typically contains customization variables
in `config.lib`, and a `chrio.asm` module in the case of
serial port NICs.

## Supporting new hardware

Ideally, adding support for new hardware requires adding
only a new HBA subdirectory (with files) and no other changes.

### Serial Port Based

For adding a new serial port/platform that uses one of the
existing serial protocols (`serial` or `ser-dri`), it should be sufficient
to only add a new HBA subdirectory with `config.lib` and `chrio.asm` files.

### WizNET W5500 Based

For the `w5500` NIC, adding new hardware support may become more complicated.
Firstly, `w5500` requires that the HBA support "burst mode", that is, it
allows the use of Z80 block I/O instructions.

If the platform supports an NVRAM module to store network configuration,
additional utilities may need to be added, which typically requires
customization of the Makefile. Currently, many of the W5500 utilities
are compiled differently depending on whether the platform has NVRAM.

The W5500 HBAs currently are very similar.
The `snios.asm` currently only checks for whether the SPI
read data port is the same as the write data port (an anomaly of
the MT011). Other differences in HBAs may require adding more conditionals
to `snios.asm`.

### See also

[Build](BUILD.md) instructions.
