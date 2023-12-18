/**
 * VLINK script for rosco_6502 ROM (32KB banked version)
 *
 * Copyright (c)2023 Ross Bamford & Contributors
 */

SECTIONS {
    .bank0 0xe000 : AT(0) {
        *(.bank0.text*)
        *(.bank0.rodata*)
        . = 0xfd00;
        *(.bank0.irq)
        . = 0xff00;
        *(.text.wozmon)
        . = 0xfffa;
        *(.bank0.vectors)
    }
    
    .bank1 0xe000 : {
        *(.bank1.text*)
        . = 0xfd00;
        *(.bank1.irq)
        . = 0xfffa;
        *(.bank1.vectors)
    }

    .bank2 0xe000 : {
        *(.bank2.text*)
        . = 0xfd00;
        *(.bank2.irq)
        . = 0xfffa;
        *(.bank2.vectors)
    }

    .bank3 0xe000 : {
        *(.bank3.text*)
        . = 0xfd00;
        *(.bank3.irq)
        . = 0xfffa;
        *(.bank3.vectors)
    }
};

