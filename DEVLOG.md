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

* 'src/alu.sv': new
* 'src/riscv\_pkg.sv': new
* 'src/datapath.sv': new
* 'tb/tb_datapath.sv': new



## 01-03.10.2026: PC, Controller, ALU controller, Risc-V Core Top Module Testbench

### Architectural Decisions
* Added RiscV Core top module connecting controllers and datapath. Contains IMEM interface (inst in, pc out). Will contain DMEM interface in future

### Components
* 'src/alu_ctrl.sv': new
* 'src/controller.sv': new
* 'src/risc_core.sv': new
* 'src/pc.sc': new
* 'src/riscv_pkg.sv': additional enums
* 'tb/riscv_core_add_sub.sv': new



## 12.10.2026: All R-Type instructions support & testbench; All I-Type: OP_IMM instructions support & testbench

### Architectural Decisions:
* Added additional ALU states to enum, Added additional cases in ALU controller and ALU.
* Created new Immediate Generator module, Updated Controller & ALU Controller, Added Imm Gen enum, updated connections in Top module & datapath.

### Components
* 'src/imm_gen.sv': new
* 'src/riscv_pkg.sv': additional enums
* 'src/alu_ctrl.sv': additional cases
* 'src/alu.sv': additional cases
* 'src/controller.sv': added new signal outputs
* 'src/datapath.sv': added imm_gen instance
* 'src/riscv_core.sv': connected new outputs in controller & inputs in datapath
* 'tb/tb_riscv_core_r_type.sv': new
* 'tb/tb_riscv_core_i_type.sv': new





