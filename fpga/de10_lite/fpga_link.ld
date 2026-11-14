/*
 * Linker script for the DE10-Lite build. Same layout as sw/xtea/link.ld
 * (code at 0x0), but the program may not use initialised/static data:
 * IMEM and DMEM are separate memories and DMEM is not preloaded.
 */
SECTIONS
{
    . = 0x00000000;
    .text : {
        *fpga_entry.o(.text*)
        *(.text*)
    }

    /DISCARD/ : { *(.comment) *(.riscv.attributes) *(.eh_frame*) }

    .rodata : { *(.rodata*) *(.srodata*) }
    .data   : { *(.data*) *(.sdata*) }
    .bss    : { *(.bss*) *(.sbss*) *(COMMON) }
}

ASSERT(SIZEOF(.rodata) == 0 && SIZEOF(.data) == 0 && SIZEOF(.bss) == 0,
       "fpga_test must not use .rodata/.data/.bss: DMEM is not preloaded")
