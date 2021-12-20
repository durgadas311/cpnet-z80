## Developing in cpnet-z80

The general source-code directory hierarchy for platform build
configuration is:
```
src/
    config.lib
    $(NIC)/
        makevars
        config.lib
    $(HBA)/
        makevars
        config.lib
```

`makevars` are optional, but they must contain valid 'make' assignments.
See details in section below.
Be aware that some use "+=" to append new items, and failure to use that
syntax can cause dependencies to fail or incomplete builds.
'makevars' files are included in this order, after defaults are set:
```
src/$(NIC)/makevars
src/$(HBA)/makevars
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

### Recommended git workflow

When starting work, create a side branch to contain the work.
In these examples, that branch is called "newbranch".
These examples are for using the git commandline interface.
Other interfaces to git should have equivalent commands,
or even provide a direct commandline interface.

1. Ensure your clone "master" branch is up-to-date.
```
git fetch origin master
```

2. Switch to new branch.
```
git checkout -b newbranch master
```

Create and test changes on "newbranch", making commits as appropriate/desired.
This branch may be provided to others, for testing and review, by pushing
it to origin: `git push origin newbranch`, making it visible on github and
available to others clones.

If the branch has been pushed to origin, any developer may perform the
following steps to publish it to "master". The following steps would
orinarily be done all at once, to minimize the chance of other
changes being made to "master" remotely and causing interference.

3. When changes are ready to publish, resync "master" with remote.
```
git fetch origin master
```

4. Rebase the new branch onto the latest "master".
```
git checkout newbranch
git rebase master
```
There is a possibility of merge conflicts at this point, those will
need to be fixed and `git rebase --continue` run in order to finish
the rebase.

5. Do a fast-forward merge with "master"
```
git checkout master
git merge newbranch
```

6. Confirm that all is well, then push new "master" to github.
```
git push origin master
```

7. Branches may be deleted, at such point in the future where
they are determined unneeded, using:
```
git branch -D newbranch
```

8. Branches on (that were pushed to) github may be deleted from
a clone using the following command. Use caution, as this may be the last
copy of the branch and it's deletion may impact others.
```
git push origin :newbranch
```


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

### Makevars

The following 'make' variables are typically modified by 'makevars' files:

Variable|Use|Notes
--------|---|----------------------
TARGETS|+=|Additional targets to build, typically COM file utilities. Initially "netstat.com srvstat.com rdate.com tr.com".
SNDEPS|+=|Additional REL files required by SNIOS.REL. Initially "snios.rel".
SNLINK|=|LINK command segment for SNIOS. Will be prefixed with target, suffixed with "[os,nr]" or "[op,nr]". Initially "snios".
ND3DEP|=|The COM file to use as base for NDOS3. Default is 'ndos3dup.com'.
WZCDEPS|+=|Additional REL files to build for WIZCFG (not used unless TARGETS adds "wizcfg.com").
WZCLINK|=|LINK command for WIZCFG. Will be suffixed with "[oc,nr]".
CPNLDR|=|Custom CPNETLDR.COM to build. Default is original "dist/cpnetldr.com".

### See also

[Build](BUILD.md) instructions.

