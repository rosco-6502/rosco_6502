; vim: set et ts=8 sw=8
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
; Modified and enhanced for rosco_6502 by Xark

FAT_TRACE               =       0       ; 1 for invasive debug trace prints
FAT_DEBUG               =       1       ; 1 for debug asserts

                .if FAT_TRACE
.macro                  tprint  str
                        .pushseg
                        .segment "RODATA0"
                        .local  @trstr
@trstr:                 .byte   str,0
                        .popseg
                        php
                        pha
                        phx
                        lda     #<@trstr
                        ldx     #>@trstr
                        jsr     PRINT
                        plx
                        pla
                        plp
.endmacro
.macro                  tprintv value
                        php
                        pha
                        lda     value
                        jsr     outbyte
                        lda     #'}'
                        jsr     COUT
                        pla
                        plp
.endmacro
.macro                  tprintv32 value
                        php
                        pha
                        lda     value+3
                        jsr     outbyte
                        lda     value+2
                        jsr     outbyte
                        lda     value+1
                        jsr     outbyte
                        lda     value+0
                        jsr     outbyte
                        lda     #' '
                        jsr     COUT
                        pla
                        plp
.endmacro
                .else
.macro                  tprint  str
.endmacro
.macro                  tprintv value
.endmacro
.macro                  tprintv32 value
.endmacro
                .endif

; FAT32 file-system

fat32_nextcluster       =       FS_ZP_PRIVATE           ; 4 bytes
fat32_filenamepointer   =       fat32_nextcluster+4     ; 2 bytes
fat32_sector_bytes      =       fat32_filenamepointer+2 ; 2 bytes
fat32_userfilename      =       fat32_sector_bytes+2    ; 2 bytes
fat32_zp_end            =       fat32_userfilename+2
                        .assert (fat32_zp_end-FS_ZP_PRIVATE<FS_ZP_SIZE),error,"FS_ZP overflow"

fat32_rootcluster       =       FS_RAM_START            ; 4 bytes
fat32_fatstart          =       fat32_rootcluster+4     ; 4 bytes
fat32_datastart         =       fat32_fatstart+4        ; 4 bytes
fat32_sectorspercluster =       fat32_datastart+4       ; 1 byte
fat32_pendingsectors    =       fat32_sectorspercluster+1; 1 byte
fat32_filename_lfn_idx  =       fat32_pendingsectors+1  ; 1 byte
fat32_ram_end           =       fat32_filename_lfn_idx+1
                        .assert (fat32_ram_end-FS_RAM_START<FS_RAM_SIZE),error,"FS_RAM overflow"

; Initialize the module - read the MBR etc, find the partition,
; and set up the variables ready for navigating the filesystem
; Trashes A, X, Y
; Returns C=1 on error
_FAT_CTRL:
                tprint  "{fat32_init:"
                        ldx     #FW_ZP_SIZE-1
@clrzpvars:             stz     FS_ZP_START,x
                        dex
                        bpl     @clrzpvars

                        ldx     #FS_RAM_SIZE-1
@clrvars:               stz     FS_RAM_START,x
                        dex
                        bpl     @clrvars

                        ; Sector 0
                        stz     FW_ZP_BLOCKNUM
                        stz     FW_ZP_BLOCKNUM+1
                        stz     FW_ZP_BLOCKNUM+2
                        stz     FW_ZP_BLOCKNUM+3

                        ; Target buffer
                        lda     #<FILESYSBUF
                        sta     FW_ZP_IOPTR
                        lda     #>FILESYSBUF
                        sta     FW_ZP_IOPTR+1

                        ; Do the read
                        jsr     BD_READ
                        bcc     @readokay
@mediaerr:              lda     #FSERR_MEDIAERR
                        sta     FS_ZP_ERRORCODE
                        bra     @fail

@readokay:              inc     FS_ZP_ERRORCODE ; stage 1 = FSERR_MBR boot sector signature check

                        ; Check some things
                        lda     FILESYSBUF+510 ; Boot sector signature 55
                        cmp     #$55
                        bne     @fail
                        lda     FILESYSBUF+511 ; Boot sector signature aa
                        cmp     #$aa
                        bne     @fail

                        inc     FS_ZP_ERRORCODE ; stage 2 = FSERR_PARTITION find FAT32 LBA partition

                        ; Find a FAT32 partition (type $0B or $0C)
