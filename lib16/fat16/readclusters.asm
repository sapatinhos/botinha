%ifndef READCLUSTERS_ASM
%define READCLUSTERS_ASM

; read a cluster chain into memory --------------------------------------------

; input:
; ax            = first cluster number
; es:di         = -> destination buffer

; output:
; es:di         += # written bytes

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

%endif
