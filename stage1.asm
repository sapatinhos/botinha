bits 16
org 0x7c00

%define STACK_BASE 0x7c00       ; stack's base address
%define PART_ENTRY bp - 2       ; -> current partition mbr entry
%define FAT_START bp - 6        ; # first sector of the fat
%define ROOT_START bp - 10      ; # first sector of the root directory
%define DATA_START bp - 14      ; # first sector of the data section
%define READBUFFER 0x8000       ; -> next stage

%define VGA_SEG 0xb800          ; video memory starts at 0xb8000
%define VGA_COL 80
%define VGA_ROW 25
%define VGA_LENW VGA_COL * VGA_ROW
%define PRINT_COLOR 0x07        ; grey on black

; bpb header ------------------------------------------------------------------

bs_jmpboot:     jmp short entry
                nop
bs_oemname:     dq 0            ; oem string

; bios parameter block --------------------------------------------------------

bpb_bytspersec: dw 0            ; # bytes per sector
bpb_secperclus: db 0            ; # sectors per cluster
bpb_rsvdseccnt: dw 0            ; # reserved sectors
bpb_numfats:    db 0            ; # fats
bpb_rootentcnt: dw 0            ; # entries in the root directory
bpb_totsec16:   dw 0            ; size of the volume in sectors (if =< 65535)
bpb_media:      db 0            ; media descriptor
bpb_fatsz16:    dw 0            ; size of a fat in sectors
bpb_secpertrk:  dw 0            ; # sectors per track
bpb_numheads:   dw 0            ; # heads
bpb_hiddsec:    dd 0            ; # hidden sectors
bpb_totsec32:   dd 0            ; size of the volume in sectors (if > 65535)

; extended boot record --------------------------------------------------------

bs_drvnum:      db 0            ; drive number
bs_reserved1:   db 0            ; reserved
bs_bootsig:     db 0x29         ; extended boot signature
bs_volid:       dd 0            ; volume serial number
bs_vollab:      times 11 db 0   ; volume label string
bs_filsystype:  db "FAT16   "   ; file system type string

; entry point -----------------------------------------------------------------

entry:

; initialize segment registers
xor ax, ax
mov ds, ax
mov es, ax
mov ss, ax

; set stack pointers
mov sp, STACK_BASE
mov bp, STACK_BASE

; save initial state
mov [bs_drvnum], dl             ; save drive number
mov [PART_ENTRY], si            ; save partition entry

; get fat offsets -------------------------------------------------------------

; rootstart = rsvdseccnt + (fatsz * numfats)
xor ebx, ebx
mov eax, [si + 0x8]             ; partition start lba address

add bx, [bpb_rsvdseccnt]
add eax, ebx

push eax                        ; save FAT_START

xor eax, eax
xor ebx, ebx
mov ax, [bpb_fatsz16]           ; ax = fatsz
mov bl, [bpb_numfats]           ; ax = fatsz * numfats
mul ebx
add eax, [FAT_START]

push eax                        ; save ROOT_START

; datastart = rootstart + (rootentcnt * 32) / bytespersec
xor eax, eax
xor ebx, ebx

mov ax, [bpb_rootentcnt]
shl eax, 5

mov bx, [bpb_bytspersec]
div ebx

add eax, [ROOT_START]
push ebx                        ; save DATA_START

; find loader -----------------------------------------------------------------

mov eax, [ROOT_START]
xor bx, bx ; bx = # current entry

; read sector
next_sector:
mov dl, [bs_drvnum]
mov di, READBUFFER
mov cx, 1
call read

; search for loader file name
next_entry:
inc bx
cmp bx, [bpb_rootentcnt]
jg err_notfound

mov cx, 11
mov si, str.loader
repe cmpsb
je  found

add di, 0x15

mov cx, READBUFFER
add cx, [bpb_bytspersec]
cmp di, cx 
jge next_sector

jmp next_entry
; ...

found:
mov dl, [bs_drvnum]
mov ax, [di + 0x1a]
mov di, READBUFFER  
call loadfile

jmp $

; functions -------------------------------------------------------------------

; lba read from active disk
; input:
; dl            = drive number
; eax           = lba address
; es:di         = -> destination buffer
; cx            = # sectors to read
; output:
; eax           = eax + cx
read:
    push bx
    push eax
    ; disk address packet
    push dword 0x0              ; lba
    push eax                    ;  address
    push es                     ;  buffer
    push di                     ; -> destination
    push cx                     ; # blocks to read
    push word 0x10              ; packet size

    mov si, sp                  ; ds:si -> packet

    mov ah, 0x42
    int 0x13
    jc  err_readerr

    add sp, 0x10

    mov ax, [bpb_bytspersec] 
    mul cx 
    
    add di, ax
    jnc no_carry
    
    mov bx, es
    add bx, (1<<12)
    mov es, bx

no_carry:
    mov bx, es
    shl dx, 12
    add bx, dx
    mov es, bx

    pop eax

    and ecx, 0x0000ffff
    add eax, ecx                

    pop bx
    ret

; input:
; dl            = drive number
; ax            = cluster number
; es:di         = -> destination buffer
loadfile:
    mov cx, [bpb_secperclus]
    mul cx
    shl ecx, 16
    add eax, ecx
    add eax, [DATA_START]
    
    

; errors ----------------------------------------------------------------------

err_notfound:
mov si, str.notfound
jmp printerr

err_readerr:
mov si, str.readerr

; print the error message string in ds:si and halt
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
lodsb                           ; al = [ds:si], si += 1
or  al, al                      ; on null terminator,
jz  halt                        ;  halt
stosw                           ; [es:di] = ax, di += 2
jmp write_char

halt:
cli                             ; disable interrupts
hlt
jmp halt

; data ------------------------------------------------------------------------

str:
.loader:
    db "loader     "

.readerr:
    db "disk read error", 0

.notfound:
    db "loader not found", 0

times 510 - ($ - $$) db 0
dw 0xaa55
