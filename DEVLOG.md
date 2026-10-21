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
* 'src/controller.sv': add new signal outputs
* 'src/datapath.sv': add imm_gen instance
* 'src/riscv_core.sv': connect new outputs in controller & inputs in datapath
* 'tb/tb_riscv_core_r_type.sv': new
* 'tb/tb_riscv_core_i_type.sv': new



## 17-18.10.2026: I-Type: OP_LOAD (Load), S-Type (Store) instructions support; I-Type: OP_LOAD, S-Type testbenches


### Architectural Decisions:
- Add a `Load Extender` module to extract, align, and sign-/zero-extend data read from DMEM based on access size and alignment (`LW`, `LH`/`LHU`, `LB`/`LBU`).
- Add a `Store Formatter` module to steer write data onto the appropriate byte lanes for sub-word accesses (`SW`, `SH`, `SB`) and generate the corresponding 4-bit byte-enable mask (`dmem_data_en`).
- Extend the `riscv_core` top-level interface to export both the global DMEM write-enable flag and the 4-bit byte-enable mask.
- Update `controller`, `alu_ctrl`, and `imm_gen` modules to decode and drive control signals for Load (I-Type) and Store (S-Type) instructions.


### Components:
* 'src/load_extender.sv': new
* 'src/store_formatter.sv': new
* 'src/controller.sv': add new signal outputs
* 'src/datapath.sv': add load_extender, store_formatter instances. update connections
* 'src/riscv_core.sv': add new dmem_data_en output. update connections
* 'src/alu_ctrl.sv': additional cases
* 'src/imm_gen.sv': additional cases
* 'tb/tb_riscv_core_load.sv': new
* 'tb/tb_riscv_core_store.sv': new



### 19.10.2026: B-Type, JALR, J-Type, U-Type instructions support; B-Type, JALR, J-Type, U-Type testbenches


### Architectural Decisions:
* Add a dedicated `Branch Comparator` module. The module compares 32-bit register outputs (`data_a`, `data_b`) and asserts condition flags: `BrEq` (`data_a == data_b`) and `BrLt` (`data_a < data_b`). This design frees the main ALU to compute the target branch address (`PC + imm`) within the same single cycle. Eliminates the need for a separate 32-bit branch address adder and centralizes branch-decision logic in the controller rather than scattering condition-check hardware across the datapath.
* Add `ALU_B_PASS` operation to forward `op_b` directly to the output regardless of `op_a`, enabling `LUI` execution without adding extra inputs to the Writeback multiplexer or complicating datapath routing.
* Update Controller & ALU Controller logic.
* Update Datapath & Riscv-core top-module connections.


### Components:
* 'src/branch_comp.sv': new
* 'src/datapath.sv': add branch_comp instance. update connections
* 'src/riscv_core.sv': update connections
* 'src/controller.sv': additional cases
* 'src/alu_ctrl.sv': additional cases
* 'src/imm_gen.sv': additional cases
* 'tb/tb_riscv_core_b_type.sv': new
* 'tb/tb_riscv_core_jalr.sv': new
* 'tb/tb_riscv_core_j_type.sv': new
* 'tb/tb_riscv_core_lui.sv': new
* 'tb/tb_riscv_core_auipc.sv': new



### 20.10.2026: System & Fence instructions stubs (NOP handling); Bare-metal environment support


### Architectural Decisions:
- Add explicit NOP decoding for `OPC_FENCE` (`FENCE`, `FENCE.I`) and `OPC_SYSTEM` (`ECALL`, `EBREAK`, `CSR*`). For an unpipelined, single-cycle, no-cache core running in a bare-metal environment, memory barriers and trap/system calls are handled as benign NOPs (`RegWEn = 0`, `MemRW = 0`, `PCSel = 0`). This ensures safety against compiler-inserted barriers and eliminates unhandled opcode synthesis warnings.


### Components:
- 'src/riscv_pkg.sv': add `OPC_FENCE` to `opcode_e` enum
- 'src/controller.sv': additional cases for `OPC_FENCE` and `OPC_SYSTEM` as NOP decoding branches