@FSTYPE_FAT32_1 = $0B
@FSTYPE_FAT32_2 = $0C
                        ldx     #0
                        lda     FILESYSBUF+$1c2,x
                        cmp     #@FSTYPE_FAT32_1
                        beq     @foundpart
                        cmp     #@FSTYPE_FAT32_2
                        beq     @foundpart
                        ldx     #16
                        lda     FILESYSBUF+$1c2,x
                        cmp     #@FSTYPE_FAT32_1
                        beq     @foundpart
                        cmp     #@FSTYPE_FAT32_2
                        beq     @foundpart
                        ldx     #32
                        lda     FILESYSBUF+$1c2,x
                        cmp     #@FSTYPE_FAT32_1
                        beq     @foundpart
                        cmp     #@FSTYPE_FAT32_2
                        beq     @foundpart
                        ldx     #48
                        lda     FILESYSBUF+$1c2,x
                        cmp     #@FSTYPE_FAT32_1
                        beq     @foundpart
                        cmp     #@FSTYPE_FAT32_2
                        beq     @foundpart

@fail:
           tprint "Err="
           tprintv FS_ZP_ERRORCODE
                        sec
                        rts
@foundpart:
                        ; Read the FAT32 BPB
                        lda     FILESYSBUF+$1c6,x
                        sta     FW_ZP_BLOCKNUM
                        lda     FILESYSBUF+$1c7,x
                        sta     FW_ZP_BLOCKNUM+1
                        lda     FILESYSBUF+$1c8,x
                        sta     FW_ZP_BLOCKNUM+2
                        lda     FILESYSBUF+$1c9,x
                        sta     FW_ZP_BLOCKNUM+3

                        jsr     BD_READ
                        bcs     @mediaerr

                        inc     FS_ZP_ERRORCODE ; stage 3 = FAT32_FILESYS_ERR BPB signature check

                        ; Check some things
                        lda     FILESYSBUF+510 ; BPB sector signature 55
                        cmp     #$55
                        bne     @fail
                        lda     FILESYSBUF+511 ; BPB sector signature aa
                        cmp     #$aa
                        bne     @fail

                        inc     FS_ZP_ERRORCODE ; stage 4 = FSERR_BADROOT RootEntCnt check

                        lda     FILESYSBUF+17 ; RootEntCnt should be 0 for FAT32
                        ora     FILESYSBUF+18
                        bne     @fail

                        inc     FS_ZP_ERRORCODE ; stage 5 = FSERR_BADTOTSEC TotSec16 check

                        lda     FILESYSBUF+19 ; TotSec16 should be 0 for FAT32
                        ora     FILESYSBUF+20
                        bne     @fail

                        inc     FS_ZP_ERRORCODE ; stage 6 = FSERR_BADSECSIZE SectorsPerCluster check

                        ; Check bytes per filesystem sector, it should be 512 for any SD card that supports FAT32
                        lda     FILESYSBUF+11 ; low byte should be zero
                        bne     @fail
                        lda     FILESYSBUF+12 ; high byte is 2 (512), 4, 8, or 16
                        cmp     #2
                        bne     @fail

                        ; Calculate the starting sector of the FAT
                        clc
                        lda     FW_ZP_BLOCKNUM
                        adc     FILESYSBUF+14             ; reserved sectors lo
                        sta     fat32_fatstart
                        sta     fat32_datastart
                        lda     FW_ZP_BLOCKNUM+1
                        adc     FILESYSBUF+15             ; reserved sectors hi
                        sta     fat32_fatstart+1
                        sta     fat32_datastart+1
                        lda     FW_ZP_BLOCKNUM+2
                        adc     #0
                        sta     fat32_fatstart+2
                        sta     fat32_datastart+2
                        lda     FW_ZP_BLOCKNUM+3
                        adc     #0
                        sta     fat32_fatstart+3
                        sta     fat32_datastart+3

                        ; Calculate the starting sector of the data area
                        ldx     FILESYSBUF+16                         ; number of FATs
