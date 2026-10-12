`timescale 1ns / 1ps

import riscv_pkg::*;

module tb_riscv_core_i_type ();

    // ----------------------------------------------------
    // Interface signals
    // ----------------------------------------------------
    logic        clk;
    logic        resetN;
    logic [31:0] inst;
    logic [31:0] pc;

    // ----------------------------------------------------
    // Emulated Instruction Memory (IMEM)
    // ----------------------------------------------------
    logic [31:0] imem [0:15];

    // Format I-Type: {imm[11:0], rs1, funct3, rd, opcode}
    // opcode RV32I OP-IMM: 7'b0010011

    // 0: ADDI x1, x0, 15
    // rd = 1, rs1 = 0, imm = +15 (12'h00F) -> Expected x1: 32'd15
    assign imem[0] = {12'h00F, 5'd0, 3'b000, 5'd1, 7'b0010011};

    // 1: ADDI x2, x1, -50
    // rd = 2, rs1 = 1, imm = -50 (12'hFCE) -> 15 + (-50) = -35 -> Expected x2: 32'hFFFF_FFDD
    assign imem[1] = {12'hFCE, 5'd1, 3'b000, 5'd2, 7'b0010011};

    // 2: ADDI x3, x0, -2048 (Corner-case: min 12-bit signed immediate)
    // rd = 3, rs1 = 0, imm = -2048 (12'h800) -> Expected x3: 32'hFFFF_F800
    assign imem[2] = {12'h800, 5'd0, 3'b000, 5'd3, 7'b0010011};

    // 3: ADDI x4, x0, 2047  (Corner-case: max 12-bit signed immediate)
    // rd = 4, rs1 = 0, imm = +2047 (12'h7FF) -> Expected x4: 32'h0000_07FF
    assign imem[3] = {12'h7FF, 5'd0, 3'b000, 5'd4, 7'b0010011};

    // 4: ADDI x0, x1, 100   (x0 preservation check)
    // rd = 0, rs1 = 1, imm = +100 (12'h064) -> Expected x0: 32'd0
    assign imem[4] = {12'h064, 5'd1, 3'b000, 5'd0, 7'b0010011};

    // Instruction memory read
    assign inst = imem[pc[31:2]];

    // ----------------------------------------------------
    // DUT Instantiation
    // ----------------------------------------------------
    riscv_core u_riscv_core (
        .clk    (clk),
        .resetN (resetN),
        .inst   (inst),
        .pc     (pc)
    );

    // ----------------------------------------------------
    // Clock Generator (50 MHz, period = 20 ns)
    // ----------------------------------------------------
    initial begin
        clk = 1'b0;
        forever #10 clk = ~clk;
    end

    // ----------------------------------------------------
    // Verification Helper Task
    // ----------------------------------------------------
    task check_result (
        input string       inst_name,
        input int          inst_idx,
        input int          rd_idx,
        input logic [31:0] expected_data,
        input logic [31:0] expected_pc
    );
        @(posedge clk);
        #1; // Wait for writeback and PC update

        assert (u_riscv_core.u_datapath.u_regfile.registers[rd_idx] === expected_data &&
                u_riscv_core.pc === expected_pc)
        begin
            $display("[PASS] Inst[%02d] %-4s: reg[x%0d] = 0x%08h (%0d), Next PC = %0d",
                     inst_idx, inst_name, rd_idx,
                     u_riscv_core.u_datapath.u_regfile.registers[rd_idx],
                     $signed(u_riscv_core.u_datapath.u_regfile.registers[rd_idx]),
                     u_riscv_core.pc);
        end
        else begin
            $error("[FAIL] Inst[%02d] %-4s failed! Expected reg[x%0d]=0x%08h, PC=%0d. Got reg=0x%08h, PC=%0d",
                   inst_idx, inst_name, rd_idx, expected_data, expected_pc,
                   u_riscv_core.u_datapath.u_regfile.registers[rd_idx], u_riscv_core.pc);
        end
    endtask

    // ----------------------------------------------------
    // Main Stimulus Sequence
    // ----------------------------------------------------
    initial begin
        // Reset sequence
        resetN = 1'b0;
        repeat (2) @(posedge clk);
        #1;
        resetN = 1'b1;

        // Verification checks
        check_result("ADDI", 0, 1, 32'd15,         32'd4);
        check_result("ADDI", 1, 2, 32'hFFFF_FFDD,  32'd8);  // -35
        check_result("ADDI", 2, 3, 32'hFFFF_F800,  32'd12); // -2048
        check_result("ADDI", 3, 4, 32'h0000_07FF,  32'd16); // +2047
        check_result("ADDI", 4, 0, 32'd0,          32'd20); // x0 remains 0

        $display("\n========================================================");
        $display("   ALL ADDI INSTRUCTION TESTS PASSED!                   ");
        $display("========================================================\n");
        $stop;
    end

endmodule