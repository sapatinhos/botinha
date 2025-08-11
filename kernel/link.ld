STARTUP(startup.o)
INPUT(kernel.o)

ENTRY(startup_entry)

SECTIONS {
    . = 0x8000;
    .text : {
        startup.o(.text)
        EXCLUDE_FILE(startup.o) *(.text)
    }
    .data : { *(.data) }
    .bss  : { *(.bss) }
}
