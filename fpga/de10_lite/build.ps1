<#
.SYNOPSIS
    Builds fpga_test.c into fpga_test.hex (one 32-bit word per line, padded with NOPs).

.DESCRIPTION
    Uses riscv32-unknown-elf-gcc, riscv64-unknown-elf-gcc or riscv-none-elf-gcc,
    whichever is found first in PATH. The hex file is loaded by fpga_imem.sv
    through $readmemh. Pass -BinFile to skip compilation and convert an
    already-built raw binary instead.

.PARAMETER Words
    IMEM depth in 32-bit words. Must match the IMEM_WORDS parameter of de10_lite_top.

.PARAMETER DefineArgs
    Extra compiler arguments, e.g. '-DANIM_STEP_ITERS=100' for a fast simulation build.

.PARAMETER Out
    Output hex file (default: fpga_test.hex next to this script).
#>
param(
    [int]$Words = 512,
    [string[]]$DefineArgs = @(),
    [string]$Out = (Join-Path $PSScriptRoot 'fpga_test.hex'),
    [string]$BinFile = ''
)

$ErrorActionPreference = 'Stop'

if (-not $BinFile) {
    $gcc = 'riscv32-unknown-elf-gcc', 'riscv64-unknown-elf-gcc', 'riscv-none-elf-gcc' |
        Where-Object { Get-Command $_ -ErrorAction SilentlyContinue } | Select-Object -First 1
    if (-not $gcc) { throw 'No RISC-V GCC (riscv32/64-unknown-elf-gcc, riscv-none-elf-gcc) found in PATH.' }
    $objcopy = $gcc -replace 'gcc$', 'objcopy'

    $elf = Join-Path $PSScriptRoot 'fpga_test.elf'
    $BinFile = Join-Path $PSScriptRoot 'fpga_test.bin'

    & $gcc -march=rv32i -mabi=ilp32 -O2 -nostdlib -ffreestanding -fno-jump-tables @DefineArgs `
        -T (Join-Path $PSScriptRoot 'fpga_link.ld') `
        (Join-Path $PSScriptRoot 'fpga_entry.s') (Join-Path $PSScriptRoot 'fpga_test.c') -o $elf
    if ($LASTEXITCODE -ne 0) { throw 'Compilation failed.' }

    & $objcopy -O binary $elf $BinFile
    if ($LASTEXITCODE -ne 0) { throw 'objcopy failed.' }
}

$bytes = [System.IO.File]::ReadAllBytes($BinFile)
$progWords = [int][math]::Ceiling($bytes.Length / 4)
if ($progWords -gt $Words) { throw "Program ($progWords words) does not fit in IMEM ($Words words)." }

$lines = New-Object System.Collections.Generic.List[string]
for ($i = 0; $i -lt $Words; $i++) {
    if ($i -lt $progWords) {
        $word = [uint32]0
        for ($b = 3; $b -ge 0; $b--) {
            $idx = 4 * $i + $b
            $word = ($word -shl 8) -bor $(if ($idx -lt $bytes.Length) { $bytes[$idx] } else { 0 })
        }
        $lines.Add($word.ToString('x8'))
    } else {
        $lines.Add('00000013')   # NOP (addi x0, x0, 0)
    }
}
[System.IO.File]::WriteAllLines($Out, $lines)
Write-Host "Wrote $Out ($progWords program words, $Words total)"
