;------------------------------------------------------------
;                            ___ ___ ___ ___
;  ___ ___ ___ ___ ___      |  _| __|   |__ |
; |  _| . |_ -|  _| . |     | . |__ | | | __|
; |_| |___|___|___|___|_____|___|___|___|___|
;                     |_____|    Bringup Code
;------------------------------------------------------------
; Copyright (c)2022-2024 Ross Bamford and contributors
; See top-level LICENSE.md for licence information.
;
; Huge shout-out to the following for helpful reference material:
; George Foot           https://github.com/gfoot/sdcard6502
; PJRC                  https://www.pjrc.com/tech/8051/ide/fat32.html
;------------------------------------------------------------
; vim: set et ts=8 sw=8

; Original version under permissive Unilicense license from:
; George Foot https://github.com/gfoot/sdcard6502 - Thanks George!
; Significantly modified for vasm amd rosco_6502 by Xark

                include "defines.asm"

                section .text

; FAT32/SD interface library
;
; This module requires some RAM workspace to be defined elsewhere:
;
; fat32_workspace    - a large page-aligned 512-byte workspace
; zp_fat32_variables - 24 bytes of zero-page storage for variables etc


                global  fat32_address
                global  fat32_bytesremaining
                global  fat32_errorstage

                global  fat32_lfnbuffer

fat32_readbuffer        = $0400
fat32_lfnbuffer         = $0200

                dsect
                        org     USER_ZP_START+$10

fat32_fatstart          ds      4
fat32_datastart         ds      4
fat32_rootcluster       ds      4
fat32_sectorspercluster ds      1
fat32_pendingsectors    ds      1
fat32_address           ds      2
fat32_nextcluster       ds      4
fat32_bytesremaining    ds      4
fat32_filenamepointer   =       fat32_bytesremaining    ; only used when searching for a file
fat32_filename_lfn_idx  =       fat32_bytesremaining+2    ; only used when searching for a file
fat32_errorstage        ds      1
                dend

zp_sd_currentsector     = FW_ZP_BLOCKNUM
zp_sd_address           = FW_ZP_IOPTR
sd_readsector           = sd_read_block

; Initialize the module - read the MBR etc, find the partition,
; and set up the variables ready for navigating the filesystem
; Trashes A, X, Y
; Returns C=1 on error
                global  fat32_init
fat32_init:
                        ldx     #fat32_errorstage-fat32_fatstart
.clrvars                stz     fat32_fatstart,x
                        dex
                        bpl     .clrvars

                        ; Sector 0
                        lda     #0
                        sta     zp_sd_currentsector
                        sta     zp_sd_currentsector+1
                        sta     zp_sd_currentsector+2
                        sta     zp_sd_currentsector+3

                        ; Target buffer
                        lda     #<fat32_readbuffer
                        sta     zp_sd_address
                        lda     #>fat32_readbuffer
                        sta     zp_sd_address+1

                        ; Do the read
                        jsr     sd_readsector
                        bcs     .fail

                        inc     fat32_errorstage ; stage 1 = boot sector signature check

                        ; Check some things
                        lda     fat32_readbuffer+510 ; Boot sector signature 55
                        cmp     #$55
                        bne     .fail
                        lda     fat32_readbuffer+511 ; Boot sector signature aa
                        cmp     #$aa
                        bne     .fail

                        inc     fat32_errorstage ; stage 2 = finding partition

                        ; Find a FAT32 partition
.FSTYPE_FAT32 = 12
                        ldx     #0
                        lda     fat32_readbuffer+$1c2,x
                        cmp     #.FSTYPE_FAT32
                        beq     .foundpart
                        ldx     #16
                        lda     fat32_readbuffer+$1c2,x
                        cmp     #.FSTYPE_FAT32
                        beq     .foundpart
                        ldx     #32
                        lda     fat32_readbuffer+$1c2,x
                        cmp     #.FSTYPE_FAT32
                        beq     .foundpart
                        ldx     #48
                        lda     fat32_readbuffer+$1c2,x
                        cmp     #.FSTYPE_FAT32
                        beq     .foundpart

