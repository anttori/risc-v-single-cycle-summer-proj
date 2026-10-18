`timescale 1ns / 1ps

import riscv_pkg::*;

module tb_riscv_core_store ();

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
    // Emulated Memories
    // ----------------------------------------------------
    logic [31:0] imem [0:31];
    logic [7:0]  dmem [0:1023];

    // Asynchronous Read for IMEM
    assign inst = imem[pc[31:2]];

    // Asynchronous Read for DMEM (Word-aligned Little-Endian)
    wire [9:0] word_base = {dmem_addr[9:2], 2'b00};
    assign dmem_data = {
        dmem[word_base + 10'd3],
        dmem[word_base + 10'd2],
        dmem[word_base + 10'd1],
        dmem[word_base + 10'd0]
    };

    // Synchronous Byte-Masked Write for DMEM
    always @(posedge clk) begin
        if (dmem_wen) begin
            if (dmem_data_en[0]) dmem[word_base + 10'd0] <= dmem_wdata[7:0];
            if (dmem_data_en[1]) dmem[word_base + 10'd1] <= dmem_wdata[15:8];
            if (dmem_data_en[2]) dmem[word_base + 10'd2] <= dmem_wdata[23:16];
            if (dmem_data_en[3]) dmem[word_base + 10'd3] <= dmem_wdata[31:24];
        end
    end

    // ----------------------------------------------------
    // Helper function for S-Type Instruction Encoding
    // Format: {imm[11:5], rs2[4:0], rs1[4:0], funct3[2:0], imm[4:0], opcode[6:0]}
    // ----------------------------------------------------
    function automatic logic [31:0] encode_s (
        input logic [11:0] imm,
        input logic [4:0]  rs2,
        input logic [4:0]  rs1,
        input logic [2:0]  funct3
    );
        return {imm[11:5], rs2, rs1, funct3, imm[4:0], 7'b0100011};
    endfunction

    // ----------------------------------------------------
    // Program Assembly
    // Base registers:
    //   x1 = 100 (0x64)
    //   x2 = 140 (0x8C)
    // Data registers:
    //   x10 = 0xDEAD_BEEF
    //   x11 = 0xA5A5_5A5A
    //   x12 = 0x0000_0011, x13 = 0x0000_0022
    //   x14 = 0x0000_0033, x15 = 0x0000_0044
    // ----------------------------------------------------
    initial begin
        // 0: SW x10, 0(x1)   -> Addr = 100. Write 0xDEAD_BEEF
        imem[0] = encode_s(12'd0,  5'd10, 5'd1, 3'b010);

        // 1: SW x10, 8(x1)   -> Addr = 108. Write with positive offset
        imem[1] = encode_s(12'd8,  5'd10, 5'd1, 3'b010);

        // 2: SW x10, -28(x2) -> Addr = 140 - 28 = 112. Negative offset check!
        imem[2] = encode_s(-12'd28, 5'd10, 5'd2, 3'b010);

        // 3: SH x11, 16(x1)  -> Addr = 116 (Halfword 0, addr[1]=0). Target word init to FF
        imem[3] = encode_s(12'd16, 5'd11, 5'd1, 3'b001);

        // 4: SH x11, 18(x1)  -> Addr = 118 (Halfword 1, addr[1]=1).
        imem[4] = encode_s(12'd18, 5'd11, 5'd1, 3'b001);

        // 5..8: Sequential Byte writes to form 0x44332211 at Word Addr 128
        // 5: SB x12, 28(x1)  -> Addr = 128 (Byte 0, addr[1:0]=00)
        imem[5] = encode_s(12'd28, 5'd12, 5'd1, 3'b000);

        // 6: SB x13, 29(x1)  -> Addr = 129 (Byte 1, addr[1:0]=01)
        imem[6] = encode_s(12'd29, 5'd13, 5'd1, 3'b000);

        // 7: SB x14, 30(x1)  -> Addr = 130 (Byte 2, addr[1:0]=10)
        imem[7] = encode_s(12'd30, 5'd14, 5'd1, 3'b000);

        // 8: SB x15, 31(x1)  -> Addr = 131 (Byte 3, addr[1:0]=11)
        imem[8] = encode_s(12'd31, 5'd15, 5'd1, 3'b000);

        // 9: NOP / ADDI x0, x0, 0 -> Verify MemRW drops to 0 after stores
        imem[9] = 32'h00000013;
    end

    // ----------------------------------------------------
    // DUT Instantiation
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
    // Clock Generator (50 MHz)
    // ----------------------------------------------------
    initial begin
        clk = 1'b0;
        forever #10 clk = ~clk;
    end

    // ----------------------------------------------------
    // Verification Tasks
    // ----------------------------------------------------
    task check_step (
        input string       inst_name,
        input int          step_idx,
        input logic [31:0] expected_addr,
        input logic [3:0]  expected_mask
    );
        @(negedge clk);

        assert (u_riscv_core.dmem_wen === 1'b1 &&
                u_riscv_core.dmem_addr === expected_addr &&
                u_riscv_core.dmem_data_en === expected_mask)
        begin
            $display("[PASS Control] Step %0d (%-2s): Addr = %0d, ByteMask = %b",
                     step_idx, inst_name, u_riscv_core.dmem_addr, u_riscv_core.dmem_data_en);
        end
        else begin
            $error("[FAIL Control] Step %0d (%-2s): Expected Addr=%0d, Mask=%b. Got Addr=%0d, Mask=%b, wen=%b",
                   step_idx, inst_name, expected_addr, expected_mask,
                   u_riscv_core.dmem_addr, u_riscv_core.dmem_data_en, u_riscv_core.dmem_wen);
        end

        @(posedge clk);
        #1;
    endtask

    task check_word_in_mem (
        input int          word_addr,
        input logic [31:0] expected_word
    );
        logic [31:0] actual_word;
        actual_word = {dmem[word_addr+3], dmem[word_addr+2], dmem[word_addr+1], dmem[word_addr]};

        assert (actual_word === expected_word)
        begin
            $display("[PASS Memory ] Word at %0d = 0x%08h (Match!)", word_addr, actual_word);
        end
        else begin
            $error("[FAIL Memory ] Word at %0d: Expected 0x%08h, Got 0x%08h",
                   word_addr, expected_word, actual_word);
        end
    endtask

    // ----------------------------------------------------
    // Main Stimulus Sequence
    // ----------------------------------------------------
    initial begin
        // 1. Assert Reset
        resetN = 1'b0;
        repeat (2) @(posedge clk);

        // 2. Pre-fill DMEM with background pattern 0xFF to catch accidental overwrites
        for (int i = 0; i < 1024; i++) begin
            dmem[i] = 8'hFF;
        end

        // 3. Deassert Reset
        #1;
        resetN = 1'b1;

        // 4. Preload Register File with base pointers and test values
        u_riscv_core.u_datapath.u_regfile.registers[1]  = 32'd100;         // Base pointer 1
        u_riscv_core.u_datapath.u_regfile.registers[2]  = 32'd140;         // Base pointer 2
        u_riscv_core.u_datapath.u_regfile.registers[10] = 32'hDEAD_BEEF;   // SW word
        u_riscv_core.u_datapath.u_regfile.registers[11] = 32'hA5A5_5A5A;   // Halfword: [15:0] = 0x5A5A
        u_riscv_core.u_datapath.u_regfile.registers[12] = 32'h0000_0011;   // Byte 0
        u_riscv_core.u_datapath.u_regfile.registers[13] = 32'h0000_0022;   // Byte 1
        u_riscv_core.u_datapath.u_regfile.registers[14] = 32'h0000_0033;   // Byte 2
        u_riscv_core.u_datapath.u_regfile.registers[15] = 32'h0000_0044;   // Byte 3

        // 5. Run & Verify Step-by-Step
        // Step 0: SW at Addr 100
        check_step("SW", 0, 32'd100, 4'b1111);
        check_word_in_mem(100, 32'hDEAD_BEEF);

        // Step 1: SW with positive offset at Addr 108
        check_step("SW", 1, 32'd108, 4'b1111);
        check_word_in_mem(108, 32'hDEAD_BEEF);

        // Step 2: SW with negative offset at Addr 112 (140 - 28)
        check_step("SW", 2, 32'd112, 4'b1111);
        check_word_in_mem(112, 32'hDEAD_BEEF);

        // Step 3: SH at Addr 116 (Lower halfword, upper bytes remain FF)
        check_step("SH", 3, 32'd116, 4'b0011);
        check_word_in_mem(116, 32'hFFFF_5A5A); // Proves upper bytes were not overwritten!

        // Step 4: SH at Addr 118 (Upper halfword)
        check_step("SH", 4, 32'd118, 4'b1100);
        check_word_in_mem(116, 32'h5A5A_5A5A);

        // Step 5: SB Byte 0 at Addr 128
        check_step("SB", 5, 32'd128, 4'b0001);
        check_word_in_mem(128, 32'hFFFF_FF11);

        // Step 6: SB Byte 1 at Addr 129
        check_step("SB", 6, 32'd129, 4'b0010);
        check_word_in_mem(128, 32'hFFFF_2211);

        // Step 7: SB Byte 2 at Addr 130
        check_step("SB", 7, 32'd130, 4'b0100);
        check_word_in_mem(128, 32'hFF33_2211);

        // Step 8: SB Byte 3 at Addr 131
        check_step("SB", 8, 32'd131, 4'b1000);
        check_word_in_mem(128, 32'h4433_2211); // All four bytes assembled correctly

        // Step 9: NOP check (MemRW and ByteMask must be 0)
        @(posedge clk);
        #1;
        assert (u_riscv_core.dmem_wen === 1'b0 && u_riscv_core.dmem_data_en === 4'b0000)
            $display("[PASS Control] NOP: Write disabled correctly (wen=0, mask=0000)");
        else
            $error("[FAIL Control] NOP: Write was not disabled!");

        // 6. Final Banner
        $display("\n========================================================");
        $display("   ALL RV32I STORE INSTRUCTION TESTS PASSED!            ");
        $display("========================================================\n");
        $stop;
    end

endmodule