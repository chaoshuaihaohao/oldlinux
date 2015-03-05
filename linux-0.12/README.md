linux-0.12
==========


## Pre-requirement
* Please compile linux-0.11 first!

## Build
```bash
    $ make

    $ tar xjf rootimage-0.12-hd.tar.bz2   <<< get root-image filesystem
    $ make help
    $ make start    <<< boot it on qemu
    $ make debug    <<< debug it via qemu & gdb, you'd start gdb to connect it.

    $ gdb tools/system
    (gdb) target remote :1234
    (gdb) b main
    (gdb) br *0x7c00    <<< CS=0x7C00, this is BIOS load the MBR's address, here bios hand over the control to linux-kernel.
                        <<< So 0x7C00 is the code of bootsec.S
                        <<< check the value of 0x7DFE and 0x7DFF is 0x55 0xAA or not
    (gdb) x/16b 0x7DF0

    (gdb) c
```

