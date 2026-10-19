`timescale 1ns / 1ps

import riscv_pkg::*;

module tb_riscv_core_auipc ();

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
    // Helper function for U-Type instruction encoding
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

        // [0] PC = 0: AUIPC x1, 0x12345
        // Expected: x1 = 0 + 0x12345000 = 0x12345000
        imem[0] = encode_u(20'h12345, 5'd1, OPC_AUIPC);

        // [1] PC = 4: AUIPC x2, 0x00001
        // Expected: x2 = 4 + 0x00001000 = 0x00001004 (verifies PC addition)
        imem[1] = encode_u(20'h00001, 5'd2, OPC_AUIPC);

        // [2] PC = 8: AUIPC x0, 0x55555
        // Expected: x0 = 0x00000000 (x0 hardwired to zero)
        imem[2] = encode_u(20'h55555, 5'd0, OPC_AUIPC);

        // [3] PC = 12: AUIPC x3, 0x00002
        // Expected: x3 = 12 + 0x00002000 = 0x0000200C
        imem[3] = encode_u(20'h00002, 5'd3, OPC_AUIPC);

        // [4] PC = 16: ADDI x4, x3, 0x014
        // Expected: x4 = 0x0000200C + 0x14 = 0x00002020 (PC-relative offset calculation)
        imem[4] = encode_i(12'h014, 5'd3, 3'b000, 5'd4, OPC_OP_IMM);

        // [5] PC = 20: NOP (end of execution)
        imem[5] = 32'h00000013;
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

        // 3. Clear register file AFTER reset release
        for (int i = 0; i < 32; i++) begin
            u_riscv_core.u_datapath.u_regfile.registers[i] = 32'b0;
        end

        $display("\n========================================================");
        $display("   STARTING RV32I AUIPC INSTRUCTION TESTS               ");
        $display("========================================================\n");

        // ----------------------------------------------------
        // Step 1: AUIPC x1, 0x12345 at PC = 0
        // ----------------------------------------------------
        @(negedge clk);
        assert (u_riscv_core.pc === 32'd0 &&
                u_riscv_core.u_controller.PCSel === 1'b0 &&
                u_riscv_core.u_datapath.imm === 32'h1234_5000 &&
                u_riscv_core.u_datapath.wb_data === 32'h1234_5000)
        begin
            $display("[PASS] Step 1 (AUIPC at PC=0): imm = 0x%08h, wb_data = 0x%08h",
                     u_riscv_core.u_datapath.imm, u_riscv_core.u_datapath.wb_data);
        end
        else begin
            $error("[FAIL] Step 1 (AUIPC at PC=0): Expected wb_data = 0x12345000, Got 0x%08h",
                   u_riscv_core.u_datapath.wb_data);
        end

        @(posedge clk);
        #1;
        assert (u_riscv_core.pc === 32'd4 &&
                u_riscv_core.u_datapath.u_regfile.registers[1] === 32'h1234_5000)
        begin
            $display("[PASS] Step 1 (Writeback): x1 = 0x%08h",
                     u_riscv_core.u_datapath.u_regfile.registers[1]);
        end
        else begin
            $error("[FAIL] Step 1 (Writeback): Expected x1 = 0x12345000, Got 0x%08h",
                   u_riscv_core.u_datapath.u_regfile.registers[1]);
        end

        // ----------------------------------------------------
        // Step 2: AUIPC x2, 0x00001 at PC = 4 (Tests PC != 0)
        // ----------------------------------------------------
        @(negedge clk);
        assert (u_riscv_core.pc === 32'd4 &&
                u_riscv_core.u_controller.PCSel === 1'b0 &&
                u_riscv_core.u_datapath.wb_data === 32'h0000_1004)
        begin
            $display("[PASS] Step 2 (AUIPC at PC=4): wb_data = 0x%08h (PC + imm added correctly)",
                     u_riscv_core.u_datapath.wb_data);
        end
        else begin
            $error("[FAIL] Step 2 (AUIPC at PC=4): Expected wb_data = 0x00001004, Got 0x%08h",
                   u_riscv_core.u_datapath.wb_data);
        end

        @(posedge clk);
        #1;
        assert (u_riscv_core.pc === 32'd8 &&
                u_riscv_core.u_datapath.u_regfile.registers[2] === 32'h0000_1004)
        begin
            $display("[PASS] Step 2 (Writeback): x2 = 0x%08h",
                     u_riscv_core.u_datapath.u_regfile.registers[2]);
        end
        else begin
            $error("[FAIL] Step 2 (Writeback): Expected x2 = 0x00001004, Got 0x%08h",
                   u_riscv_core.u_datapath.u_regfile.registers[2]);
        end

        // ----------------------------------------------------
        // Step 3: AUIPC x0, 0x55555 at PC = 8 (Verify x0 protection)
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
        // Step 4: AUIPC x3, 0x00002 at PC = 12
        // ----------------------------------------------------
        @(posedge clk);
        #1;
        assert (u_riscv_core.pc === 32'd16 &&
                u_riscv_core.u_datapath.u_regfile.registers[3] === 32'h0000_200C)
        begin
            $display("[PASS] Step 4 (AUIPC at PC=12): x3 = 0x%08h",
                     u_riscv_core.u_datapath.u_regfile.registers[3]);
        end
        else begin
            $error("[FAIL] Step 4 (AUIPC at PC=12): Expected x3 = 0x0000200C, Got 0x%08h",
                   u_riscv_core.u_datapath.u_regfile.registers[3]);
        end

        // ----------------------------------------------------
        // Step 5: ADDI x4, x3, 0x014 at PC = 16
        // ----------------------------------------------------
        @(posedge clk);
        #1;
        assert (u_riscv_core.pc === 32'd20 &&
                u_riscv_core.u_datapath.u_regfile.registers[4] === 32'h0000_2020)
        begin
            $display("[PASS] Step 5 (AUIPC + ADDI Combo): x4 = 0x%08h (0x200C + 0x14 = 0x2020)",
                     u_riscv_core.u_datapath.u_regfile.registers[4]);
        end
        else begin
            $error("[FAIL] Step 5 (AUIPC + ADDI Combo): Expected x4 = 0x00002020, Got 0x%08h",
                   u_riscv_core.u_datapath.u_regfile.registers[4]);
        end

        $display("\n========================================================");
        $display("   ALL RV32I AUIPC INSTRUCTION TESTS PASSED!            ");
        $display("========================================================\n");
        $stop;
    end

endmodule