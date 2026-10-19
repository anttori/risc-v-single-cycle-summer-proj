`timescale 1ns / 1ps

import riscv_pkg::*;

module tb_riscv_core_b_type ();

    // ----------------------------------------------------
    // Interface signals
    // ----------------------------------------------------
    logic        clk;
    logic        resetN;
    logic [31:0] inst;
    logic [31:0] pc;

    logic [31:0] dmem_data;
    logic        dmem_wen;
    logic [31:0] dmem_addr;
    logic [31:0] dmem_wdata;
    logic [3:0]  dmem_data_en;

    // ----------------------------------------------------
    // Instruction Memory (IMEM)
    // ----------------------------------------------------
    logic [31:0] imem [0:63];
    assign inst = imem[pc[31:2]];

    // DMEM data input tied to zero (unused for branch verification)
    assign dmem_data = 32'b0;

    // ----------------------------------------------------
    // Helper function for B-type instruction encoding
    // Bit mapping: imm[12|10:5] | rs2 | rs1 | funct3 | imm[4:1|11] | opcode
    // ----------------------------------------------------
    function automatic logic [31:0] encode_b (
        input logic [12:0] imm,
        input logic [4:0]  rs2,
        input logic [4:0]  rs1,
        input logic [2:0]  funct3
    );
        return {imm[12], imm[10:5], rs2, rs1, funct3, imm[4:1], imm[11], 7'b1100011};
    endfunction

    // ----------------------------------------------------
    // Test program setup
    // Registers are initialized as follows:
    //   x1 = 10,  x2 = 10 (x1 == x2)
    //   x3 = 20           (x1 != x3, x1 < x3)
    //   x4 = -1 (0xFFFFFFFF)
    //   x5 =  1 (0x00000001)
    // ----------------------------------------------------
    initial begin
        // Initialize memory with NOPs (ADDI x0, x0, 0)
        for (int i = 0; i < 64; i++) begin
            imem[i] = 32'h00000013;
        end

        // [0] PC = 0: BEQ x1, x2, +8 (10 == 10 -> TAKEN -> PC = 8)
        imem[0] = encode_b(13'd8, 5'd2, 5'd1, 3'b000);

        // [1] PC = 4: TRAP (must not execute)
        imem[1] = 32'hDEADBEEF;

        // [2] PC = 8: BEQ x1, x3, +8 (10 == 20 -> NOT TAKEN -> PC = 12)
        imem[2] = encode_b(13'd8, 5'd3, 5'd1, 3'b000);

        // [3] PC = 12: BNE x1, x3, +8 (10 != 20 -> TAKEN -> PC = 20)
        imem[3] = encode_b(13'd8, 5'd3, 5'd1, 3'b001);

        // [4] PC = 16: TRAP
        imem[4] = 32'hDEADBEEF;

        // [5] PC = 20: BNE x1, x2, +8 (10 != 10 -> NOT TAKEN -> PC = 24)
        imem[5] = encode_b(13'd8, 5'd2, 5'd1, 3'b001);

        // [6] PC = 24: BLT x4, x5, +8 (-1 < 1 signed -> TAKEN -> PC = 32)
        imem[6] = encode_b(13'd8, 5'd5, 5'd4, 3'b100);

        // [7] PC = 28: TRAP
        imem[7] = 32'hDEADBEEF;

        // [8] PC = 32: BLT x5, x4, +8 (1 < -1 signed -> NOT TAKEN -> PC = 36)
        imem[8] = encode_b(13'd8, 5'd4, 5'd5, 3'b100);

        // [9] PC = 36: BGE x5, x4, +8 (1 >= -1 signed -> TAKEN -> PC = 44)
        imem[9] = encode_b(13'd8, 5'd4, 5'd5, 3'b101);

        // [10] PC = 40: TRAP
        imem[10] = 32'hDEADBEEF;

        // [11] PC = 44: BGE x1, x2, +8 (10 >= 10 signed -> TAKEN -> PC = 52)
        imem[11] = encode_b(13'd8, 5'd2, 5'd1, 3'b101);

        // [12] PC = 48: TRAP
        imem[12] = 32'hDEADBEEF;

        // [13] PC = 52: BLTU x5, x4, +8 (1 < 0xFFFFFFFF unsigned -> TAKEN -> PC = 60)
        imem[13] = encode_b(13'd8, 5'd4, 5'd5, 3'b110);

        // [14] PC = 56: TRAP
        imem[14] = 32'hDEADBEEF;

        // [15] PC = 60: BLTU x4, x5, +8 (0xFFFFFFFF < 1 unsigned -> NOT TAKEN -> PC = 64)
        imem[15] = encode_b(13'd8, 5'd5, 5'd4, 3'b110);

        // [16] PC = 64: BGEU x4, x5, +8 (0xFFFFFFFF >= 1 unsigned -> TAKEN -> PC = 72)
        imem[16] = encode_b(13'd8, 5'd5, 5'd4, 3'b111);

        // [17] PC = 68: TRAP
        imem[17] = 32'hDEADBEEF;

        // [18] PC = 72: BEQ x0, x0, +8 (TAKEN -> jump forward to PC = 80)
        imem[18] = encode_b(13'd8, 5'd0, 5'd0, 3'b000);

        // [19] PC = 76: Landing instruction after backward branch (NOP)
        imem[19] = 32'h00000013;

        // [20] PC = 80: BEQ x0, x0, -4 (BACKWARD BRANCH: 80 - 4 = 76 -> PC = 76)
        imem[20] = encode_b(-13'd4, 5'd0, 5'd0, 3'b000);

        // [21] PC = 84: TRAP
        imem[21] = 32'hDEADBEEF;
    end

    // ----------------------------------------------------
    // DUT instantiation
    // ----------------------------------------------------
    riscv_core u_riscv_core (
        .clk          (clk),
        .resetN       (resetN),
        .inst         (inst),
        .pc           (pc),
        .dmem_data    (dmem_data),
        .dmem_wen     (dmem_wen),
        .dmem_addr    (dmem_addr),
        .dmem_wdata   (dmem_wdata),
        .dmem_data_en (dmem_data_en)
    );

    // ----------------------------------------------------
    // Clock generator (50 MHz)
    // ----------------------------------------------------
    initial begin
        clk = 1'b0;
        forever #10 clk = ~clk;
    end

    // ----------------------------------------------------
    // Verification task for branch execution
    // ----------------------------------------------------
    task check_branch (
        input string       test_name,
        input logic [31:0] expected_current_pc,
        input logic        expected_pc_sel,
        input logic [31:0] expected_next_pc
    );
        // Sample combinational signals at mid-cycle
        @(negedge clk);
        assert (u_riscv_core.pc === expected_current_pc &&
                u_riscv_core.u_controller.PCSel === expected_pc_sel &&
                u_riscv_core.u_datapath.pc_next === expected_next_pc)
        begin
            $display("[PASS] %-25s | Current PC = %2d | PCSel = %b | Next PC = %2d",
                     test_name, u_riscv_core.pc, u_riscv_core.u_controller.PCSel, u_riscv_core.u_datapath.pc_next);
        end
        else begin
            $error("[FAIL] %-25s | Current PC: exp %0d, got %0d | PCSel: exp %b, got %b | Next PC: exp %0d, got %0d",
                   test_name, expected_current_pc, u_riscv_core.pc,
                   expected_pc_sel, u_riscv_core.u_controller.PCSel,
                   expected_next_pc, u_riscv_core.u_datapath.pc_next);
        end

        // Advance to next clock cycle
        @(posedge clk);
        #1;
    endtask

    // ----------------------------------------------------
    // Main stimulus sequence
    // ----------------------------------------------------
    initial begin
        // 1. Assert Reset
        resetN = 1'b0;
        repeat (2) @(posedge clk);

        // 2. Deassert Reset
        #1;
        resetN = 1'b1;

        // 3. Preload Register File AFTER reset has been released
        u_riscv_core.u_datapath.u_regfile.registers[1] = 32'd10;         // x1 = 10
        u_riscv_core.u_datapath.u_regfile.registers[2] = 32'd10;         // x2 = 10
        u_riscv_core.u_datapath.u_regfile.registers[3] = 32'd20;         // x3 = 20
        u_riscv_core.u_datapath.u_regfile.registers[4] = 32'hFFFF_FFFF;  // x4 = -1
        u_riscv_core.u_datapath.u_regfile.registers[5] = 32'd1;          // x5 = 1

        $display("\n========================================================");
        $display("   STARTING RV32I BRANCH INSTRUCTION TESTS              ");
        $display("========================================================\n");

        // [0] BEQ Taken: 10 == 10 -> PC jump 0 -> 8
        check_branch("BEQ (Taken)", 32'd0, 1'b1, 32'd8);

        // [1] BEQ Not Taken: 10 == 20 -> PC step 8 -> 12
        check_branch("BEQ (Not Taken)", 32'd8, 1'b0, 32'd12);

        // [2] BNE Taken: 10 != 20 -> PC jump 12 -> 20
        check_branch("BNE (Taken)", 32'd12, 1'b1, 32'd20);

        // [3] BNE Not Taken: 10 != 10 -> PC step 20 -> 24
        check_branch("BNE (Not Taken)", 32'd20, 1'b0, 32'd24);

        // [4] BLT Taken: -1 < 1 (Signed) -> PC jump 24 -> 32
        check_branch("BLT (Taken, -1 < 1)", 32'd24, 1'b1, 32'd32);

        // [5] BLT Not Taken: 1 < -1 (Signed) -> PC step 32 -> 36
        check_branch("BLT (Not Taken, 1 < -1)", 32'd32, 1'b0, 32'd36);

        // [6] BGE Taken: 1 >= -1 (Signed) -> PC jump 36 -> 44
        check_branch("BGE (Taken, 1 >= -1)", 32'd36, 1'b1, 32'd44);

        // [7] BGE Taken Equal: 10 >= 10 -> PC jump 44 -> 52
        check_branch("BGE (Taken, Equal)", 32'd44, 1'b1, 32'd52);

        // [8] BLTU Taken: 1 < 0xFFFFFFFF (Unsigned) -> PC jump 52 -> 60
        check_branch("BLTU (Taken, 1 < MAX)", 32'd52, 1'b1, 32'd60);

        // [9] BLTU Not Taken: 0xFFFFFFFF < 1 (Unsigned) -> PC step 60 -> 64
        check_branch("BLTU (Not Taken, MAX < 1)", 32'd60, 1'b0, 32'd64);

        // [10] BGEU Taken: 0xFFFFFFFF >= 1 (Unsigned) -> PC jump 64 -> 72
        check_branch("BGEU (Taken, MAX >= 1)", 32'd64, 1'b1, 32'd72);

        // [11] Setup for Backward Branch: jump over to PC 80
        check_branch("BEQ (Setup Forward)", 32'd72, 1'b1, 32'd80);

        // [12] Backward Branch: PC 80 - 4 = 76
        check_branch("BEQ (Backward Jump -4)", 32'd80, 1'b1, 32'd76);

        // [13] Landing check: verify arrival at PC = 76
        @(negedge clk);
        assert (u_riscv_core.pc === 32'd76)
            $display("[PASS] %-25s | Successfully landed at PC = %0d", "Backward Landing", u_riscv_core.pc);
        else
            $error("[FAIL] %-25s | Arrived at PC = %0d instead of 76", "Backward Landing", u_riscv_core.pc);

        $display("\n========================================================");
        $display("   ALL RV32I BRANCH INSTRUCTION TESTS PASSED!           ");
        $display("========================================================\n");
        $stop;
    end

endmodule