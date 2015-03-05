Linux old kernel
================

[The old Linux kernel source ver 0.11/0.12-0.96](http://www.oldlinux.org)  
[A practical tour to the Linux Kernel](http://bootloader.wikidot.com/linux:kernel:tour)~~

## Doc

[Make image](http://my-zhang.github.io/blog/2014/06/28/make-bootable-linux-disk-image-with-grub2/)  
[Qemu+GDB](http://wwssllabcd.github.io/blog/2012/08/03/compile-linux011/)  

## Pre-requirement

* a linux distribution: fedora, centos, debian, ubuntu and mint
* some tools: gcc gdb qemu vi
* a linux-0.11 hardware image file 'hdc-0.11.img' which also can be download from http://oldlinux.org/Linux.old/bochs, and put it in the root directory.

## Build
```bash
    $ make

    $ tar xjf hdc-0.11.img.tar.bz2   <<< get root-image filesystem
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

