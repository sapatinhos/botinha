%ifndef DEFS_ASM
%define DEFS_ASM

; memory layout ---------------------------------------------------------------

%define STACK 0x7c00            ; stack's base address      - 0x800  .. 0x7bff
%define STATIC 0x7e00           ; static variables          - 0x7e00 .. 0x7fff
%define READ_BUFFER 0x8000      ; next stage load location  - 0x8000 .. 0x7ffff

; globals ---------------------------------------------------------------------

%define PART_ENTRY STATIC       ; -> current partition mbr entry        (word)
%define FAT_START STATIC + 2    ; # first sector of the fat             (dword)
%define ROOT_START STATIC + 6   ; # first sector of the root directory  (dword)
%define DATA_START STATIC + 10  ; # first sector of the data section    (dword)

; video -----------------------------------------------------------------------

%define VGA_SEG 0xb800              ; hardware mapped memory
%define VGA_COL 80                  ; # columns
%define VGA_ROW 25                  ; # rows
%define VGA_LENW VGA_COL * VGA_ROW  ; length in words
%define PRINT_COLOR 0x07            ; grey on black
%define FILL_CHAR 0xfa              ; middle dot

;------------------------------------------------------------------------------

%endif
