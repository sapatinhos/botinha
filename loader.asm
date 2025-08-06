bits 16
org 0x8000

%include "lib16/defs.asm"
%include "lib16/bpb.asm"

%define FILL_COLOR 0x01         ; blue on black

; entry point -----------------------------------------------------------------

; initialize segment registers
xor ax, ax
mov ds, ax
mov es, ax
mov ss, ax

; set stack pointers
mov bp, STACK
mov sp, bp

; clear screen ----------------------------------------------------------------

; disable cursor
mov ch, 0x3f
mov ah, 0x01
int 0x10

; string ops go forward
cld

; clear video memory
mov cx, VGA_LENW
mov ax, VGA_SEG
mov es, ax
xor di, di
mov ax, (FILL_COLOR << 8) | FILL_CHAR

rep stosw                       ; fill cx words at es:di with ax

xor ax, ax
mov es, ax                      ; reset es

; find kernel -----------------------------------------------------------------

mov eax, [ROOT_START]           ; eax = rootstart
xor bx, bx                      ; bx = # current entry
mov di, KERNEL                  ; write sector to KERNEL

; root directory walk
next_sector:
push es                         ; save es
push di                         ; save di

mov cx, 1                       ; read 1 sector
call readsectors                ; eax++

pop di                          ; restore di
pop es                          ; restore es

; search sector for the next stage's entry
next_entry:
push di                         ; save di

; check current entry
mov cx, 11                      ; cx = # bytes for a filename
mov si, str.nextstg             ; si -> next stage's filename
repe cmpsb                      ; check if [es:di], [ds:si] filenames are equal
pop di                          ; restore di
je  found

; prepare for next iteration
inc bx                          ; bx++
cmp bx, [bpb_rootentcnt]        ; if bx >= bpb_rootentcnt,
jge err_notfound                ;  file not found

add di, 0x20                    ; di -> next entry

; advance sector ?
mov cx, KERNEL                  ; cx = KERNEL
add cx, [bpb_bytspersec]        ; cx = KERNEL + bytespersec
cmp di, cx                      ; if di is out of bounds,
jge next_sector                 ;  load next sector

jmp next_entry

; load next stage -------------------------------------------------------------

found:
mov ax, [di + 0x1a]             ; ax = first cluster
mov di, KERNEL                  ; write next stage to KERNEL

call readclusters

jmp 0x0000:KERNEL               ; execute kernel

; functions -------------------------------------------------------------------

%include "lib16/fat16/readsectors.asm"
%include "lib16/fat16/readclusters.asm"

; errors ----------------------------------------------------------------------

err_notfound:
mov si, str.notfound
jmp printerr

err_readerr:
mov si, str.readerr
jmp printerr

%include "lib16/printerr.asm"

; data ------------------------------------------------------------------------

str:
.nextstg:
    db "KERNEL  SYS"

.readerr:
    db "disk read error", 0

.notfound:
    db "kernel.sys not found", 0

; -----------------------------------------------------------------------------

jmp $
