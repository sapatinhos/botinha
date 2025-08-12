ASRC			:= $(wildcard *.asm)
CSRC			:= $(wildcard *.c)
AOBJS			:= $(ASRC:.asm=.o)
COBJS			:= $(CSRC:.c=.o)

AS 		:= nasm
LD		:= x86_64-elf-ld
CC		:= x86_64-elf-gcc
CFLAGS 	:= -ffreestanding 
AFLAGS 	:= -f elf64 
LD_SCRIPT := link.ld

KERNEL := kernel.bin

.DELETE_ON_ERROR:

# binaries --------------------------------------------------------------------

all: $(AOBJS) $(COBJS)

%.o: %.asm
	$(AS) $(AFLAGS) $< -o $@

%.o: %.c
	$(CC) $(CFLAGS) -c $< -o $@

$(KERNEL): $(AOBJS) $(COBJS)
	$(LD) -T $(LD_SCRIPT) -o kernel.elf
	objcopy -O binary kernel.elf $(KERNEL)
	rm -f kernel.elf

clean:
	rm -f  *.o  $(KERNEL)

.PHONY: all run clean
