/**
 * VLINK script for rosco_6502 ROM (32KB banked version)
 *
 * Copyright (c)2023 Ross Bamford & Contributors
 */

SECTIONS {
    .bank0 0xe000 : AT(0) {
        *(.bank0.rtable)
        *(.bank0.text*)
        *(.bank0.rodata*)
        *(.bank0.routines*)
        . = 0xfd00;
        *(.bank0.bank*)
        . = 0xfe00;
        *(.bank0.irq)
        . = 0xff00;
        *(.bank0.wozmon)
        . = 0xfffa;
        *(.bank0.vectors)
    }
    
    .bank1 0xe000 : {
        *(.bank1.rtable)
        *(.bank1.text*)
        *(.bank1.rodata*)
        *(.bank1.routines*)
        . = 0xfd00;
        *(.bank1.bank*)
        . = 0xfe00;
        *(.bank1.irq)
        . = 0xff00;
        *(.bank1.wozmon)
        . = 0xfffa;
        *(.bank1.vectors)
    }

    .bank2 0xe000 : {
        *(.bank2.rtable)
        *(.bank2.text*)
        *(.bank2.rodata*)
        *(.bank2.routines*)
        . = 0xfd00;
        *(.bank2.bank*)
        . = 0xfe00;
        *(.bank2.irq)
        . = 0xff00;
        *(.bank2.wozmon)
        . = 0xfffa;
        *(.bank2.vectors)
    }

    .bank3 0xe000 : {
        *(.bank3.rtable)
        *(.bank3.text*)
        *(.bank3.rodata*)
        *(.bank3.routines*)
        . = 0xfd00;
        *(.bank3.bank*)
        . = 0xfe00;
        *(.bank3.irq)
        . = 0xff00;
        *(.bank3.wozmon)
        . = 0xfffa;
        *(.bank3.vectors)
    }
};

