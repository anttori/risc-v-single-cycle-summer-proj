.section .text
.globl _start

_start:
    lui sp, 0x1          # Stack top = 0x1000 (top of the 4 KB data window, grows down into DMEM)
    jal ra, main         # Jump to main

halt:
    j halt               # Infinite loop fallback
