%ifndef READSECTORS_ASM
%define READSECTORS_ASM

; lba read from active disk ---------------------------------------------------

; input:
; eax           = lba address
; es:di         = -> destination buffer
; cx            = # sectors to read
; dl            = drive number

; output:
; eax           += cx
; es:di         += cx * bpb_bytspersec
; dl            = drive number

readsectors:
    push bp
    mov bp, sp

    push dx                     ; save drive number

    ; build disk address packet
    push dword 0x0              ; lba
    push eax                    ;  address
    push es                     ; -> destination
    push di                     ;  buffer
    push cx                     ; # blocks to read
    push word 0x10              ; packet size

    ; set parameters
    mov si, sp                  ; ds:si -> packet

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
    mov eax, [bp - 10]          ; restore eax = lba address
    movzx ecx, word [bp - 16]   ; ecx = cx
    add eax, ecx                ; eax += cx

    add sp, 0x10                ; free packet
    pop dx                      ; restore drive number

    pop bp
    ret

%endif