.fail                   lda     fat32_errorstage
                        jsr     outbyte
                        sec
                        rts
.foundpart
                        ; Read the FAT32 BPB
                        lda     fat32_readbuffer+$1c6,x
                        sta     zp_sd_currentsector
                        lda     fat32_readbuffer+$1c7,x
                        sta     zp_sd_currentsector+1
                        lda     fat32_readbuffer+$1c8,x
                        sta     zp_sd_currentsector+2
                        lda     fat32_readbuffer+$1c9,x
                        sta     zp_sd_currentsector+3

                        jsr     sd_readsector
                        bcs     .fail

                        inc     fat32_errorstage ; stage 3 = BPB signature check

                        ; Check some things
                        lda     fat32_readbuffer+510 ; BPB sector signature 55
                        cmp     #$55
                        bne     .fail
                        lda     fat32_readbuffer+511 ; BPB sector signature aa
                        cmp     #$aa
                        bne     .fail

                        inc     fat32_errorstage ; stage 4 = RootEntCnt check

                        lda     fat32_readbuffer+17 ; RootEntCnt should be 0 for FAT32
                        ora     fat32_readbuffer+18
                        bne     .fail

                        inc     fat32_errorstage ; stage 5 = TotSec16 check

                        lda     fat32_readbuffer+19 ; TotSec16 should be 0 for FAT32
                        ora     fat32_readbuffer+20
                        bne     .fail

                        inc     fat32_errorstage ; stage 6 = SectorsPerCluster check

                        ; Check bytes per filesystem sector, it should be 512 for any SD card that supports FAT32
                        lda     fat32_readbuffer+11 ; low byte should be zero
                        bne     .fail
                        lda     fat32_readbuffer+12 ; high byte is 2 (512), 4, 8, or 16
                        cmp     #2
                        bne     .fail

                        ; Calculate the starting sector of the FAT
                        clc
                        lda     zp_sd_currentsector
                        adc     fat32_readbuffer+14             ; reserved sectors lo
                        sta     fat32_fatstart
                        sta     fat32_datastart
                        lda     zp_sd_currentsector+1
                        adc     fat32_readbuffer+15             ; reserved sectors hi
                        sta     fat32_fatstart+1
                        sta     fat32_datastart+1
                        lda     zp_sd_currentsector+2
                        adc     #0
                        sta     fat32_fatstart+2
                        sta     fat32_datastart+2
                        lda     zp_sd_currentsector+3
                        adc     #0
                        sta     fat32_fatstart+3
                        sta     fat32_datastart+3

                        ; Calculate the starting sector of the data area
                        ldx     fat32_readbuffer+16                         ; number of FATs
.skipfatsloop   
                        clc     
                        lda     fat32_datastart
                        adc     fat32_readbuffer+36 ; fatsize 0
                        sta     fat32_datastart
                        lda     fat32_datastart+1
                        adc     fat32_readbuffer+37 ; fatsize 1
                        sta     fat32_datastart+1
                        lda     fat32_datastart+2
                        adc     fat32_readbuffer+38 ; fatsize 2
                        sta     fat32_datastart+2
                        lda     fat32_datastart+3
                        adc     fat32_readbuffer+39 ; fatsize 3
                        sta     fat32_datastart+3
                        dex     
                        bne     .skipfatsloop

                        ; Sectors-per-cluster is a power of two from 1 to 128
                        lda     fat32_readbuffer+13
                        sta     fat32_sectorspercluster

                        ; Remember the root cluster
                        lda     fat32_readbuffer+44
                        sta     fat32_rootcluster
                        lda     fat32_readbuffer+45
                        sta     fat32_rootcluster+1
                        lda     fat32_readbuffer+46
                        sta     fat32_rootcluster+2
                        lda     fat32_readbuffer+47
                        sta     fat32_rootcluster+3

                        clc
                        rts