@skipfatsloop:
                        clc
                        lda     fat32_datastart
                        adc     FILESYSBUF+36 ; fatsize 0
                        sta     fat32_datastart
                        lda     fat32_datastart+1
                        adc     FILESYSBUF+37 ; fatsize 1
                        sta     fat32_datastart+1
                        lda     fat32_datastart+2
                        adc     FILESYSBUF+38 ; fatsize 2
                        sta     fat32_datastart+2
                        lda     fat32_datastart+3
                        adc     FILESYSBUF+39 ; fatsize 3
                        sta     fat32_datastart+3
                        dex
                        bne     @skipfatsloop

                        ; Sectors-per-cluster is a power of two from 1 to 128
                        lda     FILESYSBUF+13
                        sta     fat32_sectorspercluster

                        ; Remember the root cluster
                        lda     FILESYSBUF+44
                        sta     fat32_rootcluster
                        lda     FILESYSBUF+45
                        sta     fat32_rootcluster+1
                        lda     FILESYSBUF+46
                        sta     fat32_rootcluster+2
                        lda     FILESYSBUF+47
                        sta     fat32_rootcluster+3

                tprint  "OK}"
                        clc
                        rts

; fat32_seekcluster
;
; Gets ready to read fat32_nextcluster, and advances it according to the FAT
fat32_seekcluster:
                tprint  "{fat32_seekcluster:"
                tprintv32 fat32_nextcluster
                        stz     FS_ZP_ERRORCODE

                        ; FAT sector = (cluster*4) / 512 = (cluster*2) / 256
                        lda     fat32_nextcluster
                        asl
                        lda     fat32_nextcluster+1
                        rol
                        sta     FW_ZP_BLOCKNUM
                        lda     fat32_nextcluster+2
                        rol
                        sta     FW_ZP_BLOCKNUM+1
                        lda     fat32_nextcluster+3
                        rol
                        sta     FW_ZP_BLOCKNUM+2
                        ; note: cluster numbers never have the top bit set, so no carry can occur

                        ; Add FAT starting sector
                        lda     FW_ZP_BLOCKNUM
                        adc     fat32_fatstart
                        sta     FW_ZP_BLOCKNUM
                        lda     FW_ZP_BLOCKNUM+1
                        adc     fat32_fatstart+1
                        sta     FW_ZP_BLOCKNUM+1
                        lda     FW_ZP_BLOCKNUM+2
                        adc     fat32_fatstart+2
                        sta     FW_ZP_BLOCKNUM+2
                        lda     #0
                        adc     fat32_fatstart+3
                        sta     FW_ZP_BLOCKNUM+3

                        ; Target buffer
                        lda     #<FILESYSBUF
                        sta     FW_ZP_IOPTR
                        lda     #>FILESYSBUF
                        sta     FW_ZP_IOPTR+1

                        ; Read the sector from the FAT
                        jsr     BD_READ
                        bcc     @readok
                        ; sec
                        lda     #FSERR_MEDIAERR
                        sta     FS_ZP_ERRORCODE
           tprint "Err="
           tprintv FS_ZP_ERRORCODE
                        rts
@readok:
                        ; Before using this FAT data, set currentsector ready to read the cluster itself
                        ; We need to multiply the cluster number minus two by the number of sectors per
                        ; cluster, then add the data region start sector

                        ; Subtract two from cluster number
                        sec
                        lda     fat32_nextcluster
                        sbc     #2
                        sta     FW_ZP_BLOCKNUM
                        lda     fat32_nextcluster+1
                        sbc     #0
                        sta     FW_ZP_BLOCKNUM+1
                        lda     fat32_nextcluster+2
                        sbc     #0
                        sta     FW_ZP_BLOCKNUM+2
                        lda     fat32_nextcluster+3
                        sbc     #0
                        sta     FW_ZP_BLOCKNUM+3

                        ; Multiply by sectors-per-cluster which is a power of two between 1 and 128
                        lda     fat32_sectorspercluster
@spcshiftloop:
                        lsr
                        bcs     @spcshiftloopdone
                        asl     FW_ZP_BLOCKNUM
                        rol     FW_ZP_BLOCKNUM+1
                        rol     FW_ZP_BLOCKNUM+2
                        rol     FW_ZP_BLOCKNUM+3
                        jmp     @spcshiftloop
