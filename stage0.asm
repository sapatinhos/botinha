bits 16
org 0x600

%include "lib16/defs.asm"

%define LOAD 0x7c00                 ; where we are loaded initially
%define RELOC 0x600                 ; relocate to this address
%define START start                 ; absolute address for the label start

%define FILL_COLOR 0x04             ; red on black

%define PARTBL_ST RELOC + 0x1be     ; partition table start
%define PARTBL_END PARTBL_ST + 0x40 ; partition table end
%define SPTSBOOT_PTYPE 0x5a         ; sapatinhos boot partition type

; entry point -----------------------------------------------------------------

; initialize segment registers
xor ax, ax
mov ds, ax
mov es, ax
mov ss, ax

; set stack pointers
mov bp, STACK
mov sp, bp

; relocate ourselves
cld                         ; string operations go forward
mov si, sp                  ; source address
mov di, RELOC               ; destination address
mov cx, 0x100               ; move 256 words (512 bytes)
rep movsw                   ; move words until cx = 0
jmp 0x0000:START            ; jump to relocated code

start:

; clear screen ----------------------------------------------------------------

; disable cursor
mov ch, 0x3f
mov ah, 0x01
int 0x10

; clear video memory
mov cx, VGA_LENW
mov ax, VGA_SEG
mov es, ax
xor di, di
mov ax, (FILL_COLOR << 8) | FILL_CHAR

rep stosw                   ; fill cx words at es:di with ax

; scan partition table --------------------------------------------------------

; si = first partition table entry
mov si, PARTBL_ST

; check if the current entry is our boot partition
read_entry:
mov al, [si + 4]            ; al = partition type
cmp al, SPTSBOOT_PTYPE
je  load

; go to the next entry or die if not found
next_entry:
add si, 0x10
cmp si, PARTBL_END
jge err_notfound
jmp read_entry

; load next stage -------------------------------------------------------------

load:

; disk access extensions installation check
mov ah, 0x41
mov bx, 0x55aa

int 0x13
jc  err_noext               ; check failed

cmp bx, 0xaa55
jne err_noext               ; extensions are not installed

test cx, 1
jz  err_noext               ; function 42h is not supported

; build disk address packet
push si                     ; save si -> selected partition entry

push dword 0x0              ; lba
push dword [si + 0x8]       ;  address
push dword LOAD             ; read buffer address
push word 0x1               ; number of blocks to read
push word 0x10              ; packet size

mov si, sp                  ; ds:si -> packet

; disk access extensions extended read
mov ah, 0x42
int 0x13
jc err_readerr              ; read failed

add sp, 0x10                ; free packet
pop si                      ; restore si -> selected partition entry

jmp 0x0000:LOAD             ; execute next stage

; errors ----------------------------------------------------------------------

err_noext:
mov si, str.noext
jmp printerr

err_notfound:
mov si, str.notfound
jmp printerr

err_readerr:
mov si, str.readerr
jmp printerr

%include "lib16/printerr.asm"

; data ------------------------------------------------------------------------

str:
.notfound:
    db "boot partition not found", 0

.noext:
    db "lba read unavailable", 0

.readerr:
    db "disk read error", 0

times 510 - ($ - $$) db 0   ; fill remaining bytes with zeroes
dw 0xaa55                   ; mbr magic byte
