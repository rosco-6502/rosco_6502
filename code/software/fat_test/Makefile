VASM=vasm6502_oldstyle
VLINK=vlink
ASFLAGS=-quiet -wdc02 -opt-branch -esc -Fvobj -I../../firmware/firstboot
LDFLAGS=-e_start -bihex

LOADADDR := 0x0800

TARGET := $(shell basename $(CURDIR))
SOURCES := $(wildcard *.asm)
SOURCES += ../sd_test/dua_spi.asm ../sd_test/sd_card.asm ../sd_test/fat32_readonly.asm
OBJECTS := $(TARGET).o $(filter-out $(TARGET).o,$(addsuffix .o,$(basename $(notdir $(SOURCES)))))

all: $(TARGET).hex

clean:
	$(RM) *.o *.lst *.bin *.hex *.sym *.dis

$(OBJECTS): $(SOURCES) $(MAKEFILE_LIST)

$(TARGET).hex: $(OBJECTS)
	$(VLINK) $(LDFLAGS) -Ttext $(LOADADDR) -M$(TARGET).sym -o $@ $(OBJECTS)
	$(VLINK) -brawbin1 -Ttext $(LOADADDR) -o $(TARGET).bin $(OBJECTS)
	da65 --comments 4 --cpu 65c02 --start-addr $(LOADADDR) $(TARGET).bin >$(TARGET).dis

dua_spi.o :../sd_test/dua_spi.asm
	$(VASM) $(ASFLAGS) -L $(basename $(notdir $<)).lst -o $@ $<

sd_card.o :../sd_test/sd_card.asm
	$(VASM) $(ASFLAGS) -L $(basename $(notdir $<)).lst -o $@ $<

fat32_readonly.o :../sd_test/fat32_readonly.asm
	$(VASM) $(ASFLAGS) -L $(basename $(notdir $<)).lst -o $@ $<

%.o : %.asm
	$(VASM) $(ASFLAGS) -L $(basename $(notdir $<)).lst -o $@ $<

.PHONY: all clean

