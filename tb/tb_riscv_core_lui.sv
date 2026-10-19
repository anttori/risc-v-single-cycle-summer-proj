`timescale 1ns / 1ps

import riscv_pkg::*;

module tb_riscv_core_lui ();

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
    // Helper function for U-Type instruction encoding (LUI)
    // Format: {imm[31:12], rd[4:0], opcode[6:0]}
    // ----------------------------------------------------
    function automatic logic [31:0] encode_u (
        input logic [19:0] imm20,
        input logic [4:0]  rd,
        input logic [6:0]  opcode
    );
        return {imm20, rd, opcode};
    endfunction

    // ----------------------------------------------------
    // Helper function for I-Type instruction encoding (ADDI)
    // ----------------------------------------------------
    function automatic logic [31:0] encode_i (
        input logic [11:0] imm12,
        input logic [4:0]  rs1,
        input logic [2:0]  funct3,
        input logic [4:0]  rd,
        input logic [6:0]  opcode
    );
        return {imm12, rs1, funct3, rd, opcode};
    endfunction

    // ----------------------------------------------------
    // Program Assembly
    // ----------------------------------------------------
    initial begin
        // Initialize IMEM with NOPs (ADDI x0, x0, 0)
        for (int i = 0; i < 64; i++) begin
            imem[i] = 32'h00000013;
        end

        // [0] PC = 0: LUI x1, 0x12345 -> Expected x1 = 0x12345000
        imem[0] = encode_u(20'h12345, 5'd1, OPC_LUI);

        // [1] PC = 4: LUI x2, 0xDEADB -> Expected x2 = 0xDEADB000
        // Note: inst[19:15] here is 5'b11010 (x26). We preload x26 with garbage
        // to verify ALU_B_PASS completely ignores rs1_data (op_a).
        imem[1] = encode_u(20'hDEADB, 5'd2, OPC_LUI);

        // [2] PC = 8: LUI x0, 0xFFFFF -> Expected x0 = 0x00000000 (x0 hardwired to 0)
        imem[2] = encode_u(20'hFFFFF, 5'd0, OPC_LUI);

        // [3] PC = 12: ADDI x3, x1, 0x678 -> Construct full 32-bit constant 0x12345678
        imem[3] = encode_i(12'h678, 5'd1, 3'b000, 5'd3, OPC_OP_IMM);
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
    // Stimulus and Verification Sequence
    // ----------------------------------------------------
    initial begin
        // 1. Assert Reset
        resetN = 1'b0;
        repeat (2) @(posedge clk);

        // 2. Deassert Reset first
        #1;
        resetN = 1'b1;

        // 3. Preload Register File AFTER reset release
        for (int i = 0; i < 32; i++) begin
            u_riscv_core.u_datapath.u_regfile.registers[i] = 32'b0;
        end
        // Put non-zero garbage into x26 (inst[19:15] of 0xDEADB000) and destination regs
        u_riscv_core.u_datapath.u_regfile.registers[26] = 32'hCAFE_BABE;
        u_riscv_core.u_datapath.u_regfile.registers[1]  = 32'h0000_0FFF;

        $display("\n========================================================");
        $display("   STARTING RV32I LUI INSTRUCTION TESTS                 ");
        $display("========================================================\n");

        // ----------------------------------------------------
        // Step 1: LUI x1, 0x12345 at PC = 0
        // ----------------------------------------------------
        @(negedge clk);
        assert (u_riscv_core.pc === 32'd0 &&
                u_riscv_core.u_datapath.imm === 32'h1234_5000 &&
                u_riscv_core.u_datapath.wb_data === 32'h1234_5000)
        begin
            $display("[PASS] Step 1 (LUI Decode): imm = 0x%08h, wb_data = 0x%08h",
                     u_riscv_core.u_datapath.imm, u_riscv_core.u_datapath.wb_data);
        end
        else begin
            $error("[FAIL] Step 1 (LUI Decode): Expected 0x12345000, Got wb_data = 0x%08h",
                   u_riscv_core.u_datapath.wb_data);
        end

        @(posedge clk);
        #1;
        assert (u_riscv_core.pc === 32'd4 &&
                u_riscv_core.u_datapath.u_regfile.registers[1] === 32'h1234_5000)
        begin
            $display("[PASS] Step 1 (Writeback): x1 = 0x%08h (Lower 12 bits cleared)",
                     u_riscv_core.u_datapath.u_regfile.registers[1]);
        end
        else begin
            $error("[FAIL] Step 1 (Writeback): Expected x1 = 0x12345000, Got 0x%08h",
                   u_riscv_core.u_datapath.u_regfile.registers[1]);
        end

        // ----------------------------------------------------
        // Step 2: LUI x2, 0xDEADB at PC = 4 (Verify op_a ignored)
        // ----------------------------------------------------
        @(posedge clk);
        #1;
        assert (u_riscv_core.pc === 32'd8 &&
                u_riscv_core.u_datapath.u_regfile.registers[2] === 32'hDEAD_B000)
        begin
            $display("[PASS] Step 2 (ALU_B_PASS): x2 = 0x%08h (Garbage in rs1 ignored)",
                     u_riscv_core.u_datapath.u_regfile.registers[2]);
        end
        else begin
            $error("[FAIL] Step 2 (ALU_B_PASS): Expected x2 = 0xDEADB000, Got 0x%08h",
                   u_riscv_core.u_datapath.u_regfile.registers[2]);
        end

        // ----------------------------------------------------
        // Step 3: LUI x0, 0xFFFFF at PC = 8 (Verify x0 protection)
        // ----------------------------------------------------
        @(posedge clk);
        #1;
        assert (u_riscv_core.pc === 32'd12 &&
                u_riscv_core.u_datapath.u_regfile.registers[0] === 32'h0000_0000)
        begin
            $display("[PASS] Step 3 (x0 Protection): x0 = 0x%08h",
                     u_riscv_core.u_datapath.u_regfile.registers[0]);
        end
        else begin
            $error("[FAIL] Step 3 (x0 Protection): Expected x0 = 0, Got 0x%08h",
                   u_riscv_core.u_datapath.u_regfile.registers[0]);
        end

        // ----------------------------------------------------
        // Step 4: ADDI x3, x1, 0x678 at PC = 12 (Full 32-bit synthesis)
        // ----------------------------------------------------
        @(posedge clk);
        #1;
        assert (u_riscv_core.pc === 32'd16 &&
                u_riscv_core.u_datapath.u_regfile.registers[3] === 32'h1234_5678)
        begin
            $display("[PASS] Step 4 (LUI + ADDI Combo): x3 = 0x%08h",
                     u_riscv_core.u_datapath.u_regfile.registers[3]);
        end
        else begin
            $error("[FAIL] Step 4 (LUI + ADDI Combo): Expected x3 = 0x12345678, Got 0x%08h",
                   u_riscv_core.u_datapath.u_regfile.registers[3]);
        end

        $display("\n========================================================");
        $display("   ALL RV32I LUI INSTRUCTION TESTS PASSED!              ");
        $display("========================================================\n");
        $stop;
    end

endmodule