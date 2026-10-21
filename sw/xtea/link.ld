SECTIONS
{
    . = 0x00000000;
    .text : {
        *entry.o(.text*)
        *(.text*)
    }
    .rodata : { *(.rodata*) }
    .data : { *(.data*) }
    .bss : { *(.bss*) }
}
