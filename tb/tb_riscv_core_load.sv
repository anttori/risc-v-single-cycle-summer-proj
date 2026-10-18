`timescale 1ns / 1ps

import riscv_pkg::*;

module tb_riscv_core_load ();

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

    // ----------------------------------------------------
    // Emulated Memories (IMEM & DMEM)
    // ----------------------------------------------------
    logic [31:0] imem [0:15];
    logic [7:0]  dmem [0:1023];

    // Asynchronous Read for IMEM
    assign inst = imem[pc[31:2]];

    // Asynchronous Read for DMEM (Little-Endian word-aligned assembly)
    wire [9:0] word_base = {dmem_addr[9:2], 2'b00};
    assign dmem_data = {
        dmem[word_base + 10'd3],
        dmem[word_base + 10'd2],
        dmem[word_base + 10'd1],
        dmem[word_base + 10'd0]
    };

    // Synchronous Write for DMEM (using standard always to permit initial preloading)
    always @(posedge clk) begin
        if (dmem_wen) begin
            dmem[dmem_addr[9:0]] <= dmem_wdata[7:0];
        end
    end

    // ----------------------------------------------------
    // Instruction Encoding (RV32I I-Type Load Format)
    // Format: {imm[11:0], rs1[4:0], funct3[2:0], rd[4:0], opcode[6:0]}
    // opcode: 7'b0000011 (OPC_LOAD)
    // ----------------------------------------------------

    // Base address in x1 = 40 (0x28). Target word at dmem[40..43]:
    // dmem[40] = 0x5A (Byte 0, MSB=0, +90)
    // dmem[41] = 0xE7 (Byte 1, MSB=1, -25)
    // dmem[42] = 0x9C (Byte 2, MSB=1, -100)
    // dmem[43] = 0x3B (Byte 3, MSB=0, +59)

    // 0: LB x5, 0(x1)  -> Byte 0 (pos) -> Expected: 0x0000_005A
    assign imem[0]  = {12'd0, 5'd1, 3'b000, 5'd5, 7'b0000011};

    // 1: LB x6, 1(x1)  -> Byte 1 (neg) -> Expected: 0xFFFF_FFE7
    assign imem[1]  = {12'd1, 5'd1, 3'b000, 5'd6, 7'b0000011};

    // 2: LB x7, 2(x1)  -> Byte 2 (neg) -> Expected: 0xFFFF_FF9C
    assign imem[2]  = {12'd2, 5'd1, 3'b000, 5'd7, 7'b0000011};

    // 3: LB x8, 3(x1)  -> Byte 3 (pos) -> Expected: 0x0000_003B
    assign imem[3]  = {12'd3, 5'd1, 3'b000, 5'd8, 7'b0000011};

    // 4: LBU x9, 1(x1) -> Byte 1 unsigned -> Expected: 0x0000_00E7
    assign imem[4]  = {12'd1, 5'd1, 3'b100, 5'd9, 7'b0000011};

    // 5: LBU x10, 2(x1)-> Byte 2 unsigned -> Expected: 0x0000_009C
    assign imem[5]  = {12'd2, 5'd1, 3'b100, 5'd10, 7'b0000011};

    // 6: LH x11, 0(x1) -> Halfword 0 (0xE75A, MSB=1) -> Expected: 0xFFFF_E75A
    assign imem[6]  = {12'd0, 5'd1, 3'b001, 5'd11, 7'b0000011};

    // 7: LH x12, 2(x1) -> Halfword 1 (0x3B9C, MSB=0) -> Expected: 0x0000_3B9C
    assign imem[7]  = {12'd2, 5'd1, 3'b001, 5'd12, 7'b0000011};

    // 8: LHU x13, 0(x1)-> Halfword 0 unsigned       -> Expected: 0x0000_E75A
    assign imem[8]  = {12'd0, 5'd1, 3'b101, 5'd13, 7'b0000011};

    // 9: LHU x14, 2(x1)-> Halfword 1 unsigned       -> Expected: 0x0000_3B9C
    assign imem[9]  = {12'd2, 5'd1, 3'b101, 5'd14, 7'b0000011};

    // 10: LW x15, 0(x1)-> Full 32-bit word          -> Expected: 0x3B9C_E75A
    assign imem[10] = {12'd0, 5'd1, 3'b010, 5'd15, 7'b0000011};

    // 11: LW x16, -4(x2) -> Negative offset: x2(44) - 4 = 40 -> Expected: 0x3B9C_E75A
    assign imem[11] = {12'hFFC, 5'd2, 3'b010, 5'd16, 7'b0000011};

    // 12: LW x0, 0(x1) -> Write into x0             -> Expected: 0x0000_0000
    assign imem[12] = {12'd0, 5'd1, 3'b010, 5'd0,  7'b0000011};

    // ----------------------------------------------------
    // DUT Instantiation
    // ----------------------------------------------------
    riscv_core u_riscv_core (
        .clk        (clk),
        .resetN     (resetN),
        .inst       (inst),
        .pc         (pc),
        .dmem_data  (dmem_data),
        .dmem_wen   (dmem_wen),
        .dmem_addr  (dmem_addr),
        .dmem_wdata (dmem_wdata)
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
            $display("[PASS] Inst[%02d] %-4s: reg[x%0d] = 0x%08h, Next PC = %0d",
                     inst_idx, inst_name, rd_idx,
                     u_riscv_core.u_datapath.u_regfile.registers[rd_idx], u_riscv_core.pc);
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
        // 1. Assert Reset
        resetN = 1'b0;
        repeat (2) @(posedge clk);

        // 2. Deassert Reset cleanly off-edge
        #1;
        resetN = 1'b1;

        // 3. Preload DMEM test vectors at base address 40
        dmem[40] = 8'h5A; // Byte 0 (pos)
        dmem[41] = 8'hE7; // Byte 1 (neg)
        dmem[42] = 8'h9C; // Byte 2 (neg)
        dmem[43] = 8'h3B; // Byte 3 (pos)

        // 4. Preload Register File pointers
        u_riscv_core.u_datapath.u_regfile.registers[1] = 32'd40; // Base pointer
        u_riscv_core.u_datapath.u_regfile.registers[2] = 32'd44; // Pointer for negative offset check

        // 5. Verification checks
        check_result("LB",   0,  5,  32'h0000_005A, 32'd4);
        check_result("LB",   1,  6,  32'hFFFF_FFE7, 32'd8);
        check_result("LB",   2,  7,  32'hFFFF_FF9C, 32'd12);
        check_result("LB",   3,  8,  32'h0000_003B, 32'd16);
        check_result("LBU",  4,  9,  32'h0000_00E7, 32'd20);
        check_result("LBU",  5,  10, 32'h0000_009C, 32'd24);
        check_result("LH",   6,  11, 32'hFFFF_E75A, 32'd28);
        check_result("LH",   7,  12, 32'h0000_3B9C, 32'd32);
        check_result("LHU",  8,  13, 32'h0000_E75A, 32'd36);
        check_result("LHU",  9,  14, 32'h0000_3B9C, 32'd40);
        check_result("LW",   10, 15, 32'h3B9C_E75A, 32'd44);
        check_result("LW",   11, 16, 32'h3B9C_E75A, 32'd48); // Negative offset test
        check_result("LW",   12, 0,  32'd0,         32'd52); // x0 zero-preservation check

        // 6. Completion Banner
        $display("\n========================================================");
        $display("   ALL RV32I LOAD INSTRUCTION TESTS PASSED!             ");
        $display("========================================================\n");
        $stop;
    end

endmodule