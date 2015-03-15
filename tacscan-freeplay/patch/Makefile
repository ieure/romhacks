SRC = $(wildcard ????-*.s)
BIN = $(SRC:%.s=%.bin)

all: $(BIN)

%.bin: %.s
	z80asm -o $@ $<

patch: 1711a.cpu-u25

1711a.cpu-u25: $(BIN)
	dd of=$@ if=../orig/$@ bs=1b count=56
	cat 0038-hook.bin >> $@
	dd if=../orig/$@ bs=1b seek=59 of=

clean:
	rm -f *.bin
