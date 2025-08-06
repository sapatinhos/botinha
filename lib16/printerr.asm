%ifndef PRINTERR_ASM
%define PRINTERR_ASM

%include "lib16/defs.asm"

; print an error message string in ds:si and halt -----------------------------

printerr:
xor di, di
mov ax, VGA_SEG
mov es, ax
mov ah, PRINT_COLOR

; es:di = video memory
; ds:si = error message
; al = current char
; ah = color attribute

.write_char:
lodsb                           ; al = [ds:si], si += 1
or  al, al                      ; on null terminator,
jz  .halt                       ;  halt
stosw                           ; [es:di] = ax, di += 2
jmp .write_char

.halt:
cli                             ; disable interrupts
hlt
jmp .halt

;------------------------------------------------------------------------------

%endif
