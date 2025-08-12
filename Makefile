KERNEL 	:= kernel.sys
BOOT 	:= botinha
DISK	:= disk.img

PARTNUM := s1

$(KERNEL):
	gmake -C ./kernel $(KERNEL)
	ls -lh
	cp kernel/$(KERNEL) .

$(DISK): $(KERNEL)
	gmake -C ./$(BOOT)  $(DISK)
	cp $(BOOT)/$(DISK) .
	sudo sh -c '\
        MDDEV=$$(mdconfig -a -t vnode -f $(DISK)) && \
        trap "mdconfig -d -u $$MDDEV" EXIT && \
        mount -t msdosfs /dev/$${MDDEV}$(PARTNUM) /mnt && \
        cp $(KERNEL) /mnt/kernel.sys && \
        umount /mnt \
    '

run: $(DISK)
	qemu-system-x86_64 -drive format=raw,file=$(DISK)

# -----------------------------------------------------------------------------

clean:
	make -C ./kernel clean
	make -C ./botinha clean
	rm -f $(KERNEL) $(DISK)
