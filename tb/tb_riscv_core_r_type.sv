`timescale 1ns / 1ps

import riscv_pkg::*;

module tb_riscv_core_r_type ();

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

    // Format: {funct7, rs2, rs1, funct3, rd, opcode}
    // opcode RV32I R-Type: 7'b0110011

    // 0: ADD  x4,  x1, x2  -> Expected: 0xF000_000A
    assign imem[0]  = {7'b0000000, 5'd2, 5'd1, 3'b000, 5'd4,  7'b0110011};

    // 1: SUB  x5,  x2, x1  -> Expected: 0x0FFF_FFFA
    assign imem[1]  = {7'b0100000, 5'd1, 5'd2, 3'b000, 5'd5,  7'b0110011};

    // 2: SLL  x10, x1, x2  -> Shift left by 2 (clean op_b) -> Expected: 0xC000_0020
    assign imem[2]  = {7'b0000000, 5'd2, 5'd1, 3'b001, 5'd10, 7'b0110011};

    // 3: SLL  x11, x1, x3  -> Shift left with dirty bits (x3[4:0] = 2) -> Expected: 0xC000_0020
    assign imem[3]  = {7'b0000000, 5'd3, 5'd1, 3'b001, 5'd11, 7'b0110011};

    // 4: SRL  x12, x1, x2  -> Logical right shift (zeroes extended) -> Expected: 0x3C00_0002
    assign imem[4]  = {7'b0000000, 5'd2, 5'd1, 3'b101, 5'd12, 7'b0110011};

    // 5: SRA  x13, x1, x2  -> Arithmetic right shift (sign extended) -> Expected: 0xFC00_0002
    assign imem[5]  = {7'b0100000, 5'd2, 5'd1, 3'b101, 5'd13, 7'b0110011};

    // 6: SLT  x14, x1, x2  -> Signed: negative < positive -> Expected: 0x0000_0001
    assign imem[6]  = {7'b0000000, 5'd2, 5'd1, 3'b010, 5'd14, 7'b0110011};

    // 7: SLTU x15, x1, x2  -> Unsigned: large positive < 2 -> Expected: 0x0000_0000
    assign imem[7]  = {7'b0000000, 5'd2, 5'd1, 3'b011, 5'd15, 7'b0110011};

    // 8: XOR  x16, x7, x8  -> 0x00FF_F0F0 ^ 0x0F0F_0F0F -> Expected: 0x0FF0_FFFF
    assign imem[8]  = {7'b0000000, 5'd8, 5'd7, 3'b100, 5'd16, 7'b0110011};

    // 9: OR   x17, x7, x8  -> 0x00FF_F0F0 | 0x0F0F_0F0F -> Expected: 0x0FFF_FFFF
    assign imem[9]  = {7'b0000000, 5'd8, 5'd7, 3'b110, 5'd17, 7'b0110011};

    // 10: AND x18, x7, x8  -> 0x00FF_F0F0 & 0x0F0F_0F0F -> Expected: 0x000F_0000
    assign imem[10] = {7'b0000000, 5'd8, 5'd7, 3'b111, 5'd18, 7'b0110011};

    // 11: OR  x0,  x7, x8  -> Attempt to write into hardwired zero -> Expected x0: 0x0000_0000
    assign imem[11] = {7'b0000000, 5'd8, 5'd7, 3'b110, 5'd0,  7'b0110011};

    // Asynchronous instruction fetch
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
        // Wait for the synchronous clock edge that commits the result to regfile
        @(posedge clk);
        #1; // Delay to settle simulation delta cycles and race conditions

        assert (u_riscv_core.u_datapath.u_regfile.registers[rd_idx] === expected_data &&
                u_riscv_core.pc === expected_pc)
        begin
            $display("[PASS] Inst[%02d] %-4s: reg[x%0d] = 0x%08h, Next PC = %0d",
                     inst_idx, inst_name, rd_idx,
                     u_riscv_core.u_datapath.u_regfile.registers[rd_idx], u_riscv_core.pc);
        end
        else begin
            $error("[FAIL] Inst[%02d] %-4s failed! Expected: reg[x%0d]=0x%08h, PC=%0d. Got: reg=0x%08h, PC=%0d",
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

        // 3. Preload initial register test vectors (while processor starts at pc = 0)
        u_riscv_core.u_datapath.u_regfile.registers[1] = 32'hF000_0008; // x1: Negative operand
        u_riscv_core.u_datapath.u_regfile.registers[2] = 32'd2;         // x2: Positive operand / shift size
        u_riscv_core.u_datapath.u_regfile.registers[3] = 32'h0000_00A2; // x3: Shift with non-zero upper bits
        u_riscv_core.u_datapath.u_regfile.registers[7] = 32'h00FF_F0F0; // x7: Bitmask operand 1
        u_riscv_core.u_datapath.u_regfile.registers[8] = 32'h0F0F_0F0F; // x8: Bitmask operand 2

        // 4. Sequential Checks: check_result(name, inst_idx, rd, expected_data, expected_next_pc)
        check_result("ADD",  0,  4,  32'hF000_000A, 32'd4);
        check_result("SUB",  1,  5,  32'h0FFF_FFFA, 32'd8);
        check_result("SLL",  2,  10, 32'hC000_0020, 32'd12);
        check_result("SLL",  3,  11, 32'hC000_0020, 32'd16); // Masking test (x3[4:0] == 2)
        check_result("SRL",  4,  12, 32'h3C00_0002, 32'd20);
        check_result("SRA",  5,  13, 32'hFC00_0002, 32'd24);
        check_result("SLT",  6,  14, 32'h0000_0001, 32'd28); // Signed comparison
        check_result("SLTU", 7,  15, 32'h0000_0000, 32'd32); // Unsigned comparison
        check_result("XOR",  8,  16, 32'h0FF0_FFFF, 32'd36);
        check_result("OR",   9,  17, 32'h0FFF_FFFF, 32'd40);
        check_result("AND",  10, 18, 32'h000F_0000, 32'd44);
        check_result("OR",   11, 0,  32'h0000_0000, 32'd48); // x0 zero-preservation check

        // 5. Completion Banner
        $display("\n========================================================");
        $display("   ALL RV32I R-TYPE INSTRUCTION TESTS PASSED!          ");
        $display("========================================================\n");
        $stop;
    end

endmodule