/**
 * VLINK script for rosco_6502 ROM (32KB banked version)
 *
 * Copyright (c)2023 Ross Bamford & Contributors
 */

SECTIONS {
    .bank0 0xe000 : AT(0) {
        *(.bank0.rtable)
        *(.bank0.irq)
        *(.bank0.text*)
        *(.bank0.rodata*)
        . = 0xfffa;
        *(.bank0.vectors)
    }

    .bank1 0xe000 : {
        *(.bank1.rtable)
        *(.bank1.irq)
        *(.bank1.text*)
        *(.bank1.rodata*)
        . = 0xfffa;
        *(.bank1.vectors)
    }

    .bank2 0xe000 : {
        *(.bank2.rtable)
        *(.bank2.irq)
        *(.bank2.text*)
        *(.bank2.rodata*)
        . = 0xfffa;
        *(.bank2.vectors)
    }

    .bank3 0xe000 : {
        *(.bank3.rtable)
        *(.bank3.irq)
        *(.bank3.text*)
        *(.bank3.rodata*)
        . = 0xfffa;
        *(.bank3.vectors)
    }
};

