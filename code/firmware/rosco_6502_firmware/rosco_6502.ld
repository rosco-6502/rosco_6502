MEMORY {
    ZP     : ORIGIN = 0x0000, LENGTH = 0x0100
    STACK  : ORIGIN = 0x0100, LENGTH = 0x0100
    KRAM   : ORIGIN = 0x0200, LENGTH = 0x0100    
    LOWRAM : ORIGIN = 0x0300, LENGTH = 0x3e00
    BANKRAM: ORIGIN = 0x4000, LENGTH = 0x8000
    ROM    : ORIGIN = 0xe000, LENGTH = 0x1ffa
    VECTORS: ORIGIN = 0xfffa, LENGTH = 0x0006
};

SECTIONS {
    .text: {
        _code_start = .;
        *(.text CODE text)
        *(.rodata*)
        _code_end = .;
    } > ROM;

    .data: {
        _data_start = .;
        *(.data DATA data)
        _data_end = .;
    } > ROM;

    .fillrom : {
        FILL8(0xa0);
        . = ORIGIN(ROM) + LENGTH(ROM) - 1;
        BYTE(0xfe);
        _rom_end = .;
    } > ROM;

    .vectors : {
        *(.vectors)
    } > VECTORS;

    .bss (NOLOAD): {
        _bss_start = .;
        *(.bss BSS bss)
        *(COMMON)
        .bss_end = .;
        *(.data DATA data)
        .data_copy_end = .;
    } > KRAM;
};

