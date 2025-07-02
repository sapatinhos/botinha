SRC := stage0.asm
BIN := boot

$(BIN): clean
	nasm $(SRC) -o $(BIN)

run: $(BIN)
	qemu-system-x86_64 -drive format=raw,file=$(BIN) &

clean:
	rm -f $(BIN)

.PHONY: run clean
