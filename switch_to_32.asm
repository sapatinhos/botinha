bits 16
org 0x8000

%define STACK 0x7c00
%define VIDEO 0xb8000
%define BLUE  0x11          ; blue foreground and blue background
%define LGBL  0x07          ; light gray foreground and black background
%define SCREEN_LEN 0x7d0

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

; enable protected mode

; disable maskable interrupts
cli

; disable non maskable interrupts
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

; clear pipeline and set cs register
jmp  gdt.cs - gdt : pmode

bits 32

; set remaining segment registers
pmode:
mov  ax, gdt.ds - gdt
mov  ds, ax
mov  ss, ax
mov  es, ax
mov  fs, ax
mov  gs, ax

push BLUE
call clear_screen

push hello
call print32

; halt
jmp $

; functions

; print a string in protected mode
print32:
    push ebp
    mov  ebp, esp

    mov  esi, [ebp + 8]     ; read string address into eax
    mov  edi, VIDEO         ; write video address to edi

.loop:
    mov  dl, [esi]          ; set di to the current character
    mov  dh, LGBL           ; print with dos colors
    mov  [edi], dx          ; write to video memory

    inc  esi
    add  edi, 2

    cmp  byte [esi], 0      ; check for null terminator
    jne  print32.loop       ; if there are still characters to print, continue

    pop ebp
    ret

clear_screen:
    push ebp
    mov  ebp, esp

    mov  dl, 0x20           ; empty space to fill the screen
    mov  dh, [ebp + 8]      ; read color to fill screen

    mov  edi, VIDEO         ; load video memory adress

    mov  eax, SCREEN_LEN*2  ; load length of screen to fill, 2 bytes per cell

    mov  ecx, 0

.loop:
    mov [edi + ecx], dx     ; write to video memory

    add ecx, 2

    cmp ecx, eax            ; check if wrote to the whole screen
    jbe clear_screen.loop

    pop ebp
    ret

; data
hello:
    db "sapatinhos v0.32", 0

; GDT
gdtr:
    dw gdtend - gdt ; gdt size
    dd gdt          ; gdt offset
gdt:
.null:
    dq 0
.cs:
    dw 0xffff       ; limit [15:0]
    dw 0x0000       ; base [15:0]
    db 0x00         ; base [23:16]
    db 0b10011011   ; access byte
    db 0b01001111   ; flags [3:0] limit [51:48]
    db 0x00         ; base [63:56]
.ds:
    dw 0xffff       ; limit [15:0]
    dw 0x0000       ; base [15:0]
    db 0x00         ; base [23:16]
    db 0b10010011   ; access byte
    db 0b01001111   ; flags [3:0] limit [51:48]
    db 0x00         ; base [63:56]
gdtend:

times 510 - ($ - $$) db 0
dw 0xaa55
