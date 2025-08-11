bits 16

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

%define PML4T_ADDR 0x1000
%define PDPT_ADDR 0x2000
%define PDT_ADDR 0x3000
%define PT_ADDR 0x4000

%define PT_SZ 4096
%define PT_ADDR_MASK 0xffffffffff000 
%define PT_PRESENT 1
%define PT_READABLE 2
%define PT_HUGEPAGE 1 << 7 

%define PAE_ENABLE 1 << 5

%define EFER_MSR 0xC0000080
%define EFER_LM_ENABLE 1 << 8

%define CR0_PM_ENABLE 1 << 0
%define CR0_PG_ENABLE 1 << 31

; Access bits
%define PRESENT   1 << 7
%define NOT_SYS   1 << 4
%define EXEC      1 << 3
%define DC        1 << 2
%define RW        1 << 1
%define ACCESSED  1 << 0

; Flags bits
%define GRAN_4K   1 << 7
%define SZ_32     1 << 6
%define LONG_MODE 1 << 5

%define VGA_TEXT_BUFFER_ADDR  0xb8000
%define COLS  80
%define ROWS  25
%define BYTES_PER_CHARACTER  2
%define VGA_TEXT_BUFFER_SIZE  BYTES_PER_CHARACTER * COLS * ROWS


extern kmain

; entry point -----------------------------------------------------------------

global startup_entry
startup_entry:

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
lgdt [gdtr32]

; set PE bit
smsw ax
or   ax, 1
lmsw ax

; clear pipeline and set cs register
jmp  gdt32.cs - gdt32 : pmode

bits 32

; set remaining segment registers
pmode:
mov  ax, gdt32.ds - gdt32
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

; setup paging ------------------------------------------------------------------------

mov edi, PML4T_ADDR
mov cr3, edi                

xor eax, eax
mov ecx, PT_SZ
rep stosd

mov edi, cr3

; setup page tables
mov DWORD [edi], PDPT_ADDR & PT_ADDR_MASK | PT_PRESENT | PT_READABLE

mov edi, PDPT_ADDR
mov DWORD [edi], PDT_ADDR & PT_ADDR_MASK | PT_PRESENT | PT_READABLE 

mov edi, PDT_ADDR
mov DWORD [edi], 0 & PT_ADDR_MASK | PT_PRESENT | PT_READABLE | PT_HUGEPAGE

; enable PAE
mov eax, cr4
or eax, PAE_ENABLE
mov cr4, eax

; enable long mode 
mov ecx, EFER_MSR
rdmsr
or eax, EFER_LM_ENABLE
wrmsr

; enable paging
mov eax, cr0
or eax, CR0_PG_ENABLE | CR0_PM_ENABLE   

mov cr0, eax

lgdt [GDT.Pointer]
jmp GDT.Code:Realm64

bits 64
Realm64:
cli   
; before even switching from real mode
mov ax, GDT.Data
mov ds, ax
mov es, ax
mov fs, ax
mov gs, ax
mov ss, ax

mov rdi, VGA_TEXT_BUFFER_ADDR
mov rax, (FILL_COLOR << 8) | FILL_CHAR
mov rcx, VGA_TEXT_BUFFER_SIZE / 8
rep stosq
jmp kmain
hlt

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

; GDT32
gdtr32:
    dw gdtend32 - gdt32 ; gdt size
    dd gdt32          ; gdt offset
gdt32:
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
gdtend32:

GDT:
    .Null: equ $ - GDT
        dq 0
    .Code: equ $ - GDT
        .Code.limit_lo: dw 0xffff
        .Code.base_lo: dw 0
        .Code.base_mid: db 0
        .Code.access: db PRESENT | NOT_SYS | EXEC | RW
        .Code.flags: db GRAN_4K | LONG_MODE | 0xF   ; Flags & Limit (high, bits 16-19)
        .Code.base_hi: db 0
    .Data: equ $ - GDT
        .Data.limit_lo: dw 0xffff
        .Data.base_lo: dw 0
        .Data.base_mid: db 0
        .Data.access: db PRESENT | NOT_SYS | RW
        .Data.Flags: db GRAN_4K | SZ_32 | 0xF       ; Flags & Limit (high, bits 16-19)
        .Data.base_hi: db 0
    .Pointer:
        dw $ - GDT - 1
        dq GDT
