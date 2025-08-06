%ifndef BPB_ASM
%define BPB_ASM

%assign bpb_start   0x7c00

; bpb header ------------------------------------------------------------------

%assign bs_jmpboot      bpb_start       ; 3 bytes
%assign bs_oemname      bpb_start + 3   ; 8 bytes

; bios parameter block --------------------------------------------------------

%assign bpb_bytspersec  bpb_start + 11  ; 2 bytes
%assign bpb_secperclus  bpb_start + 13  ; 1 byte
%assign bpb_rsvdseccnt  bpb_start + 14  ; 2 bytes
%assign bpb_numfats     bpb_start + 16  ; 1 byte
%assign bpb_rootentcnt  bpb_start + 17  ; 2 bytes
%assign bpb_totsec16    bpb_start + 19  ; 2 bytes
%assign bpb_media       bpb_start + 21  ; 1 byte
%assign bpb_fatsz16     bpb_start + 22  ; 2 bytes
%assign bpb_secpertrk   bpb_start + 24  ; 2 bytes
%assign bpb_numheads    bpb_start + 26  ; 2 bytes
%assign bpb_hiddsec     bpb_start + 28  ; 4 bytes
%assign bpb_totsec32    bpb_start + 32  ; 4 bytes

; extended boot record --------------------------------------------------------

%assign bs_drvnum       bpb_start + 36  ; 1 byte
%assign bs_reserved1    bpb_start + 37  ; 1 byte
%assign bs_bootsig      bpb_start + 38  ; 1 byte
%assign bs_volid        bpb_start + 39  ; 4 bytes
%assign bs_vollab       bpb_start + 43  ; 11 bytes
%assign bs_filsystype   bpb_start + 54  ; 8 bytes

;------------------------------------------------------------------------------

%endif
