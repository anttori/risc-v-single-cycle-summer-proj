`timescale 1ns / 1ps

import riscv_pkg::*;

module tb_riscv_core_j_type ();

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

    // Unused DMEM data input tied to zero
    assign dmem_data = 32'b0;

    // ----------------------------------------------------
    // Helper function for J-Type instruction encoding
    // Format: {imm[20], imm[10:1], imm[11], imm[19:12], rd[4:0], opcode[6:0]}
    // ----------------------------------------------------
    function automatic logic [31:0] encode_j (
        input logic [20:0] imm,
        input logic [4:0]  rd
    );
        return {imm[20], imm[10:1], imm[11], imm[19:12], rd, 7'b1101111};
    endfunction

    // ----------------------------------------------------
    // Helper function for I-Type instruction encoding (ADDI)
    // ----------------------------------------------------
    function automatic logic [31:0] encode_i (
        input logic [11:0] imm,
        input logic [4:0]  rs1,
        input logic [2:0]  funct3,
        input logic [4:0]  rd,
        input logic [6:0]  opcode
    );
        return {imm, rs1, funct3, rd, opcode};
    endfunction

    // ----------------------------------------------------
    // Program assembly
    // ----------------------------------------------------
    initial begin
        // Initialize entire IMEM with NOPs (ADDI x0, x0, 0)
        for (int i = 0; i < 64; i++) begin
            imem[i] = 32'h00000013;
        end

        // [0] PC = 0: JAL x1, +32
        // Target: 0 + 32 = 32. Link: 0 + 4 = 4 -> stored in x1 (ra)
        imem[0] = encode_j(21'd32, 5'd1);

        // [1] PC = 4: TRAP (Should not be reached immediately)
        imem[1] = 32'hDEADBEEF;

        // [5] PC = 20: Resumed linear execution point
        // ADDI x3, x0, 99
        imem[5] = encode_i(12'd99, 5'd0, 3'b000, 5'd3, 7'b0010011);

        // [6] PC = 24: Final NOP
        imem[6] = 32'h00000013;

        // [8] PC = 32: JAL x0, +16 (Unconditional jump pseudo-op: j offset)
        // Target: 32 + 16 = 48. Link discarded into x0 (must remain 0)
        imem[8] = encode_j(21'd16, 5'd0);

        // [9] PC = 36: TRAP
        imem[9] = 32'hDEADBEEF;

        // [12] PC = 48: JAL x2, -28 (Backward jump with non-zero imm[14:12])
        // Target: 48 - 28 = 20. Link: 48 + 4 = 52 -> stored in x2
        // Note: -28 has inst[14:12] = 3'b111, verifying alu_ctrl does not execute AND
        imem[12] = encode_j(-21'd28, 5'd2);

        // [13] PC = 52: TRAP
        imem[13] = 32'hDEADBEEF;
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
    // Clock generation (50 MHz)
    // ----------------------------------------------------
    initial begin
        clk = 1'b0;
        forever #10 clk = ~clk;
    end

    // ----------------------------------------------------
    // Stimulus and Verification Sequence
    // ----------------------------------------------------
    initial begin
        // 1. Reset cycle
        resetN = 1'b0;
        repeat (2) @(posedge clk);

        // 2. Deassert reset
        #1;
        resetN = 1'b1;

        // 3. Clear register file
        for (int i = 0; i < 32; i++) begin
            u_riscv_core.u_datapath.u_regfile.registers[i] = 32'b0;
        end

        $display("\n========================================================");
        $display("   STARTING RV32I JAL INSTRUCTION TESTS                 ");
        $display("========================================================\n");

        // ----------------------------------------------------
        // Step 1: Execute JAL x1, +32 at PC = 0
        // ----------------------------------------------------
        @(negedge clk);
        assert (u_riscv_core.pc === 32'd0 &&
                u_riscv_core.u_controller.PCSel === 1'b1 &&
                u_riscv_core.u_datapath.pc_next === 32'd32 &&
                u_riscv_core.u_datapath.wb_data === 32'd4)
        begin
            $display("[PASS] Step 1 (Forward JAL): Target PC = %0d, Return Addr = %0d",
                     u_riscv_core.u_datapath.pc_next, u_riscv_core.u_datapath.wb_data);
        end
        else begin
            $error("[FAIL] Step 1 (Forward JAL): Expected Target=32, Link=4. Got Target=%0d, Link=%0d",
                   u_riscv_core.u_datapath.pc_next, u_riscv_core.u_datapath.wb_data);
        end

        // Clock edge: PC latches 32, x1 latches 4
        @(posedge clk);
        #1;
        assert (u_riscv_core.pc === 32'd32 &&
                u_riscv_core.u_datapath.u_regfile.registers[1] === 32'd4)
        begin
            $display("[PASS] Step 1 (Landed): PC = %0d, x1 (ra) = %0d",
                     u_riscv_core.pc, u_riscv_core.u_datapath.u_regfile.registers[1]);
        end
        else begin
            $error("[FAIL] Step 1 (Landed): Expected PC=32, x1=4. Got PC=%0d, x1=%0d",
                   u_riscv_core.pc, u_riscv_core.u_datapath.u_regfile.registers[1]);
        end

        // ----------------------------------------------------
        // Step 2: Execute JAL x0, +16 at PC = 32 (Pseudo-op: j)
        // ----------------------------------------------------
        @(negedge clk);
        assert (u_riscv_core.pc === 32'd32 &&
                u_riscv_core.u_controller.PCSel === 1'b1 &&
                u_riscv_core.u_datapath.pc_next === 32'd48)
        begin
            $display("[PASS] Step 2 (JAL to x0): Target PC = %0d", u_riscv_core.u_datapath.pc_next);
        end
        else begin
            $error("[FAIL] Step 2 (JAL to x0): Expected Target=48. Got Target=%0d",
                   u_riscv_core.u_datapath.pc_next);
        end

        // Clock edge: PC latches 48, x0 must stay 0
        @(posedge clk);
        #1;
        assert (u_riscv_core.pc === 32'd48 &&
                u_riscv_core.u_datapath.u_regfile.registers[0] === 32'd0)
        begin
            $display("[PASS] Step 2 (Landed): PC = %0d, x0 = %0d (Zero register preserved)",
                     u_riscv_core.pc, u_riscv_core.u_datapath.u_regfile.registers[0]);
        end
        else begin
            $error("[FAIL] Step 2 (Landed): Expected PC=48, x0=0. Got PC=%0d, x0=%0d",
                   u_riscv_core.pc, u_riscv_core.u_datapath.u_regfile.registers[0]);
        end

        // ----------------------------------------------------
        // Step 3: Execute JAL x2, -28 at PC = 48 (Backward Jump)
        // ----------------------------------------------------
        @(negedge clk);
        assert (u_riscv_core.pc === 32'd48 &&
                u_riscv_core.u_controller.PCSel === 1'b1 &&
                u_riscv_core.u_datapath.pc_next === 32'd20 &&
                u_riscv_core.u_datapath.wb_data === 32'd52)
        begin
            $display("[PASS] Step 3 (Backward JAL): Target PC = %0d, Return Addr = %0d",
                     u_riscv_core.u_datapath.pc_next, u_riscv_core.u_datapath.wb_data);
        end
        else begin
            $error("[FAIL] Step 3 (Backward JAL): Expected Target=20, Link=52. Got Target=%0d, Link=%0d",
                   u_riscv_core.u_datapath.pc_next, u_riscv_core.u_datapath.wb_data);
        end

        // Clock edge: PC latches 20, x2 latches 52
        @(posedge clk);
        #1;
        assert (u_riscv_core.pc === 32'd20 &&
                u_riscv_core.u_datapath.u_regfile.registers[2] === 32'd52)
        begin
            $display("[PASS] Step 3 (Landed): PC = %0d, x2 = %0d",
                     u_riscv_core.pc, u_riscv_core.u_datapath.u_regfile.registers[2]);
        end
        else begin
            $error("[FAIL] Step 3 (Landed): Expected PC=20, x2=52. Got PC=%0d, x2=%0d",
                   u_riscv_core.pc, u_riscv_core.u_datapath.u_regfile.registers[2]);
        end

        // ----------------------------------------------------
        // Step 4: Resume execution with ADDI x3, x0, 99 at PC = 20
        // ----------------------------------------------------
        @(posedge clk);
        #1;
        assert (u_riscv_core.pc === 32'd24 &&
                u_riscv_core.u_datapath.u_regfile.registers[3] === 32'd99)
        begin
            $display("[PASS] Step 4 (Resume Execution): PC = %0d, x3 = %0d",
                     u_riscv_core.pc, u_riscv_core.u_datapath.u_regfile.registers[3]);
        end
        else begin
            $error("[FAIL] Step 4 (Resume Execution): Expected PC=24, x3=99. Got PC=%0d, x3=%0d",
                   u_riscv_core.pc, u_riscv_core.u_datapath.u_regfile.registers[3]);
        end

        $display("\n========================================================");
        $display("   ALL RV32I JAL INSTRUCTION TESTS PASSED!              ");
        $display("========================================================\n");
        $stop;
    end

endmodule