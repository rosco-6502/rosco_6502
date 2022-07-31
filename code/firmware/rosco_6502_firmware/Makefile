VASM=vasm6502_oldstyle
VLINK=vlink
ASFLAGS=-c02

all: rom.bin

%.vo: %.asm 
	$(VASM) $(ASFLAGS) -L $(basename $<).lst -Fvobj -o $@ $<

rom.bin: boot.vo
	$(VLINK) -Trosco_6502.ld -brawbin1 -o $@ $^

burn: rom.bin
	minipro -p AT28C64B -s -w $<

clean:
	$(RM) -f *.vo *.lst rom.bin

.PHONY: all burn clean

