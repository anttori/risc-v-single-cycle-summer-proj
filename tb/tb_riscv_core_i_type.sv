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

    // 0: ADDI x4, x1, 10
    // 0xF000_0008 + 10 -> Expected x4: 0xF000_0012
    assign imem[0]  = {12'h00A, 5'd1, 3'b000, 5'd4, 7'b0010011};

    // 1: ADDI x5, x2, -50
    // 2 + (-50) = -48 -> Expected x5: 0xFFFF_FFD0
    assign imem[1]  = {12'hFCE, 5'd2, 3'b000, 5'd5, 7'b0010011};

    // 2: SLLI x10, x1, 2
    // Shift left by 2 -> Expected x10: 0xC000_0020
    assign imem[2]  = {7'b0000000, 5'd2, 5'd1, 3'b001, 5'd10, 7'b0010011};

    // 3: SRLI x11, x1, 2
    // Logical right shift (zeroes extended) -> Expected x11: 0x3C00_0002
    assign imem[3]  = {7'b0000000, 5'd2, 5'd1, 3'b101, 5'd11, 7'b0010011};

    // 4: SRAI x12, x1, 2
    // Arithmetic right shift (sign extended, inst[30]=1) -> Expected x12: 0xFC00_0002
    assign imem[4]  = {7'b0100000, 5'd2, 5'd1, 3'b101, 5'd12, 7'b0010011};

    // 5: SLTI x13, x1, 2
    // Signed: negative < +2 -> Expected x13: 0x0000_0001
    assign imem[5]  = {12'h002, 5'd1, 3'b010, 5'd13, 7'b0010011};

    // 6: SLTIU x14, x1, 2
    // Unsigned: large positive (~4.02e9) < 2 -> Expected x14: 0x0000_0000
    assign imem[6]  = {12'h002, 5'd1, 3'b011, 5'd14, 7'b0010011};

    // 7: SLTIU x15, x2, -1
    // Unsigned with sign-extended imm (-1 -> 0xFFFFFFFF): 2 < 0xFFFFFFFF -> Expected x15: 0x0000_0001
    assign imem[7]  = {12'hFFF, 5'd2, 3'b011, 5'd15, 7'b0010011};

    // 8: XORI x16, x7, -1
    // Bitwise NOT via XOR with sign-extended -1: ~0x00FF_F0F0 -> Expected x16: 0xFF00_0F0F
    assign imem[8]  = {12'hFFF, 5'd7, 3'b100, 5'd16, 7'b0010011};

    // 9: ORI x17, x7, 15
    // 0x00FF_F0F0 | 0x0000_000F -> Expected x17: 0x00FF_F0FF
    assign imem[9]  = {12'h00F, 5'd7, 3'b110, 5'd17, 7'b0010011};

    // 10: ANDI x18, x7, 240
    // 0x00FF_F0F0 & 0x0000_00F0 -> Expected x18: 0x0000_00F0
    assign imem[10] = {12'h0F0, 5'd7, 3'b111, 5'd18, 7'b0010011};

    // 11: ANDI x0, x7, 240
    // Attempt to write into hardwired zero -> Expected x0: 0x0000_0000
    assign imem[11] = {12'h0F0, 5'd7, 3'b111, 5'd0,  7'b0010011};

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
        #1; // Wait for register writeback and PC update

        assert (u_riscv_core.u_datapath.u_regfile.registers[rd_idx] === expected_data &&
                u_riscv_core.pc === expected_pc)
        begin
            $display("[PASS] Inst[%02d] %-5s: reg[x%0d] = 0x%08h, Next PC = %0d",
                     inst_idx, inst_name, rd_idx,
                     u_riscv_core.u_datapath.u_regfile.registers[rd_idx], u_riscv_core.pc);
        end
        else begin
            $error("[FAIL] Inst[%02d] %-5s failed! Expected: reg[x%0d]=0x%08h, PC=%0d. Got: reg=0x%08h, PC=%0d",
                   inst_idx, inst_name, rd_idx, expected_data, expected_pc,
                   u_riscv_core.u_datapath.u_regfile.registers[rd_idx], u_riscv_core.pc);
        end
    endtask

    // ----------------------------------------------------
    // Main Stimulus Sequence
    // ----------------------------------------------------
    initial begin
        // 1. Assert Reset
        resetN = 1'b0;
        repeat (2) @(posedge clk);

        // 2. Deassert Reset cleanly off-edge
        #1;
        resetN = 1'b1;

        // 3. Preload initial register test vectors
        u_riscv_core.u_datapath.u_regfile.registers[1] = 32'hF000_0008; // x1: Negative operand
        u_riscv_core.u_datapath.u_regfile.registers[2] = 32'd2;         // x2: Positive operand
        u_riscv_core.u_datapath.u_regfile.registers[7] = 32'h00FF_F0F0; // x7: Bitmask operand

        // 4. Sequential Checks
        check_result("ADDI",  0,  4,  32'hF000_0012, 32'd4);
        check_result("ADDI",  1,  5,  32'hFFFF_FFD0, 32'd8);
        check_result("SLLI",  2,  10, 32'hC000_0020, 32'd12);
        check_result("SRLI",  3,  11, 32'h3C00_0002, 32'd16);
        check_result("SRAI",  4,  12, 32'hFC00_0002, 32'd20);
        check_result("SLTI",  5,  13, 32'h0000_0001, 32'd24);
        check_result("SLTIU", 6,  14, 32'h0000_0000, 32'd28);
        check_result("SLTIU", 7,  15, 32'h0000_0001, 32'd32); // imm = -1 corner-case
        check_result("XORI",  8,  16, 32'hFF00_0F0F, 32'd36); // Full 32-bit sign-extended inversion
        check_result("ORI",   9,  17, 32'h00FF_F0FF, 32'd40);
        check_result("ANDI",  10, 18, 32'h0000_00F0, 32'd44);
        check_result("ANDI",  11, 0,  32'd0,         32'd48); // x0 zero-preservation check

        // 5. Completion Banner
        $display("\n========================================================");
        $display("   ALL RV32I OP-IMM INSTRUCTION TESTS PASSED!           ");
        $display("========================================================\n");
        $stop;
    end

endmodule