fat32_seekcluster:
                        ; Gets ready to read fat32_nextcluster, and advances it according to the FAT

                        ; FAT sector = (cluster*4) / 512 = (cluster*2) / 256
                        lda     fat32_nextcluster
                        asl     
                        lda     fat32_nextcluster+1
                        rol     
                        sta     zp_sd_currentsector
                        lda     fat32_nextcluster+2
                        rol     
                        sta     zp_sd_currentsector+1
                        lda     fat32_nextcluster+3
                        rol     
                        sta     zp_sd_currentsector+2
                        ; note: cluster numbers never have the top bit set, so no carry can occur

                        ; Add FAT starting sector
                        lda     zp_sd_currentsector
                        adc     fat32_fatstart
                        sta     zp_sd_currentsector
                        lda     zp_sd_currentsector+1
                        adc     fat32_fatstart+1
                        sta     zp_sd_currentsector+1
                        lda     zp_sd_currentsector+2
                        adc     fat32_fatstart+2
                        sta     zp_sd_currentsector+2
                        lda     #0
                        adc     fat32_fatstart+3
                        sta     zp_sd_currentsector+3

                        ; Target buffer
                        lda     #<fat32_readbuffer
                        sta     zp_sd_address
                        lda     #>fat32_readbuffer
                        sta     zp_sd_address+1

                        ; Read the sector from the FAT
                        jsr     sd_readsector
                        bcc     .readok
                        ; sec
                        rts
.readok
                        ; Before using this FAT data, set currentsector ready to read the cluster itself
                        ; We need to multiply the cluster number minus two by the number of sectors per
                        ; cluster, then add the data region start sector

                        ; Subtract two from cluster number
                        sec
                        lda     fat32_nextcluster
                        sbc     #2
                        sta     zp_sd_currentsector
                        lda     fat32_nextcluster+1
                        sbc     #0
                        sta     zp_sd_currentsector+1
                        lda     fat32_nextcluster+2
                        sbc     #0
                        sta     zp_sd_currentsector+2
                        lda     fat32_nextcluster+3
                        sbc     #0
                        sta     zp_sd_currentsector+3

                        ; Multiply by sectors-per-cluster which is a power of two between 1 and 128
                        lda     fat32_sectorspercluster
.spcshiftloop
                        lsr
                        bcs     .spcshiftloopdone
                        asl     zp_sd_currentsector
                        rol     zp_sd_currentsector+1
                        rol     zp_sd_currentsector+2
                        rol     zp_sd_currentsector+3
                        jmp     .spcshiftloop
.spcshiftloopdone

                        ; Add the data region start sector
                        clc
                        lda     zp_sd_currentsector
                        adc     fat32_datastart
                        sta     zp_sd_currentsector
                        lda     zp_sd_currentsector+1
                        adc     fat32_datastart+1
                        sta     zp_sd_currentsector+1
                        lda     zp_sd_currentsector+2
                        adc     fat32_datastart+2
                        sta     zp_sd_currentsector+2
                        lda     zp_sd_currentsector+3
                        adc     fat32_datastart+3
                        sta     zp_sd_currentsector+3

                        ; That's now ready for later code to read this sector in - tell it how many consecutive
                        ; sectors it can now read
                        lda     fat32_sectorspercluster
                        sta     fat32_pendingsectors

                        ; Now go back to looking up the next cluster in the chain
                        ; Find the offset to this cluster's entry in the FAT sector we loaded earlier

                        ; Offset = (cluster*4) & 511 = (cluster & 127) * 4
                        lda     fat32_nextcluster
                        and     #$7f
                        asl
                        asl
                        tay ; Y = low byte of offset

                        ; Add the potentially carried bit to the high byte of the address
                        lda     zp_sd_address+1
                        adc     #0
                        sta     zp_sd_address+1

                        ; Copy out the next cluster in the chain for later use
                        lda     (zp_sd_address),y
                        sta     fat32_nextcluster
                        iny
                        lda     (zp_sd_address),y
                        sta     fat32_nextcluster+1
                        iny
                        lda     (zp_sd_address),y
                        sta     fat32_nextcluster+2
                        iny     
                        lda     (zp_sd_address),y
                        and     #$0f
                        sta     fat32_nextcluster+3

                        ; See if it's the end of the chain
                        ora     #$f0
                        and     fat32_nextcluster+2
                        and     fat32_nextcluster+1
                        cmp     #$ff
                        bne     .notendofchain
                        lda     fat32_nextcluster
                        cmp     #$f8
                        bcc     .notendofchain

                        ; It's the end of the chain, set the top bits so that we can tell this later on
                        sta     fat32_nextcluster+3
