stage0:
	nasm stage0.asm

clean:
	rm -rf stage0

.PHONY: stage0 clean