@spcshiftloopdone:

                        ; Add the data region start sector
                        clc
                        lda     FW_ZP_BLOCKNUM
                        adc     fat32_datastart
                        sta     FW_ZP_BLOCKNUM
                        lda     FW_ZP_BLOCKNUM+1
                        adc     fat32_datastart+1
                        sta     FW_ZP_BLOCKNUM+1
                        lda     FW_ZP_BLOCKNUM+2
                        adc     fat32_datastart+2
                        sta     FW_ZP_BLOCKNUM+2
                        lda     FW_ZP_BLOCKNUM+3
                        adc     fat32_datastart+3
                        sta     FW_ZP_BLOCKNUM+3

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
                        lda     FW_ZP_IOPTR+1
                        adc     #0
                        sta     FW_ZP_IOPTR+1

                        ; Copy out the next cluster in the chain for later use
                        lda     (FW_ZP_IOPTR),y
                        sta     fat32_nextcluster
                        iny
                        lda     (FW_ZP_IOPTR),y
                        sta     fat32_nextcluster+1
                        iny
                        lda     (FW_ZP_IOPTR),y
                        sta     fat32_nextcluster+2
                        iny
                        lda     (FW_ZP_IOPTR),y
                        and     #$0f
                        sta     fat32_nextcluster+3

                        ; See if it's the end of the chain
                        ora     #$f0
                        and     fat32_nextcluster+2
                        and     fat32_nextcluster+1
                        cmp     #$ff
                        bne     @notendofchain
                        lda     fat32_nextcluster
                        cmp     #$f8
                        bcc     @notendofchain

                        ; It's the end of the chain, set the top bits so that we can tell this later on
                        sta     fat32_nextcluster+3
@notendofchain:
           tprint "OK}"
                        clc
                        rts

; Reads the next sector from a cluster chain into the buffer at FS_ZP_ADDRPTR.
;
; Advances the current sector ready for the next read and looks up the next cluster
; in the chain when necessary.
;
; OLD: On return, carry is clear if data was read, or set if the cluster chain has ended.
; NEW: On return, C set on error.  A is non-zero if data was read, or 0 set if the cluster chain has ended.
fat32_readnextsector:
                tprint  "{fat32_readnextsector:"
                        stz     FS_ZP_ERRORCODE

                        ; Maybe there are pending sectors in the current cluster
                        lda     fat32_pendingsectors
                        bne     @readsector

                        ; No pending sectors, check for end of cluster chain
                        lda     fat32_nextcluster+3
                        bmi     @endofchain

                        ; Prepare to read the next cluster
                        jsr     fat32_seekcluster
@readsector:
                        dec     fat32_pendingsectors

                        ; Set up target address
                        lda     FS_ZP_ADDRPTR
                        sta     FW_ZP_IOPTR
                        lda     FS_ZP_ADDRPTR+1
                        sta     FW_ZP_IOPTR+1

                tprintv32 FW_ZP_BLOCKNUM

                        ; Read the sector
                        jsr     BD_READ
                        bcc     @readokay

                        lda     #FSERR_MEDIAERR
                        sta     FS_ZP_ERRORCODE
                        bra     @fail

                        ; Advance to next sector
@readokay:
                        inc     FW_ZP_BLOCKNUM
                        bne     @sectorincrementdone
                        inc     FW_ZP_BLOCKNUM+1
                        bne     @sectorincrementdone
                        inc     FW_ZP_BLOCKNUM+2
                        bne     @sectorincrementdone
                        inc     FW_ZP_BLOCKNUM+3
@sectorincrementdone:
                        ; OLD: Success - clear carry and return
                        ; NEW: Success - clear Z and return NE
           tprint "more-OK}"

                        lda     #$FF
                        clc
                        rts

                        ; error - set carry and return (also EQ for end of chain)
@fail:
           tprint "Err="
           tprintv FS_ZP_ERRORCODE

                        lda     #$00
                        sec
                        rts
@endofchain:
                        ; OLD: End of chain - set carry and return
                        ; sec
                        ; NEW: End of chain - set Z and return EQ
           tprint "done-OK}"

                        lda     #$00
                        clc
                        rts

; Prepare to read from root directory
;
; Point FW_ZP_IOPTR at the dirent
fat32_openroot:
                tprint  "{fat32_openroot:"
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
                        bcs     @fail

                        ; clear sector bytes, so we always read a sector the first time through
                        stz     fat32_sector_bytes
                        stz     fat32_sector_bytes+1
                        lda     #$ff
                        sta     FW_ZP_IOPTR+1


                tprint  "OK}"

                        clc
                        rts
