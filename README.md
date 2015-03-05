Linux-0.11
==========

The old Linux kernel source ver 0.11 run on Qemu of Fedora 21.

## Doc

[Make image](http://my-zhang.github.io/blog/2014/06/28/make-bootable-linux-disk-image-with-grub2/)  
[Qemu+GDB](http://wwssllabcd.github.io/blog/2012/08/03/compile-linux011/)  

## Pre-requirement

* a linux distribution: debian , ubuntu and mint are recommended
* some tools: gcc gdb qemu
* a linux-0.11 hardware image file: hdc-0.11.img, please download it from http://www.oldlinux.org, or http://mirror.lzu.edu.cn/os/oldlinux.org/, ant put it in the root directory.

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