.notendofchain
                        clc
                        rts

; Reads the next sector from a cluster chain into the buffer at fat32_address.
;
; Advances the current sector ready for the next read and looks up the next cluster
; in the chain when necessary.
;
; OLD: On return, carry is clear if data was read, or set if the cluster chain has ended.
; NEW: On return, C set on error.  Z is clear if data was read (BNE), or Z set if the cluster chain has ended (BEQ).
fat32_readnextsector:
                        ; Maybe there are pending sectors in the current cluster
                        lda     fat32_pendingsectors
                        bne     .readsector

                        ; No pending sectors, check for end of cluster chain
                        lda     fat32_nextcluster+3
                        bmi     .endofchain

                        ; Prepare to read the next cluster
                        jsr     fat32_seekcluster
.readsector
                        dec     fat32_pendingsectors

                        ; Set up target address
                        lda     fat32_address
                        sta     zp_sd_address
                        lda     fat32_address+1
                        sta     zp_sd_address+1

                        ; Read the sector
                        jsr     sd_readsector
                        bcs     .fail

                        ; Advance to next sector
                        inc     zp_sd_currentsector
                        bne     .sectorincrementdone
                        inc     zp_sd_currentsector+1
                        bne     .sectorincrementdone
                        inc     zp_sd_currentsector+2
                        bne     .sectorincrementdone
                        inc     zp_sd_currentsector+3
.sectorincrementdone

                        ; OLD: Success - clear carry and return
;                        clc
                        ; NEW: Success - clear Z and return NE
                        lda     #$FF
                        rts
.endofchain
                        ; OLD: End of chain - set carry and return
                        ; sec
                        ; NEW: End of chain - set Z and return EQ
                        lda     #$00
                        rts

                        ; error - set carry and return
.fail                   sec
                        rts

; Prepare to read from root directory
;
; Point zp_sd_address at the dirent
                global  fat32_openroot
fat32_openroot:
                        ; Prepare to read the root directory
                        lda     fat32_rootcluster
                        sta     fat32_nextcluster
                        lda     fat32_rootcluster+1
                        sta     fat32_nextcluster+1
                        lda     fat32_rootcluster+2
                        sta     fat32_nextcluster+2
                        lda     fat32_rootcluster+3
                        sta     fat32_nextcluster+3

                        jsr     fat32_seekcluster
                        bcs     .fail

                        ; Set the pointer to a large value so we always read a sector the first time through
                        lda     #$ff
                        sta     zp_sd_address+1

                        clc
.fail                   rts

; Prepare to read from a file or directory based on a dirent
;
; Point zp_sd_address at the dirent
                global  fat32_opendirent
fat32_opendirent:

                        ; Remember file size in bytes remaining
                        ldy     #28
                        lda     (zp_sd_address),y
                        sta     fat32_bytesremaining
                        iny     
                        lda     (zp_sd_address),y
                        sta     fat32_bytesremaining+1
                        iny     
                        lda     (zp_sd_address),y
                        sta     fat32_bytesremaining+2
                        iny     
                        lda     (zp_sd_address),y
                        sta     fat32_bytesremaining+3

                        ; Seek to first cluster
                        ldy     #26
                        lda     (zp_sd_address),y
                        sta     fat32_nextcluster
                        iny     
                        lda     (zp_sd_address),y
                        sta     fat32_nextcluster+1
                        ldy     #20
                        lda     (zp_sd_address),y
                        sta     fat32_nextcluster+2
                        iny     
                        lda     (zp_sd_address),y
                        sta     fat32_nextcluster+3

                        jsr     fat32_seekcluster

                        ; Set the pointer to a large value so we always read a sector the first time through
                        lda     #$ff
                        sta     zp_sd_address+1

                        clc
                        rts

