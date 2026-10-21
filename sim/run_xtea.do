# 1. Clean up previous work library and create a fresh one
if [file exists work] {
    vdel -lib work -all
}
vlib work
vmap work work

# 2. Compile package and core RTL sources (strict dependency order)
vlog -sv ../src/riscv_pkg.sv
vlog -sv ../src/pc.sv
vlog -sv ../src/branch_comp.sv
vlog -sv ../src/load_extender.sv
vlog -sv ../src/store_formatter.sv
vlog -sv ../src/alu.sv
vlog -sv ../src/alu_ctrl.sv
vlog -sv ../src/imm_gen.sv
vlog -sv ../src/regfile.sv
vlog -sv ../src/controller.sv
vlog -sv ../src/datapath.sv
vlog -sv ../src/riscv_core.sv

# 3. Compile XTEA verification testbench
vlog -sv ../tb/tb_riscv_core_xtea.sv

# 4. Elaborate and load simulation
vsim -voptargs=+acc work.tb_riscv_core_xtea

# 5. Run simulation until $stop directive
run -all