@fail:
           tprint "Err="
           tprintv FS_ZP_ERRORCODE

                        sec
                        rts

; convert US ASCII uppercase in A to lowercase
;
tolower:
                        cmp     #'A'
                        bcc     @noconvert
                        cmp     #'Z'+1
                        bcs     @noconvert
                        ora     #$20
@noconvert:             rts


; Prepare to read from a file or directory based on a dirent
;
; Point FW_ZP_IOPTR at the dirent
fat32_opendirent:
                        stz     FS_ZP_ERRORCODE

                        ; Remember file size in bytes remaining
                        ldy     #28
                        lda     (FW_ZP_IOPTR),y
                        sta     FS_ZP_BYTESLEFT
                        iny
                        lda     (FW_ZP_IOPTR),y
                        sta     FS_ZP_BYTESLEFT+1
                        iny
                        lda     (FW_ZP_IOPTR),y
                        sta     FS_ZP_BYTESLEFT+2
                        iny
                        lda     (FW_ZP_IOPTR),y
                        sta     FS_ZP_BYTESLEFT+3

                tprint  "{fat32_opendirent:"
                tprintv32 FS_ZP_BYTESLEFT

                        ; Seek to first cluster
                        ldy     #26
                        lda     (FW_ZP_IOPTR),y
                        sta     fat32_nextcluster
                        iny
                        lda     (FW_ZP_IOPTR),y
                        sta     fat32_nextcluster+1
                        ldy     #20
                        lda     (FW_ZP_IOPTR),y
                        sta     fat32_nextcluster+2
                        iny
                        lda     (FW_ZP_IOPTR),y
                        sta     fat32_nextcluster+3

                        jsr     fat32_seekcluster
                        stz     fat32_sector_bytes
                        stz     fat32_sector_bytes+1

                        bcs     @fail

                tprint  "OK}"
                        clc
                        rts

@fail:
           tprint "Err="
           tprintv FS_ZP_ERRORCODE
                        sec
                        rts

; Read a directory entry from the open directory
;
; OLD: On exit the carry is set if there were no more directory entries.
;
; A is set to the file's attribute byte or $FF (FS_DIRENT_END_ATTR) if no more entries, C set if error
; FW_ZP_IOPTR points at the returned directory entry.
; LFNs and empty entries are ignored automatically.
_FAT_READDIRENT:
                tprint  "{fat32_readdirent:"
@fat32_readdirent:                
                        stz     FILENAMEBUF ; clear LFN
@readnext:
                        ; Increment pointer by 32 to point to next entry
                        clc
                        lda     FW_ZP_IOPTR
                        adc     #32
                        sta     FW_ZP_IOPTR
                        lda     FW_ZP_IOPTR+1
                        adc     #0
                        sta     FW_ZP_IOPTR+1

                        ; If it's not past the end of the buffer, we have data already
                        cmp     #>(FILESYSBUF+$200)
                        bcc     @gotdata

                        ; Read another sector
                        lda     #<FILESYSBUF
                        sta     FS_ZP_ADDRPTR
                        lda     #>FILESYSBUF
                        sta     FS_ZP_ADDRPTR+1

                        jsr     fat32_readnextsector
                        jcs     @fail                   ; error
                        cmp     #0                      ; was EOF?
                        bne     @gotdata                ; branch if not
                        ; return end of dir (but C may be set if error)
@endofdirectory:
                tprint  "EOD-"

                        lda     #FS_DIRENT_END_ATTR
                        jra     @done
@gotdata:
                        ; Check first character
                        lda     (FW_ZP_IOPTR)

                        ; End of directory => abort
                        beq     @endofdirectory

                        ; Empty entry => start again
                        cmp     #$e5
                        beq     @readnext

                .if 0    ; dump raw dirent
                        lda     #$0d
                        jsr     COUT
                        lda     #$0a
                        jsr     COUT
                        lda     #<$0020
                        sta     ZP_COUNT
                        lda     #>$0020
                        sta     ZP_COUNT+1
                        lda     FW_ZP_IOPTR
                        sta     FW_ZP_TMPPTR
                        lda     FW_ZP_IOPTR+1
                        sta     FW_ZP_TMPPTR+1
                        jsr     examine

                .endif
                        ; Check attributes
                        ldy     #11
                        lda     (FW_ZP_IOPTR),y
                        and     #$3f
                        cmp     #$0f ; LFN => start again
                        bne     @returnent

                        lda     (FW_ZP_IOPTR)         ; get LFN index/flag
                        bit     #$40                    ; new entry?
                        beq     @copylfn                ; branch if not

                        ldx     #0
