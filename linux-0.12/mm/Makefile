CC	=gcc -m32
CFLAGS	=-O0 -g3 -fstrength-reduce -fno-stack-protector -fno-builtin -fomit-frame-pointer \
	-finline-functions -nostdinc -I../include -Wall #-Wall
AS	=as --32
AR	=ar
LD	=ld -m elf_i386
CPP	=gcc -E -nostdinc -I../include
NASM 	=nasm
NMFLAGS =-f elf32

.c.o:
	$(CC) $(CFLAGS) \
	-c -o $*.o $<
.s.o:
	$(AS) -o $*.o $<
.c.s:
	$(CC) $(CFLAGS) \
	-S -o $*.s $<

OBJS	= memory.o swap.o page.elf32

all: mm.o

mm.o: $(OBJS)
	$(LD) -r -o mm.o $(OBJS)

page.elf32:
	$(NASM) $(NMFLAGS) page.asm -o page.elf32

clean:
	rm -f core *.o *.a tmp_make
	rm -f *.elf32
	for i in *.c;do rm -f `basename $$i .c`.s;done

dep:
	sed '/\#\#\# Dependencies/q' < Makefile > tmp_make
	(for i in *.c;do $(CPP) -M $$i;done) >> tmp_make
	cp tmp_make Makefile

### Dependencies:
memory.o : memory.c ../include/signal.h ../include/sys/types.h \
  ../include/asm/system.h ../include/linux/sched.h ../include/linux/head.h \
  ../include/linux/fs.h ../include/linux/mm.h ../include/linux/kernel.h \
  ../include/sys/param.h ../include/sys/time.h ../include/time.h \
  ../include/sys/resource.h 
swap.o : swap.c ../include/string.h ../include/linux/sched.h \
  ../include/linux/head.h ../include/linux/fs.h ../include/sys/types.h \
  ../include/linux/mm.h ../include/linux/kernel.h ../include/signal.h \
  ../include/sys/param.h ../include/sys/time.h ../include/time.h \
  ../include/sys/resource.h 
