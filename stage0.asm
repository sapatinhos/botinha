bits 16
org 0x7c00

%define STACK 0x7c00        ; set the stack to be below where we were loaded
%define VIDEO_SEG 0xb800    ; video memory starts at 0xb8000
%define VIDEO_LEN 0xfa0     ; the default mode (80x25) uses 0xfa0 bytes
%define VIDEO_COL 80
%define VIDEO_ROW 25
%define FILL_CHAR '.'
%define FILL_COLOR 0x04     ; red on black
%define PRINT_COLOR 0x0f    ; white on black

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
push hello_str
call print_str
add  sp, 2      ; pop hello_str

; string operations go forward
cld

; TODO

; relocate ourselves ...
call nl_cursor
push reloc_str
call print_str
add  sp, 2      ; pop reloc_str

; load second stage from disk ...
call nl_cursor
push load_str
call print_str
add  sp, 2      ; pop load_str

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

; moves the cursor to the next line
nl_cursor:
    push bp
    mov  bp, sp

    call get_cursor     ; ax = current cursor position
    mov  cx, ax         ; save ax in cx

    mov  dx, VIDEO_COL  ; zero dh and set dl to VIDEO_COL
    div  dl             ; ah = ax mod VIDEO_COL

    sub  dl, ah         ; dl = how many characters to reach the next line
    add  cx, dx         ; cx = next line cursor position

    push cx
    call set_cursor     ; update cursor position
    add  sp, 2          ; pop cx

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

    ; fs:di = address to write
    call get_cursor         ; ax = current cursor position
    shl  ax, 1
    mov  di, ax             ; di = video memory offset

    mov  ax, VIDEO_SEG
    mov  fs, ax             ; fs = video memory base address (>> 4)

    mov  si, [bp + 4]       ; si = string address
    mov  dh, PRINT_COLOR    ; dh = text color

.loop:
    mov  dl, [si]           ; dl = current character
    mov  [fs:di], dx        ; write to video memory

    inc  si                 ; go forward 1 byte on str address
    add  di, 2              ; go forward 2 bytes on video address

    cmp  byte [si], 0x0     ; check for null terminator
    jne  print_str.loop     ; if there are still characters to print, continue

    shr  di, 1              ; di = cursor position after printing the str
    push di
    call set_cursor         ; update cursor position
    add  sp, 2              ; pop di

    pop  bp
    ret

; data ------------------------------------------------------------------------

hello_str:
    db "Real mode", 0

reloc_str:
    db "Relocating", 0

load_str:
    db "Loading stage1", 0

notfound_str:
    db "Boot partition not found!", 0

times 510 - ($ - $$) db 0   ; fill remaining bytes with zeroes
dw 0xaa55                   ; mbr magic byte
