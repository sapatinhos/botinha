bits 16
org 0x8000

%define STACK 0x8000                ; where we are loaded initially

%define VGA_SEG 0xb800              ; video memory starts at 0xb8000
%define VGA_MEM 0xb8000              ; video memory starts at 0xb8000
%define VGA_COL 80
%define VGA_ROW 25
%define VGA_LENW VGA_COL * VGA_ROW

%define FILL_CHAR 0xfa              ; middle dot
%define FILL_COLOR 0x01             ; blue on black
%define PRINT_COLOR 0x07            ; grey on black

%define EFLAGS_CPUID 0x200000
%define CPUID_EXT 0x80000000
%define CPUID_EXT_FEATURES 0x80000001
%define CPUID_LONG_MODE_FLAG 0x20000000 

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

; enter protected mode ------------------------------------------------------

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

push str.hello
call print32
pop eax

; check long mode support -----------------------------------------------------

pushfd
pop eax                     ; get eflags

mov ecx, eax
xor eax, EFLAGS_CPUID       ; flip 21th bit (id flag)

push eax
popfd                       ; commits changes to the eflags

pushfd
pop eax                     ; retrieve eflags to check if changes persisted

push ecx
popfd                       ; restore eflags

xor eax, ecx
jz err_nocpuid

mov eax, CPUID_EXT
cpuid                       ; queries max leaf value

cmp eax, CPUID_EXT_FEATURES
jb err_nocpuidext           ; check if it has required leaf level

mov eax, CPUID_EXT_FEATURES
cpuid                       ; query extended processor info
 
test edx, CPUID_LONG_MODE_FLAG
jz err_nolongmode

push FILL_CHAR
call clear_screen

push str.cpuid
call print32

jmp halt


; 16 bits functions -------------------------------------------------------------------
bits 16

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

; 32 bits functions -------------------------------------------------------------------
bits 32 

; print a string in protected mode
print32:
    push ebp
    mov  ebp, esp

    mov  esi, [ebp + 8]     ; read string address into eax
    mov  edi, VGA_MEM       ; write video address to edi

.loop:
    mov  dl, [esi]          ; set di to the current character
    mov  dh, PRINT_COLOR           ; print with dos colors
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

    mov  dl, FILL_COLOR           ; empty space to fill the screen
    mov  dh, [ebp + 8]      ; read color to fill screen

    mov  edi, VGA_MEM         ; load video memory adress

    mov  eax, VGA_LENW*2  ; load length of screen to fill, 2 bytes per cell

    mov  ecx, 0

.loop:
    mov [edi + ecx], dx     ; write to video memory

    add ecx, 2

    cmp ecx, eax            ; check if wrote to the whole screen
    jbe clear_screen.loop

    pop ebp
    ret

err_nocpuid:
push str.nocpuid
call print32
jmp halt

err_nocpuidext:
push str.nocpuidext
call print32
jmp halt

err_nolongmode:
push str.nolongmode
call print32
jmp halt


halt:
cli                     ; disable interrupts
hlt
jmp halt

; data ------------------------------------------------------------------------

str:
.hello:
    db "hello cruel world", 0

.cpuid:
    db "cpuid present", 0

.nocpuid:
    db "cpuid isnt available", 0

.nocpuidext:
    db "cpuid required extensions arent available", 0

.nolongmode:
    db "long mode not available", 0

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

