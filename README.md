# Single-Cycle RV32I RISC-V Processor Core - Summer Project

A synthesized and functionally verified single-cycle RISC-V processor core implemented in SystemVerilog. The core supports the complete base RV32I integer instruction set and executes bare-metal compiled C programs.

---

## Architectural Highlights

- **Architecture:** RV32I Base Integer Instruction Set (Single-Cycle Microarchitecture).
- **Instruction Support (37/37 base integer instructions):**
  - **R-Type:** `ADD`, `SUB`, `SLL`, `SLT`, `SLTU`, `XOR`, `SRL`, `SRA`, `OR`, `AND`
  - **I-Type:** `ADDI`, `SLTI`, `SLTIU`, `XORI`, `ORI`, `ANDI`, `SLLI`, `SRLI`, `SRAI`
  - **Load/Store:** `LB`, `LH`, `LW`, `LBU`, `LHU` / `SB`, `SH`, `SW`
  - **Control Flow:** `BEQ`, `BNE`, `BLT`, `BGE`, `BLTU`, `BGEU`, `JAL`, `JALR`
  - **Upper Immediate:** `LUI`, `AUIPC`
  - **System / Sync:** Safe NOP decoding for `FENCE`, `FENCE.I`, and `SYSTEM` (`ECALL`/`EBREAK`/`CSR*`) opcodes to support bare-metal execution environments.
- **Hardware Implementations:**
  - **Dedicated Branch Comparator:** Resolves branch condition flags (`BrEq`, `BrLt`) directly from register operands in parallel with operand routing. This allows the main ALU to calculate branch target addresses (`PC + imm`) within the same cycle without requiring an extra branch adder.
  - **ALU Pass-Through (`ALU_B_PASS`):** Routes upper immediate values directly to the register writeback path for `LUI`, avoiding additional multiplexer stages.
  - **Sub-Word Memory Logic:** Integrated `Load Extender` (sign/zero extension) and `Store Formatter` (byte-lane alignment with 4-bit write-enable mask generation).

---

## Synthesis & Timing Analysis

The design was synthesized, placed, and routed using Intel Quartus Prime targeting a Cyclone V FPGA.

| Metric | Result |
| :--- | :--- |
| **Target Device** | Intel Cyclone V (5CSXFC6D6F31C6) |
| **Logic Utilization** | 1,283 ALMs |
| **Dedicated Registers** | 1,024 (992 RegFile bits + 32-bit PC) |
| **Target Clock Constraint** | 50.0 MHz (Period: 20.0 ns via `timing.sdc`) |
| **Critical Path Data Delay** | 17.49 ns |
| **Worst-Case Setup Slack** | **+2.206 ns** (Timing Met / Closed) |
| **Maximum Frequency ($F_{max}$)** | **56.2 MHz** (Slow 85°C timing model) |
| **Critical Path** | `RegFile` Read (`rs1`) $\rightarrow$ ALU Input Mux $\rightarrow$ 32-bit Comparator (`SLT`/`SLTU`) $\rightarrow$ Writeback Mux $\rightarrow$ `RegFile` Data Setup (`asdata`) |

---

## Verification

The core was verified across two layers using Siemens ModelSim:

### 1. Directed RTL Unit Tests
Dedicated self-checking SystemVerilog testbenches located in `tb/` covering corner cases, immediate sign extension, byte-lane masking, and link-register dependencies:
- R-Type arithmetic and shifts (`tb_riscv_core_r_type.sv`)
- Immediate operations (`tb_riscv_core_i_type.sv`)
- Sub-word load/store alignments (`tb_riscv_core_load_store.sv`)
- Signed/unsigned branch evaluations (`tb_riscv_core_b_type.sv`)
- Control transfers and linkages (`tb_riscv_core_jalr.sv`, `tb_riscv_core_j_type.sv`)
- Upper immediate addressing (`tb_riscv_core_lui.sv`, `tb_riscv_core_auipc.sv`)

### 2. Bare-Metal Software Execution (XTEA Cipher)
End-to-end integration verification was performed by running a bare-metal C implementation of the **XTEA (Extended Tiny Encryption Algorithm)** 64-bit block cipher:
- **Toolchain:** Compiled with `riscv32-unknown-elf-gcc` (`-march=rv32i -mabi=ilp32 -O2 -nostdlib -ffreestanding`).
- **Memory Layout:** Custom vector reset entry (`entry.s`) and linker script (`link.ld`) mapping text and data segments.
- **Execution:** 1,629 clock cycles executed in simulation.
- **Verification:** Correct encryption to ciphertext and subsequent decryption back to original plaintext (`0x00C0FFEE`, `0xFEE1600D`) verified via automated memory assertions.

---

## Project Structure

```text
├── src/            # Synthesizable SystemVerilog core RTL
├── tb/             # RTL testbenches
├── sw/             # Bare-metal software sources
│   └── xtea/       # XTEA C source, entry.s, link.ld, disassembly (.asm), and hex image
├── sim/            # Automated simulation scripts (run_xtea.do)
├── quartus/        # Quartus Prime project files (.qpf, .qsf) and timing constraints (.sdc)
├── DEVLOG.md       # Chronological engineering decisions and milestone log
└── LICENSE         # MIT License
```

---

## Simulation Quickstart

Run the automated bare-metal verification in ModelSim / Questa:

```bash
cd sim
vsim -c -do run_xtea.do
```

The script compiles the full package, RTL hierarchy, and testbench, automatically locates `sw/xtea/program.hex`, runs execution to halt, and verifies memory contents:

```text
[TB] Successfully located firmware: ../sw/xtea/program.hex

=======================================================
  SIMULATION HALT DETECTED AT PC = 0x00000190
  Total execution cycles: 1629
=======================================================

--- Final Memory Verification ---
Data[0] Word Index: 105 (Addr: 0x000001A4) = 0x00C0FFEE
Data[1] Word Index: 106 (Addr: 0x000001A8) = 0xFEE1600D

==================================================================
>>> [PASS] XTEA encryption & decryption verified successfully! <<<
==================================================================
```

---

## License

This project is licensed under the MIT License — see the [LICENSE](LICENSE) file for details.