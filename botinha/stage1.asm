bits 16
org 0x7c00

; memory layout ---------------------------------------------------------------

%define STACK 0x7c00            ; stack's base address      - 0x800  .. 0x7bff
%define STATIC 0x7e00           ; static variables          - 0x7e00 .. 0x7fff
%define READ_BUFFER 0x8000      ; next stage load location  - 0x8000 .. 0x7ffff

; globals ---------------------------------------------------------------------

%define PART_ENTRY STATIC       ; -> current partition mbr entry        (word)
%define FAT_START STATIC + 2    ; # first sector of the fat             (dword)
%define ROOT_START STATIC + 6   ; # first sector of the root directory  (dword)
%define DATA_START STATIC + 10  ; # first sector of the data section    (dword)

; video -----------------------------------------------------------------------

%define VGA_SEG 0xb800              ; hardware mapped memory
%define VGA_COL 80                  ; # columns
%define VGA_ROW 25                  ; # rows
%define VGA_LENW VGA_COL * VGA_ROW  ; length in words
%define PRINT_COLOR 0x07            ; grey on black

; bpb header ------------------------------------------------------------------

bs_jmpboot:     jmp short entry
                nop
bs_oemname:     db "SPTSBOOT"   ; oem string

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
mov bp, STACK
mov sp, bp

; save initial state
mov [bs_drvnum], dl             ; save drive number
mov [PART_ENTRY], si            ; save -> mbr partition entry

; get fat offsets -------------------------------------------------------------

; fatstart = partstart + rsvdseccnt
mov ebx, [si + 0x8]                 ; ebx = partition start LBA
movzx eax, word [bpb_rsvdseccnt]    ; eax = # reserved sectors

add ebx, eax                        ; ebx = fatstart

mov [FAT_START], ebx                ; save fatstart

; rootstart = fatstart + (fatsz * numfats)
movzx eax, word [bpb_fatsz16]       ; eax = fatsz
movzx ecx, byte [bpb_numfats]       ; ecx = numfats

mul ecx                             ; eax = fatsz * numfats
                                    ; && edx = 0
add ebx, eax                        ; ebx = rootstart

mov [ROOT_START], ebx               ; save rootstart

; datastart = rootstart + (rootentcnt * 32) / bytespersec
movzx eax, word [bpb_rootentcnt]    ; eax = rootentcnt
movzx ecx, word [bpb_bytspersec]    ; ecx = bytespersec

shl eax, 5                          ; eax = (rootentcnt * 32)
div ecx                             ; eax = (rootentcnt * 32) / bytespersec
                                    ; && edx = 0
add ebx, eax                        ; ebx = datastart

mov [DATA_START], ebx               ; save datastart

; find next stage -------------------------------------------------------------

cld                             ; string ops go forward
mov eax, [ROOT_START]           ; eax = rootstart
xor bx, bx                      ; bx = # current entry
mov di, READ_BUFFER             ; write sector to READ_BUFFER

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
mov cx, READ_BUFFER             ; cx = READ_BUFFER
add cx, [bpb_bytspersec]        ; cx = READ_BUFFER + bytespersec
cmp di, cx                      ; if di is out of bounds,
jge next_sector                 ;  load next sector

jmp next_entry

; load next stage -------------------------------------------------------------

found:
mov ax, [di + 0x1a]             ; ax = first cluster
mov di, READ_BUFFER             ; write next stage to READ_BUFFER
call readclusters

jmp 0x0000:READ_BUFFER          ; execute next stage

; functions -------------------------------------------------------------------

; lba read from active disk ---------------------------------------------------

; input:
; eax           = lba address
; es:di         = -> destination buffer
; cx            = # sectors to read

; output:
; eax           += cx
; es:di         += cx * bpb_bytspersec

readsectors:
    push bp
    mov bp, sp

    ; build disk address packet
    push dword 0x0              ; lba
    push eax                    ;  address
    push es                     ; -> destination
    push di                     ;  buffer
    push cx                     ; # blocks to read
    push word 0x10              ; packet size

    ; set parameters
    mov si, sp                  ; ds:si -> packet
    mov dl, [bs_drvnum]         ; dl = drive number

    ; read from disk
    mov ah, 0x42                ; extended
    int 0x13                    ;  read
    jc  err_readerr             ; die on error

    ; es:di += cx * bpb_bytspersec
    mov ax, [bpb_bytspersec]    ; ax = bytespersec
    mul cx                      ; dx:ax = cx * bytespersec

    shl dx, 12                  ; make dx bit-aligned as a segment register
    mov cx, es                  ; cx = es
    add cx, dx                  ; cx += dx

    add di, ax                  ; di += ax
    jnc .no_carry

    add ch, 0x10                ; cx += (1<<12)

.no_carry:
    mov es, cx                  ; es += dx + carry

    ; eax += cx
    mov eax, [bp - 8]           ; restore eax = lba address
    movzx ecx, word [bp - 14]   ; ecx = cx
    add eax, ecx                ; eax += cx

    add sp, 0x10                ; free packet

    pop bp
    ret

; read a cluster chain into memory --------------------------------------------

; input:
; ax            = first cluster number
; es:di         = -> destination buffer

readclusters:
    push bp
    mov bp, sp

    push bx
    push ax                     ; save current cluster #
    push es                     ; save initial es value
    push di                     ; save initial di value

    ; get next cluster #
    mov cx, [bpb_bytspersec]    ; cx = # bytes per sector
    shr cx, 1                   ; cx = # FAT16 entries per sector

    xor dx, dx                  ; dx = 0
    div cx                      ; ax = FAT sector #
    mov bx, dx                  ; bx = entry offset in FAT sector

    movzx eax, ax               ; zero eax high bits
    add eax, [FAT_START]        ; eax = lba address of wanted FAT sector
    mov cx, 1                   ; cx = 1 sector
    call readsectors            ; read FAT sector into es:di

    pop di                      ; restore di
    pop es                      ; restore es

    shl bx, 1                   ; bx = entry offset in bytes
    mov bx, [es:di + bx]        ; bx = next cluster #

    ; read current cluster
    pop ax                              ; ax = current cluster #
    sub ax, 2                           ; ax -= 2
    movzx eax, ax                       ; zero eax high bits
    movzx ecx, byte [bpb_secperclus]    ; ecx = sectors per cluster
    mul ecx                             ; eax *= ecx
    add eax, [DATA_START]               ; eax = lba address of cluster
    call readsectors

    ; read next cluster
    mov ax, bx                  ; ax = next cluster #
    cmp ax, 0xfff8              ; cluster # >= 0xfff8 is eof
    jge .eof

    call readclusters           ; if not eof, follow cluster chain

.eof:

    pop bx
    pop bp
    ret

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
.nextstg:
    db "KERNEL     "

.readerr:
    db "disk read error", 0

.notfound:
    db "loader not found", 0

times 510 - ($ - $$) db 0
dw 0xaa55