@clrlfn:
                        stz     FILENAMEBUF,x       ; fresh lfn
                        dex
                        bne     @clrlfn

@copylfn:
                        and     #$1f                    ; mask for 32 LFN entries
                        beq     @fat32_readdirent       ; index should not be zero, zero lfn keep reading
                        dec                             ; zero based idx
                        tax                             ; save in x
                        asl                             ; * 2
                        asl                             ; * 4
                        sta     fat32_filename_lfn_idx  ; save * 4
                        asl                             ; * 8
                        clc
                        adc     fat32_filename_lfn_idx  ; add for * 12
                        sta     fat32_filename_lfn_idx  ; save * 12
                        bcs     @readnext               ; skip entry if starts > 256 chars
                        txa
                        adc     fat32_filename_lfn_idx  ; add for * 13
                        bcs     @readnext               ; skip entry if starts > 256 chars
                        tax                             ; x = LFN index
                        ldy     #1                      ; y = dirent byte
@lfnloop:               cpy     #$0b
                        beq     @skip2byte
                        cpy     #$0d
                        beq     @skip1byte
                        cpy     #$1a
                        beq     @skip2byte
                        lda     (FW_ZP_IOPTR),y
                        cmp     #$FF                    ; convert 0xFF to 0x00
                        bne     @notpad
                        lda     #$00
@notpad:                sta     FILENAMEBUF,x
                        inx
@skip2byte:             iny
@skip1byte:             iny
                        cpy     #$20
                        beq     @lfncopydone
                        cpx     #$ff
                        bne     @lfnloop
@lfncopydone:           jra     @readnext

@returnent:
                .if 1    ; create LFN from SFN
                        ldy     FILENAMEBUF         ; already have LFN for this entry?
                        bne     @done                   ; branch if yes
                        pha                             ; save attributes
                        ldy     #$0c                    ; see https://en.wikipedia.org/wiki/Design_of_the_FAT_file_system#VFAT_long_file_names
                        lda     (FW_ZP_IOPTR),y       ; dirent[$0C] has SFN case flags [5]=ext lowercase, [4]=base lowercase
                        asl                             ; shift so N=lower ext flag, V=lower ext flag for BIT test
                        asl
                        asl
                        sta     FW_ZP_TEMP_3
                        ldx     #0
                        ldy     #0
@makelfnbase:           lda     (FW_ZP_IOPTR),y
                        iny
                        cmp     #' '
                        beq     @donebase
                        bit     FW_ZP_TEMP_3
                        bvc     @nobaselower
                        jsr     tolower
@nobaselower:           sta     FILENAMEBUF,x
                        inx
                        cpy     #8
                        bne     @makelfnbase
@donebase:              pla
                        cmp     #$08                    ; if volume, don't add '@'
                        pha
                        beq     @makelfnext
                        ldy     #8
                        lda     (FW_ZP_IOPTR),y
                        cmp     #' '
                        beq     @donelfn
                        lda     #'.'
                        sta     FILENAMEBUF,x
                        inx
@makelfnext:            lda     (FW_ZP_IOPTR),y
                        iny
                        cmp     #' '
                        beq     @donelfn
                        bit     FW_ZP_TEMP_3
                        bpl     @noextlower
                        jsr     tolower
@noextlower:            sta     FILENAMEBUF,x
                        inx
                        cpy     #8+3
                        bne     @makelfnext
@donelfn:               stz     FILENAMEBUF,x
                        pla                             ; reload attribute for return
                .endif
@done:
                tprint  "OK="
                .if FAT_TRACE
                        sta     FW_ZP_TEMP_3
                tprintv FW_ZP_TEMP_3
                .endif
                        clc
                        rts
@fail:
                tprint  "Err="
                tprintv FS_ZP_ERRORCODE
                        sec
                        rts

