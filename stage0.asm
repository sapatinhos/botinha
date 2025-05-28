bits 16
org 0x7c00

%define STACK 0x7c00
%define VIDEO 0xb8000

; string operations go forward
cld

; initialize segment registers
xor ax, ax
mov es, ax
mov ds, ax
mov ss, ax

; set stack pointers
mov sp, STACK
mov bp, STACK

; print hello
mov si, 0
print_hello:
    mov ah, 0x0e                ; display char code
    mov al, [hello + si]        ; move char into al
    int 0x10                    ; video interrupt
    add si, 1
    cmp byte [hello + si], 0    ; check for null terminator
    jne print_hello

; enable protected mode

; disable interrupts, including NMI
cli
in al, 0x70
or al, 0x80
out 0x70, al
in al, 0x71

; enable A20
in al, 0x92     ; this may cause problems for very old systems
or al, 2
out 0x92, al

; load gdt
lgdt [gdtr]

; set PE bit
smsw ax
or   ax, 1
lmsw ax

bits 32

; print protected
push protected
call print32

jmp $

; functions
; print a string in protected mode
print32:
    push ebp
    mov  ebp, esp

    mov  esi, [ebp + 16]        ; read string address into eax

    xor  eax, eax
.loop:
    mov  dh, [esi + eax]
    mov  dl, 0x07
    mov  [VIDEO], dx
    inc  eax
    cmp  byte [esi + eax], 0     ; check for null terminator
    jne  print32.loop

    pop ebp
    ret

; data
hello:
    db "sapatinhos v0.1", 0

protected:
    db "protected", 0

; GDT
gdtr:
    dw gdtend - gdt ; gdt size
    dd gdt          ; gdt offset
gdt:
    ; null descriptor

    dq 0

    ; cs

    dw 0xffff       ; limit [15:0]
    dw 0x0000       ; base [15:0]
    db 0x00         ; base [23:16]
    db 0b10011011   ; access byte
    db 0b01001111   ; flags [3:0] limit [51:48]
    db 0x00         ; base [63:56]

    ; ds

    dw 0xffff       ; limit [15:0]
    dw 0x0000       ; base [15:0]
    db 0x00         ; base [23:16]
    db 0b10010011   ; access byte
    db 0b01001111   ; flags [3:0] limit [51:48]
    db 0x00         ; base [63:56]

gdtend:

times 510 - ($ - $$) db 0
dw 0xaa55
