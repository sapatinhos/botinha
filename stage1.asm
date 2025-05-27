bits 16
org 0x7c00

cld
xor ax, ax
mov es, ax
mov ds, ax
mov ss, ax
mov sp, 0xe00

mov si, 0

print:
    mov ah, 0x0e
    mov al, [hello + si]
    int 0x10
    add si, 1
    cmp byte [hello + si], 0
    jne print

jmp $

hello:
    db "sapatinhos v0.1", 0

times 510 - ($ - $$) db 0
dw 0xaa55