; Finds a particular directory entry. A,X point to the NUL terminated filename to seek.
; The directory should already be open for iteration.
fat32_finddirent:
                        stz     FS_ZP_ERRORCODE

                        ; Form ZP pointer to user's filename
                        sta     fat32_filenamepointer
                        stx     fat32_filenamepointer+1

                tprint  "{fat32_finddirent:"
                .if FAT_TRACE
                        jsr     PRINT
                        lda     #' '
                        jsr     COUT
                .endif

                        ; Iterate until name is found or end of directory
@direntloop:
                        jsr     FS_READDIRENT
                        bcs     @fail
                        cmp     #$FF
                        bne     @comparename

                        lda     #FSERR_NOTFOUND
                        sta     FS_ZP_ERRORCODE
@fail:
                tprint  "Err="
                tprintv FS_ZP_ERRORCODE
                        sec
                        rts     ; with carry set

@comparename:           ;bra     @compareshort
                        lda     FILENAMEBUF
                        beq     @compareshort
; case insensitive LFN compare
                        ldy     #0
@comparelong:           lda     FILENAMEBUF,y
                        jsr     tolower
                        sta     FW_ZP_TEMP_3
                        lda     (fat32_filenamepointer),y
                        jsr     tolower
                        cmp     FW_ZP_TEMP_3
                        bne     @direntloop     ; no match
                        tax
                        beq     @foundit        ; it was NUL
                        iny
                        bne     @comparelong
                        bra     @foundit        ; 256 matches, assueme truncated match

; case insensitive SFN compare (base padded to 8 and ext to 3 with ' ', e.g, "README  MD ")
@compareshort:          ldy     #11-1
@comparenameloop:       lda     (FW_ZP_IOPTR),y
                        jsr     tolower
                        sta     FW_ZP_TEMP_3
                        lda     (fat32_filenamepointer),y
                        jsr     tolower
                        cmp     FW_ZP_TEMP_3
                        bne     @direntloop     ; no match
                        dey
                        bpl     @comparenameloop

@foundit:
                tprint  "OK}"
                        clc
                        rts

; traverse a file path and open final dirent
;
_FAT_OPEN:
                        stz     FS_ZP_ERRORCODE

                        ; Form ZP pointer to user's filename
                        sta     fat32_userfilename
                        stx     fat32_userfilename+1

                        ldy     #0                      ; zero index for source path
@pathpart:              ldx     #0                      ; zero index for path component
@pathcharloop:          lda     (fat32_userfilename),y  ; get next path char
                        beq     @openpath               ; end of string, open path
                        iny                             ; inc source index
                        cmp     #'/'                    ; is path separator?
                        beq     @openpath               ; branch if yes
                        sta     SCRATCHBUF,x      ; store path char into component
                        inx                             ; increment component index
                        tya                             ; test source index
                        bne     @pathcharloop           ; if not wrapped, loop
                        lda     #FSERR_BADPATH   ; source path too long
                        sta     FS_ZP_ERRORCODE         ; set error code
                        bra     @fail                   ; fail return

@openpath:              stz     SCRATCHBUF,x      ; NUL terminal path component
                        phy                             ; save source index on stack
                        cpy     #1                      ; initial slash?
                        bne     @notroot                ; branch if not
                tprint  ":"
                        jsr     fat32_openroot          ; read root
                        bra     @popcheckfail           ; pop source index and check error
@notroot:
                tprint  "/"
                        clc                             ; clear error
                        lda     SCRATCHBUF              ; is this empty component?
                        beq     @popcheckfail           ; branch if yes (ignore)
                .if FAT_TRACE
                        lda     #<SCRATCHBUF
                        ldx     #>SCRATCHBUF
                        jsr     PRINT
                tprint  "\r\n"
                .endif
                        lda     #<SCRATCHBUF      ; find path component in current dirent
                        ldx     #>SCRATCHBUF
                        jsr     fat32_finddirent
                        bcs     @popcheckfail
                        jsr     fat32_opendirent
@popcheckfail:          ply
                        bcs     @fail
                        lda     (fat32_userfilename),y
                        bne     @pathpart
@done:                  clc
                        rts
@fail:                  sec
                        rts


; Read a byte from an open file
;
; The byte is returned in A with C clear; or if end-of-file was reached, C is set instead
; TODO: more than A

