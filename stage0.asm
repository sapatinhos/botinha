bits 16
org 0x7c00

%define STACK 0x7c00        ; set the stack to be below where we were loaded
%define VIDEO_SEG 0xb800    ; video memory starts at 0xb8000
%define VIDEO_LEN 0xfa0     ; the default mode (80x25) uses 0xfa0 bytes
%define FILL_CHAR 0x20      ; space ascii code
%define FILL_COLOR 0x17     ; light gray foreground and blue background
%define PRINT_COLOR 0x07    ; light gray foreground and black background

; entry point -----------------------------------------------------------------

; initialize segment registers
xor ax, ax
mov ds, ax
mov es, ax
mov ss, ax

; set stack pointers
mov sp, STACK
mov bp, STACK

; clear screen and put a blue background
call clear_scr

; print a hello message
push hello
call print_str
add  sp, 2      ; pop hello

; string operations go forward
cld

; TODO

; relocate ourselves ...

; load second stage from disk ...

; halt
jmp $

; functions -------------------------------------------------------------------

; get current cursor position
get_cursor:
    mov  dx, 0x3d4  ; dx = io port
    mov  al, 0x0f   ; al = read / write

    out  dx, al     ; outb (0x3d4, 0x0f)

    inc  dx
    in   al, dx     ; pos |= inb (0x3d5)
    mov  cl, al

    mov  al, 0x0e
    dec  dx
    out  dx, al     ; outb (0x3d4, 0x0e)

    inc  dx
    in   al, dx     ; pos |= (inb (0x3D5) << 8)
    mov  ch, al

    mov  ax, cx     ; ax = cursor position

    ret

; set cursor position
set_cursor:
    push bp
    mov  bp, sp

    mov  cx, [bp + 4]   ; cx = cursor position
    and  cx, 0xffff

    mov  dx, 0x3d4      ; dx = io port
    mov  al, 0x0f       ; al = read / write

    out  dx, al         ; outb (0x3d4, 0x0f)

    inc  dx
    mov  al, cl
    out  dx, al         ; outb (0x3d5, (pos & 0xff))

    mov  al, 0x0e
    dec  dx
    out  dx, al         ; outb (0x3d4, 0x0e)

    inc  dx
    mov  al, ch
    out  dx, al         ; outb (0x3d5, ((pos >> 8 ) & 0xff))

    pop  bp
    ret

; fills video memory with FILL_CHARs colored FILL_COLOR
clear_scr:
    push bp
    mov  bp, sp

    ; dx = content to write
    mov  dl, FILL_CHAR
    mov  dh, FILL_COLOR

    ; fs:di = address to write
    mov  ax, VIDEO_SEG
    mov  fs, ax
    xor  di, di

.loop:
    mov  [fs:di], dx        ; write to video memory

    add  di, 2              ; go forward 2 bytes

    cmp  di, VIDEO_LEN      ; if we didn't write VIDEO_LEN bytes,
    jbe  clear_scr.loop     ;   repeat

    ; set cursor position to zero
    push 0x0
    call set_cursor
    add  sp, 2              ; pop 0x0

    pop  bp
    ret

; print a null-terminated string
print_str:
    push bp
    mov  bp, sp

    mov  si, [bp + 4]       ; si = string address
    mov  dh, PRINT_COLOR    ; dh = text color

    ; fs:di = address to write
    mov  ax, VIDEO_SEG
    mov  fs, ax
    xor  di, di

.loop:
    mov  dl, [si]           ; dl = current character
    mov  [fs:di], dx        ; write to video memory

    inc  si                 ; go forward 1 byte on str address
    add  di, 2              ; go forward 2 bytes on video address

    cmp  byte [si], 0x0     ; check for null terminator
    jne  print_str.loop     ; if there are still characters to print, continue

    pop  bp
    ret

; data ------------------------------------------------------------------------

hello:
    db "Real Mode", 0

times 510 - ($ - $$) db 0   ; fill remaining bytes with zeroes
dw 0xaa55                   ; mbr magic byte