; Read a directory entry from the open directory
;
; On exit the carry is set if there were no more directory entries.
;
; Otherwise, A is set to the file's attribute byte and
; zp_sd_address points at the returned directory entry.
; LFNs and empty entries are ignored automatically.
                global fat32_readdirent
fat32_readdirent:
                        stz     fat32_lfnbuffer ; no LFN
.readnext
                        ; Increment pointer by 32 to point to next entry
                        clc
                        lda     zp_sd_address
                        adc     #32
                        sta     zp_sd_address
                        lda     zp_sd_address+1
                        adc     #0
                        sta     zp_sd_address+1

                        ; If it's not past the end of the buffer, we have data already
                        cmp     #>(fat32_readbuffer+$200)
                        bcc     .gotdata

                        ; Read another sector
                        lda     #<fat32_readbuffer
                        sta     fat32_address
                        lda     #>fat32_readbuffer
                        sta     fat32_address+1

                        jsr     fat32_readnextsector
; OLD                        bcc     .gotdata
                
                        bne     .gotdata
                        bcc     .endofdirectory

                        ; TODO set error code

.endofdirectory
                        sec
                        rts

.gotdata
                        ; Check first character
                        lda     (zp_sd_address)

                        ; End of directory => abort
                        beq     .endofdirectory

                        ; Empty entry => start again
                        cmp     #$e5
                        beq     fat32_readdirent

                if 0

                        lda     #<$0020
                        sta     ZP_COUNT
                        lda     #>$0020
                        sta     ZP_COUNT+1
                        lda     zp_sd_address
                        sta     FW_ZP_TMPPTR
                        lda     zp_sd_address+1
                        sta     FW_ZP_TMPPTR+1
                        jsr     examine
                        lda     #$0d
                        jsr     COUT
                        lda     #$0a
                        jsr     COUT

                endif
                        ; Check attributes
                        ldy     #11
                        lda     (zp_sd_address),y
                        and     #$3f
                        cmp     #$0f ; LFN => start again
                        bne     .notlfn

                        lda     (zp_sd_address)         ; get LFN index/flag
                        bit     #$40                    ; new entry?
                        beq     .copylfn                ; branch if not

                        ldx     #0
.clrlfn                 stz     fat32_lfnbuffer,x       ; fresh lfn
                        dex
                        bne     .clrlfn

.copylfn                and     #$1f                    ; mask for 32 LFN entries
                        beq     fat32_readdirent        ; index should not be zero, zero lfn keep reading
                        dec                             ; zero based idx
                        tax                             ; save in x
                        asl                             ; * 2
                        asl                             ; * 4
                        sta     fat32_filename_lfn_idx  ; save * 4
                        asl                             ; * 8
                        clc
                        adc     fat32_filename_lfn_idx  ; add for * 12
                        sta     fat32_filename_lfn_idx  ; save * 12
                        bcs     .readnext               ; skip entry if starts > 256 chars
                        txa
                        adc     fat32_filename_lfn_idx  ; add for * 13
                        bcs     .readnext               ; skip entry if starts > 256 chars
                        tax                             ; x = LFN index
                        ldy     #1                      ; y = dirent byte
.lfnloop                cpy     #$0b
                        beq     .skip2byte
                        cpy     #$0d
                        beq     .skip1byte
                        cpy     #$1a
                        beq     .skip2byte
                        lda     (zp_sd_address),y
                        cmp     #$FF                    ; convert 0xFF to 0x00
                        bne     .notpad
                        lda     #$00
.notpad                 sta     fat32_lfnbuffer,x
                        inx
.skip2byte              iny
.skip1byte              iny
                        cpy     #$20
                        beq     .lfncopydone
                        cpx     #$ff
                        bne     .lfnloop
.lfncopydone            bra     .readnext

.notlfn                 ; Yield this result
                        clc
                        rts

; Finds a particular directory entry. X,Y point to the 11-character filename to seek.
; The directory should already be open for iteration.
                global  fat32_finddirent