_FAT_READBYTE:
                        stz     FS_ZP_ERRORCODE

                        ; Is there any data to read at all?
                        lda     FS_ZP_BYTESLEFT
                        ora     FS_ZP_BYTESLEFT+1
                        ora     FS_ZP_BYTESLEFT+2
                        ora     FS_ZP_BYTESLEFT+3
                        beq     @eof

                        ; Decrement the remaining byte count
                        lda     FS_ZP_BYTESLEFT
                        sec
                        sbc     #1
                        sta     FS_ZP_BYTESLEFT
                        lda     FS_ZP_BYTESLEFT+1
                        sbc     #0
                        sta     FS_ZP_BYTESLEFT+1
                        lda     FS_ZP_BYTESLEFT+2
                        sbc     #0
                        sta     FS_ZP_BYTESLEFT+2
                        lda     FS_ZP_BYTESLEFT+3
                        sbc     #0
                        sta     FS_ZP_BYTESLEFT+3

                        ; Need to read a new sector?
                        lda     FW_ZP_IOPTR+1
                        cmp     #>(FILESYSBUF+$200)
                        blt     @gotdata

                        ; Read another sector
                        lda     #<FILESYSBUF
                        sta     FS_ZP_ADDRPTR
                        lda     #>FILESYSBUF
                        sta     FS_ZP_ADDRPTR+1

                        jsr     fat32_readnextsector
                        bcs     @fail
                        cmp     #0
                        beq     @eof
@gotdata:
                        lda     (FW_ZP_IOPTR)

                        inc     FW_ZP_IOPTR
                        bne     @done
                        inc     FW_ZP_IOPTR+1
@done:
                        clc
                        rts

@eof:                   lda     #FSERR_EOF
                        sta     FS_ZP_ERRORCODE
@fail:
                        lda     #$FF
                        sec
                        rts

; Read a whole file into memory. It's assumed the file has just been opened
; and no data has been read yet.
;
; Also we read whole sectors, so data in the target region beyond the end of the
; file may get overwritten, up to the next 512-byte boundary.
;
; supports incrementing rosco_6502 RAM bank at $C000, but must load at address divisible by $0200
;
_FAT_READFILE:
                        lda     BANK_SET
                        pha

                        stz     FS_ZP_ERRORCODE

                        ; add $01ff to round up number of sectors
                        lda     FS_ZP_BYTESLEFT
                        clc
                        adc     #$FF
                        sta     FS_ZP_BYTESLEFT
                        lda     FS_ZP_BYTESLEFT+1
                        adc     #1
                        sta     FS_ZP_BYTESLEFT+1
                        lda     FS_ZP_BYTESLEFT+2
                        adc     #0
                        sta     FS_ZP_BYTESLEFT+2

@sectorreadloop:
                        ; check if 24-bit count zero (ignoring low byte)
                        lda     FS_ZP_BYTESLEFT+2
                        ora     FS_ZP_BYTESLEFT+1
                        ; No data?
                        beq     @done

@readsector:            ; Read entire sectors to the user-supplied buffer
                        ; Read a sector to FS_ZP_ADDRPTR
                        jsr     fat32_readnextsector
                        bcs     @fail
                        cmp     #0
                        beq     @done

                        ; Advance FS_ZP_ADDRPTR by 512 bytes
                        lda     FS_ZP_ADDRPTR+1
                        adc     #2                      ; carry already clear
                        sta     FS_ZP_ADDRPTR+1
                        cmp     #>(BANK_RAM_ADDR+BANK_RAM_SIZE)
                        blt     @notnextbank
                        lda     BANK_SET
                        and     #BANK_RAM_M
                        cmp     #BANK_RAM_M
                        beq     @eom                    ; already in last RAM bank, so quit with error
                        inc     BANK_SET
                        lda     #>BANK_RAM_ADDR
                        sta     FS_ZP_ADDRPTR+1

@notnextbank:           lda     FS_ZP_BYTESLEFT+1  ; subtract $0200 (sector size)
                        sec
                        sbc     #$02
                        sta     FS_ZP_BYTESLEFT+1
                        lda     FS_ZP_BYTESLEFT+2
                        sbc     #$00
                        sta     FS_ZP_BYTESLEFT+2
                        bcs     @sectorreadloop         ; loop until underflow
@done:
                        clc
                        pla
                        sta     BANK_SET
                        rts
@eom:                   lda     #FSERR_TRUNCATED
                        sta     FS_ZP_ERRORCODE
@fail:                  sec
                        pla
                        sta     BANK_SET
                        rts
