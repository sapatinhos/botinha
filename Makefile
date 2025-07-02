STAGE0 := stage0.asm
OUT0 := boot

STAGE1 := stage1.asm
OUT1 := stage1

all: clean
	nasm $(STAGE0) -o $(OUT0)
	nasm $(STAGE1) -o $(OUT1)

run: $(OUT0)
	qemu-system-x86_64 -drive format=raw,file=$(OUT0) &

clean:
	rm -f $(OUT0) $(OUT1)

.PHONY: run clean
