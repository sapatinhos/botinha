SRC			:= $(wildcard *.asm)
BIN			:= $(SRC:.asm=.bin)

DISK		:= disk.img
DISKSZ	:= 64M
BOOTSEC := stage0.bin

PARTNUM := "s1"
PARTSZ	:= 32M
PARTTYP	:= '!0x5a'
PARTSEC	:= stage1.bin

.DELETE_ON_ERROR:

# binaries --------------------------------------------------------------------

all: $(BIN)

%.bin: %.asm
	nasm $< -o $@

# emulation -------------------------------------------------------------------

$(DISK): $(BIN)
	truncate -s $(DISKSZ) $(DISK)
	sudo sh -c '\
		MDDEV=$$(mdconfig -a -t vnode -f $(DISK)) && \
		trap "mdconfig -d -u $$MDDEV" EXIT && \
		dd if=$(BOOTSEC) of=/dev/$$MDDEV bs=512 oflag=sync status=progress && \
		gpart add -s $(PARTSZ) -t $(PARTTYP) /dev/$$MDDEV && \
		newfs_msdos -B ./$(PARTSEC) -F 16 $$MDDEV$(PARTNUM) && \
		mount -t msdosfs /dev/$$MDDEV$(PARTNUM) /mnt && \
		cp loader.bin /mnt/loader && \
		umount /mnt \
	'

run: $(BIN) $(DISK)
	qemu-system-x86_64 -drive format=raw,file=$(DISK)

# -----------------------------------------------------------------------------

clean:
	rm -f $(BIN) $(DISK)

.PHONY: all run clean
