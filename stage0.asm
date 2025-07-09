bits 16
org 0x600

%define LOAD 0x7c00             ; where we are loaded initially
%define RELOC 0x600             ; relocate to this address
%define VIDEO_SEG 0xb800        ; video memory starts at 0xb8000
%define VIDEO_LEN 0xfa0         ; the default mode (80x25) uses 0xfa0 bytes
%define VIDEO_COL 80
%define VIDEO_ROW 25
%define FILL_CHAR '.'
%define FILL_COLOR 0x04         ; red on black
%define PRINT_COLOR 0x0f        ; white on black
%define SPTS_PTYPE 0x5a         ; sapatinhos boot partition type byte
%define PARTBL RELOC + 0x1be    ; partition table start

; entry point -----------------------------------------------------------------

; TODO ensure cs is set to zero
;jmp 0 : LOAD + 3

; initialize segment registers
xor ax, ax
mov ds, ax
mov es, ax
mov ss, ax

; set stack pointers
mov sp, LOAD
mov bp, LOAD

; relocate ourselves
cld                         ; string operations go forward
mov  si, sp                 ; source address
mov  di, RELOC              ; destination address
mov  cx, 0x100              ; move 256 words (512 bytes)
rep                         ; repeat until cx = 0
movsw                       ; move words
jmp  start - LOAD + RELOC   ; jump to relocated code

start:
push dx                     ; save drive number
call clearscr               ; clear screen and reset cursor

; scan partition table for sapatinhos boot partition
mov si, PARTBL
xor cx, cx

read_entry:
mov al, [si + 4]            ; al = partition type
cmp al, SPTS_PTYPE
jz  load_stage1             ; if found, load
inc cx
cmp cx, 4
jge err_notfound
add si, 0x10
jmp read_entry

; load stage1 from disk and execute it
load_stage1:
pop dx                      ; dl = drive number
push si                     ; si = selected partition entry

; check if we can use int 13h fn 42h
mov ah, 0x41
mov bx, 0x55aa

int 0x13                    ; extensions installation check
jc  err_noext

cmp bx, 0xaa55
jne err_noext

test cx, 1
jz  err_noext

; disk address packet
sub sp, 0x10
mov bx, sp
mov byte [bx], 0x10         ; size of packet
mov byte [bx + 1], 0        ; reserved
mov word [bx + 2], 1        ; number of blocks to transfer
mov dword [bx + 4], LOAD    ; address to write

mov cx, 2                   ; LBA
add si, 0x8
lea di, [bx + 8]
rep movsw
mov dword [bx + 12], 0

mov si, sp                  ; ds:si -> disk address packet

mov ah, 0x42
int 0x13                    ; extended read
jc err_readerr

; success
push str.hello
call print
add  sp, 2                  ; pop hello_str

pop si
jmp bx                      ; execute stage1
jmp $                       ; halt

err_noext:
push str.noext
call print
jmp $                       ; halt

err_notfound:
push str.notfound
call print
jmp $                       ; halt

err_readerr:
push str.readerr
call print
jmp $                       ; halt

; functions -------------------------------------------------------------------

cursor:
; get current cursor position
.get:
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
.set:
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
.break:
    push bp
    mov  bp, sp

    call cursor.get     ; ax = current cursor position
    mov  cx, ax         ; save ax in cx

    mov  dx, VIDEO_COL  ; zero dh and set dl to VIDEO_COL
    div  dl             ; ah = ax mod VIDEO_COL

    sub  dl, ah         ; dl = how many characters to reach the next line
    add  cx, dx         ; cx = next line cursor position

    push cx
    call cursor.set     ; update cursor position
    add  sp, 2          ; pop cx

    pop  bp
    ret

; fills video memory with FILL_CHARs colored FILL_COLOR and reset cursor
clearscr:
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
    jbe  clearscr.loop     ;   repeat

    ; set cursor position to zero
    push 0x0
    call cursor.set
    add  sp, 2              ; pop 0x0

    pop  bp
    ret

; print a null-terminated string
print:
    push bp
    mov  bp, sp

    ; fs:di = address to write
    call cursor.get         ; ax = current cursor position
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
    jne  print.loop         ; if there are still characters to print, continue

    shr  di, 1              ; di = cursor position after printing the str
    push di
    call cursor.set         ; update cursor position
    add  sp, 2              ; pop di

    pop  bp
    ret

; data ------------------------------------------------------------------------

str:
.hello:
    db "sapatinhos16", 0

.notfound:
    db "boot partition not found!", 0

.noext:
    db "bios int 13h extensions not supported!", 0

.readerr:
    db "failed to read from disk!", 0

times 510 - ($ - $$) db 0   ; fill remaining bytes with zeroes
dw 0xaa55                   ; mbr magic byte
