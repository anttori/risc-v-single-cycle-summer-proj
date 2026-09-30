\# Development Log - RISC-V Single-Cycle Core





\## 29.09.2026: Project Start - Register File Implementation



\### Architectural Notes

* Implemented 32x32 register file matching RV32I specification.
* Read: Two asynch read ports.
* Write: Synch write on 'posedge clk' gated by 'RegWEn'.
* Hardwired zero: Register `x0` is statically wired to `32'b0` (writes to `x0` are ignored).



\### Components

* 'src/regfile.sv': new





\---





\## 30.09.2026: ALU, Package, Initial Datapat, ALU-Registers Testbench



\### Architectural Decisions 

* \*\*Memory Boundary:\*\* Kept Instruction Memory (`IMEM`) and Data Memory (`DMEM`) external to the `datapath` module. Datapath interfaces via standard `pc\[31:0]` (output) and `inst\[31:0]` (input) buses, maintaining core modularity.
* \*\*Centralized Types:\*\* Established `riscv\_pkg.sv` for unified enums (ALU operations, control signals) to enforce strict typing across `Controller` and `Datapath`.





\### Components

* 'src/alu.sc': new
* 'src/riscv\_pkg.sv': new
* 'src/datapath.sv': new
* 'tb/tb_datapath.sv': new





