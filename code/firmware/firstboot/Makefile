VASM=vasm6502_oldstyle 
ASFLAGS=-c02 -Fbin 

all: rom.bin

boot64k.bin: boot.asm
	$(VASM) $(ASFLAGS) -L boot64k.lst -o $@ $^

rom.bin: boot64k.bin
	tail -c 8192 $< > $@

burn: rom.bin
	minipro -p AT28C64B -s -w $<

clean:
	$(RM) -f boot64k.bin rom.bin

.PHONY: all burn clean

