SRC := stage0.asm
BIN := boot

$(BIN):
	nasm $(SRC) -o $(BIN)

run: $(BIN)
	qemu-system-amd64 -drive format=raw,file=$(BIN) &

clean:
	rm -f $(BIN)

.PHONY: run clean