fat32_finddirent:
                        ; Form ZP pointer to user's filename
                        stx     fat32_filenamepointer
                        sty     fat32_filenamepointer+1

                        ; Iterate until name is found or end of directory
.direntloop
                        jsr     fat32_readdirent
                        bcc     .comparename

                        rts     ; with carry set

.comparename            ;bra     .compareshort
                        lda     fat32_lfnbuffer
                        beq     .compareshort

                        ldy     #0
.comparelong            lda     fat32_lfnbuffer,y
                        cmp     (fat32_filenamepointer),y
                        bne     .direntloop ; no match
                        tax
                        beq     .foundit
                        iny
                        bne     .comparelong
                        bra     .foundit

.compareshort           ldy     #11-1
.comparenameloop        lda     (zp_sd_address),y
                        cmp     (fat32_filenamepointer),y
                        bne     .direntloop ; no match
                        dey     
                        bpl     .comparenameloop

.foundit                clc
                        rts

; Read a byte from an open file
;
; The byte is returned in A with C clear; or if end-of-file was reached, C is set instead
                global fat32_file_readbyte
fat32_file_readbyte:
                        sec

                        ; Is there any data to read at all?
                        lda     fat32_bytesremaining
                        ora     fat32_bytesremaining+1
                        ora     fat32_bytesremaining+2
                        ora     fat32_bytesremaining+3
                        beq     .rts

                        ; Decrement the remaining byte count
                        lda     fat32_bytesremaining
                        sbc     #1
                        sta     fat32_bytesremaining
                        lda     fat32_bytesremaining+1
                        sbc     #0
                        sta     fat32_bytesremaining+1
                        lda     fat32_bytesremaining+2
                        sbc     #0
                        sta     fat32_bytesremaining+2
                        lda     fat32_bytesremaining+3
                        sbc     #0
                        sta     fat32_bytesremaining+3

                        ; Need to read a new sector?
                        lda     zp_sd_address+1
                        cmp     #>(fat32_readbuffer+$200)
                        bcc     .gotdata

                        ; Read another sector
                        lda     #<fat32_readbuffer
                        sta     fat32_address
                        lda     #>fat32_readbuffer
                        sta     fat32_address+1

                        jsr     fat32_readnextsector
; OLD                        bcs     .rts               ; this shouldn't happen
                        beq     .rts
                        bcs     .rts
.gotdata
                        ldy     #0
                        lda     (zp_sd_address),y

                        inc     zp_sd_address
                        bne     .rts
                        inc     zp_sd_address+1
                        bne     .rts
                        inc     zp_sd_address+2
                        bne     .rts
                        inc     zp_sd_address+3
.rts
                        rts

; Read a whole file into memory. It's assumed the file has just been opened
; and no data has been read yet.
;
; Also we read whole sectors, so data in the target region beyond the end of the
; file may get overwritten, up to the next 512-byte boundary.
;
; And we don't properly support 64k+ files, as it's unnecessary complication given
; the 6502's small address space
                global  fat32_file_read
fat32_file_read:
                        ; Round the size up to the next whole sector
                        lda     fat32_bytesremaining
                        cmp     #1                      ; set carry if bottom 8 bits not zero
                        lda     fat32_bytesremaining+1
                        adc     #0                      ; add carry, if any
                        lsr                             ; divide by 2
                        adc     #0                      ; round up

                        ; No data?
                        beq     .done

                        ; Store sector count - not a byte count any more
                        sta     fat32_bytesremaining

                        ; Read entire sectors to the user-supplied buffer
.wholesectorreadloop
                        ; Read a sector to fat32_address
                        jsr     fat32_readnextsector
                        bcs     .fail
                        beq     .fail

                        ; Advance fat32_address by 512 bytes
                        lda     fat32_address+1
                        adc     #2                      ; carry already clear
                        sta     fat32_address+1

                        ldx     fat32_bytesremaining    ; note - actually loads sectors remaining
                        dex
                        stx     fat32_bytesremaining    ; note - actually stores sectors remaining

                        bne     .wholesectorreadloop
.done
                        clc
                        rts
.fail                   sec
                        rts

