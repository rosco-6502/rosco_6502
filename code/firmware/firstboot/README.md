## Initial (firstboot) ROM for rosco_6502

This directory contains the ROM code for rosco_6502. 

Currently, there's not a great deal in here - it boots,
sets up a heartbeat LED flash on LED1, and drops into
wozmon. 

### Building

You'll need VASM (6502, oldstyle) installed, plus VLINK, and
the usual build tools (`make` etc).

* http://sun.hasenbraten.de/vasm/
* http://sun.hasenbraten.de/vlink/

This code builds both 8KiB and 32KiB (banked) ROMs - 
to build all targets, just do:

```shell
make clean all
```

If you want to build just the 8KiB ROM:

```shell
make clean boot8k.bin
```

Or for the 32KiB one:

```shell
make clean boot32k.bin
```

If you have minipro set up, you can also burn directly to ROM
with the targets `burn8` or `burn32` for 8KiB and 32KiB respectively.

### Notes on Wozmon

```
The WOZ Monitor for the Apple 1
Written by Steve Wozniak in 1976

Modified for rosco_6502 / VASM by 
Ross Bamford forty-seven years later.
```

#### Usage

To use wozmon on the rosco_6502, you'll
want to set your terminal to treat CR 
as CRLF and send a single CR on return.

I've done the bare minimum to make the 
code work on the rosco_6502. This has
changed the entrypoints of some routines:

* `GETLINE` is now at `FF13`
* `ECHO` is now at `FFE6`
* `PRBYTE` is now at `FFD3`
* `PRHEX` is now at `FFDC`

The monitor entrypoint (not `GETLINE` but
the actual beginning at `FF00`) is loaded
into `NMI`, but there's not a way to
trigger than right now without adding a button...

