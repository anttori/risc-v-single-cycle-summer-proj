`timescale 1ns / 1ps

import riscv_pkg::*;

module tb_riscv_core_jalr ();

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

    // DMEM data input tied to zero (unused for JALR verification)
    assign dmem_data = 32'b0;

    // ----------------------------------------------------
    // Helper function for I-Type instruction encoding
    // Format: {imm[11:0], rs1[4:0], funct3[2:0], rd[4:0], opcode[6:0]}
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
    // Program Assembly
    // Register setup:
    //   x1  = 0   (Return address register: ra)
    //   x2  = 40  (Base pointer 1)
    //   x3  = 100 (Base pointer 2)
    //   x5  = 0   (Destination register)
    //   x6  = 0   (Verification register)
    // ----------------------------------------------------
    initial begin
        // Initialize memory with NOPs (ADDI x0, x0, 0)
        for (int i = 0; i < 64; i++) begin
            imem[i] = 32'h00000013;
        end

        // [0] PC = 0: JALR x1, 8(x2)
        // Target = 40 + 8 = 48. Link = PC + 4 = 4 -> stored in x1 (ra)
        imem[0] = encode_i(12'd8, 5'd2, 3'b000, 5'd1, 7'b1100111);

        // [1] PC = 4: Target after function return (Landing site)
        // ADDI x6, x0, 42 -> Confirm normal execution resumes
        imem[1] = encode_i(12'd42, 5'd0, 3'b000, 5'd6, 7'b0010011);

        // [2] PC = 8: NOP (program finished)
        imem[2] = 32'h00000013;

        // [12] PC = 48: JALR x5, -16(x3) (Negative immediate test)
        // Target = 100 - 16 = 84. Link = 48 + 4 = 52 -> stored in x5
        imem[12] = encode_i(-12'd16, 5'd3, 3'b000, 5'd5, 7'b1100111);

        // [21] PC = 84: JALR x0, 0(x1) (Function return: ret / jr ra)
        // Target = x1 + 0 = 4. rd = x0 -> verify x0 is NOT overwritten
        imem[21] = encode_i(12'd0, 5'd1, 3'b000, 5'd0, 7'b1100111);
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
    // Main stimulus sequence
    // ----------------------------------------------------
    initial begin
        // 1. Assert Reset
        resetN = 1'b0;
        repeat (2) @(posedge clk);

        // 2. Deassert Reset first
        #1;
        resetN = 1'b1;

        // 3. Preload Register File strictly AFTER reset release
        u_riscv_core.u_datapath.u_regfile.registers[1] = 32'd0;
        u_riscv_core.u_datapath.u_regfile.registers[2] = 32'd40;
        u_riscv_core.u_datapath.u_regfile.registers[3] = 32'd100;
        u_riscv_core.u_datapath.u_regfile.registers[5] = 32'd0;
        u_riscv_core.u_datapath.u_regfile.registers[6] = 32'd0;

        $display("\n========================================================");
        $display("   STARTING RV32I JALR INSTRUCTION TESTS                ");
        $display("========================================================\n");

        // ----------------------------------------------------
        // Step 1: Execute JALR x1, 8(x2) at PC = 0
        // Target: 40 + 8 = 48, Link: 0 + 4 = 4
        // ----------------------------------------------------
        @(negedge clk);
        assert (u_riscv_core.pc === 32'd0 &&
                u_riscv_core.u_controller.PCSel === 1'b1 &&
                u_riscv_core.u_datapath.pc_next === 32'd48 &&
                u_riscv_core.u_datapath.wb_data === 32'd4)
        begin
            $display("[PASS] Step 1 (JALR Call): Target PC = %0d, Return Addr = %0d",
                     u_riscv_core.u_datapath.pc_next, u_riscv_core.u_datapath.wb_data);
        end
        else begin
            $error("[FAIL] Step 1 (JALR Call): Expected Target=48, Link=4. Got Target=%0d, Link=%0d",
                   u_riscv_core.u_datapath.pc_next, u_riscv_core.u_datapath.wb_data);
        end

        // Clock edge: PC latches 48, x1 latches 4
        @(posedge clk);
        #1;
        assert (u_riscv_core.pc === 32'd48 &&
                u_riscv_core.u_datapath.u_regfile.registers[1] === 32'd4)
        begin
            $display("[PASS] Step 1 (Landed): PC = %0d, x1 (ra) = %0d",
                     u_riscv_core.pc, u_riscv_core.u_datapath.u_regfile.registers[1]);
        end
        else begin
            $error("[FAIL] Step 1 (Landed): Expected PC=48, x1=4. Got PC=%0d, x1=%0d",
                   u_riscv_core.pc, u_riscv_core.u_datapath.u_regfile.registers[1]);
        end

        // ----------------------------------------------------
        // Step 2: Execute JALR x5, -16(x3) at PC = 48
        // Target: 100 - 16 = 84, Link: 48 + 4 = 52
        // ----------------------------------------------------
        @(negedge clk);
        assert (u_riscv_core.pc === 32'd48 &&
                u_riscv_core.u_controller.PCSel === 1'b1 &&
                u_riscv_core.u_datapath.pc_next === 32'd84 &&
                u_riscv_core.u_datapath.wb_data === 32'd52)
        begin
            $display("[PASS] Step 2 (Negative Offset): Target PC = %0d, Return Addr = %0d",
                     u_riscv_core.u_datapath.pc_next, u_riscv_core.u_datapath.wb_data);
        end
        else begin
            $error("[FAIL] Step 2 (Negative Offset): Expected Target=84, Link=52. Got Target=%0d, Link=%0d",
                   u_riscv_core.u_datapath.pc_next, u_riscv_core.u_datapath.wb_data);
        end

        // Clock edge: PC latches 84, x5 latches 52
        @(posedge clk);
        #1;
        assert (u_riscv_core.pc === 32'd84 &&
                u_riscv_core.u_datapath.u_regfile.registers[5] === 32'd52)
        begin
            $display("[PASS] Step 2 (Landed): PC = %0d, x5 = %0d",
                     u_riscv_core.pc, u_riscv_core.u_datapath.u_regfile.registers[5]);
        end
        else begin
            $error("[FAIL] Step 2 (Landed): Expected PC=84, x5=52. Got PC=%0d, x5=%0d",
                   u_riscv_core.pc, u_riscv_core.u_datapath.u_regfile.registers[5]);
        end

        // ----------------------------------------------------
        // Step 3: Execute JALR x0, 0(x1) at PC = 84 (Return jump)
        // Target: x1 + 0 = 4, rd = x0 (x0 must remain 0)
        // ----------------------------------------------------
        @(negedge clk);
        assert (u_riscv_core.pc === 32'd84 &&
                u_riscv_core.u_controller.PCSel === 1'b1 &&
                u_riscv_core.u_datapath.pc_next === 32'd4)
        begin
            $display("[PASS] Step 3 (Return Jump): Target PC = %0d", u_riscv_core.u_datapath.pc_next);
        end
        else begin
            $error("[FAIL] Step 3 (Return Jump): Expected Target=4. Got Target=%0d",
                   u_riscv_core.u_datapath.pc_next);
        end

        // Clock edge: PC latches 4, x0 remains 0
        @(posedge clk);
        #1;
        assert (u_riscv_core.pc === 32'd4 &&
                u_riscv_core.u_datapath.u_regfile.registers[0] === 32'd0)
        begin
            $display("[PASS] Step 3 (Return Landing): PC = %0d, x0 = %0d (Zero register preserved)",
                     u_riscv_core.pc, u_riscv_core.u_datapath.u_regfile.registers[0]);
        end
        else begin
            $error("[FAIL] Step 3 (Return Landing): Expected PC=4, x0=0. Got PC=%0d, x0=%0d",
                   u_riscv_core.pc, u_riscv_core.u_datapath.u_regfile.registers[0]);
        end

        // ----------------------------------------------------
        // Step 4: Resume sequential execution (ADDI x6, x0, 42)
        // ----------------------------------------------------
        @(posedge clk);
        #1;
        assert (u_riscv_core.pc === 32'd8 &&
                u_riscv_core.u_datapath.u_regfile.registers[6] === 32'd42)
        begin
            $display("[PASS] Step 4 (Resume Execution): PC = %0d, x6 = %0d (Pipeline resumed correctly)",
                     u_riscv_core.pc, u_riscv_core.u_datapath.u_regfile.registers[6]);
        end
        else begin
            $error("[FAIL] Step 4 (Resume Execution): Expected PC=8, x6=42. Got PC=%0d, x6=%0d",
                   u_riscv_core.pc, u_riscv_core.u_datapath.u_regfile.registers[6]);
        end

        $display("\n========================================================");
        $display("   ALL RV32I JALR INSTRUCTION TESTS PASSED!             ");
        $display("========================================================\n");
        $stop;
    end

endmodule