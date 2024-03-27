VASM=vasm6502_oldstyle
VLINK=vlink
ASFLAGS=-nocase -c02 -Fvobj -quiet -I../../firmware/firstboot
LDFLAGS=-e_start -bihex

LOADADDR := 0x8000

TARGET := $(shell basename $(CURDIR))
SOURCES := $(wildcard *.asm)
OBJECTS := $(TARGET).o $(filter-out $(TARGET).o,$(addsuffix .o,$(basename $(SOURCES))))

all: $(TARGET).hex

clean:
	$(RM) *.o *.lst *.bin *.hex *.sym *.dis

$(OBJECTS): $(SOURCES) $(MAKEFILE_LIST)

$(TARGET).hex: $(OBJECTS)
	$(VLINK) $(LDFLAGS) -Ttext $(LOADADDR) -M$(TARGET).sym -o $@ $(OBJECTS)
	$(VLINK) -brawbin1 -Ttext $(LOADADDR) -o $(TARGET).bin $(OBJECTS)
	da65 --comments 4 --cpu 65c02 --start-addr $(LOADADDR) $(TARGET).bin >$(TARGET).dis

%.o : %.asm
	$(VASM) $(ASFLAGS) -L $(basename $<).lst -o $@ $<

.PHONY: all clean

