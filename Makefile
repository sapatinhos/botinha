SRC			:= $(wildcard *.asm)
BIN			:= $(SRC:.asm=.bin)

DISK		:= disk.img
DISKSZ	:= 1M
BOOTSEC := stage0.bin
PART1F	:= stage1.bin
PART1T	:= '!0x5a'

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
		gpart add -s $$(stat -f %z $(PART1F)) -t $(PART1T) /dev/$$MDDEV && \
		dd if=$(PART1F) of=/dev/$$MDDEV"s1" bs=1M oflag=sync status=progress \
	'

run: $(BIN) $(DISK)
	qemu-system-x86_64 -drive format=raw,file=$(DISK)

# -----------------------------------------------------------------------------

clean:
	rm -f $(BIN) $(DISK)

.PHONY: all run clean
