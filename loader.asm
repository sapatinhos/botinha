bits 16
org 0x8000

%define STACK 0x8000                ; where we are loaded initially

%define VGA_SEG 0xb800              ; video memory starts at 0xb8000
%define VGA_COL 80
%define VGA_ROW 25
%define VGA_LENW VGA_COL * VGA_ROW

%define FILL_CHAR 0xfa              ; middle dot
%define FILL_COLOR 0x01             ; blue on black
%define PRINT_COLOR 0x07            ; grey on black

; entry point -----------------------------------------------------------------

; initialize segment registers
xor ax, ax
mov ds, ax
mov es, ax
mov ss, ax

; set stack pointers
mov bp, STACK
mov sp, bp

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

mov si, str.hello

; print the error message string in si and halt
printerr:
xor di, di
mov ax, VGA_SEG
mov es, ax
mov ah, PRINT_COLOR

; es:di = video memory
; ds:si = error message
; al = current char
; ah = color attribute

write_char:
lodsb                   ; al = [ds:si], si += 1
or  al, al              ; on null terminator,
jz  halt                ;  halt
stosw                   ; [es:di] = ax, di += 2
jmp write_char

halt:
cli                     ; disable interrupts
hlt
jmp halt

; data ------------------------------------------------------------------------

str:
.hello:
    db "hello cruel world", 0

times 510 - ($ - $$) db 0   ; fill remaining bytes with zeroes
dw 0xaa55                   ; mbr magic byte
