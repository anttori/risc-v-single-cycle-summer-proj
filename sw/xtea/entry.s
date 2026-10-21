.section .text
.globl _start

_start:
    lui sp, 0x1          # Set stack pointer
    jal ra, main         # Jump to main

halt:
    j halt               # Infinite loop fallback