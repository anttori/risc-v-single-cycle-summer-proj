`timescale 1ns / 1ps

module tb_riscv_core_xtea;

    // Clock and reset signals
    logic clk;
    logic rst_n;

    // Core interface signals
    logic [31:0] pc;
    logic [31:0] inst;
    logic [31:0] dmem_addr;
    logic [31:0] dmem_wdata;
    logic        dmem_we;
    logic [3:0]  dmem_byte_en;
    logic [31:0] dmem_rdata;

    // Memory sizing (word-addressed)
    // 4096 words = 16 KB each for instruction and data memory
    localparam int IMEM_DEPTH = 4096;
    localparam int DMEM_DEPTH = 4096;

    logic [31:0] imem [0:IMEM_DEPTH-1];
    logic [31:0] dmem [0:DMEM_DEPTH-1];

    // Instantiate Device Under Test (DUT)
    riscv_core dut (
        .clk          (clk),
        .resetN       (rst_n),
        .inst         (inst),
        .pc           (pc),
        .dmem_data    (dmem_rdata),
        .dmem_wen     (dmem_we),
        .dmem_addr    (dmem_addr),
        .dmem_wdata   (dmem_wdata),
        .dmem_data_en (dmem_byte_en)
    );

    // 50 MHz clock generation (20 ns period)
    always #10 clk = ~clk;

    // Asynchronous instruction read (word-aligned from PC)
    assign inst = (pc[31:2] < IMEM_DEPTH) ? imem[pc[31:2]] : 32'h00000013; // NOP (addi x0, x0, 0)

    // Synchronous data memory read and write with byte-enable support
    wire [29:0] dmem_word_idx = dmem_addr[31:2];

    assign dmem_rdata = (dmem_word_idx < DMEM_DEPTH) ? dmem[dmem_word_idx] : 32'h00000000;

    // Behavioral RAM model with byte-enable write strobes
    always @(posedge clk) begin
        if (dmem_we && (dmem_word_idx < DMEM_DEPTH)) begin
            if (dmem_byte_en[0]) dmem[dmem_word_idx][7:0]   <= dmem_wdata[7:0];
            if (dmem_byte_en[1]) dmem[dmem_word_idx][15:8]  <= dmem_wdata[15:8];
            if (dmem_byte_en[2]) dmem[dmem_word_idx][23:16] <= dmem_wdata[23:16];
            if (dmem_byte_en[3]) dmem[dmem_word_idx][31:24] <= dmem_wdata[31:24];
        end
    end

    // String variable to store resolved path to hex firmware
    string hex_file;
    int    fd;

    // Simulation initialization
    initial begin
        clk   = 1'b0;
        rst_n = 1'b0;

        // 1. Check if custom path is provided via command-line plusarg (+HEX_PATH=...)
        if ($value$plusargs("HEX_PATH=%s", hex_file)) begin
            $display("[TB] Loading hex firmware from plusarg: %s", hex_file);
        end else begin
            // 2. Resolve relative path based on simulator working directory
            // Case A: Simulator launched from repo root
            fd = $fopen("sw/xtea/program.hex", "r");
            if (fd) begin
                hex_file = "sw/xtea/program.hex";
                $fclose(fd);
            end else begin
                // Case B: Simulator launched from quartus/ or sim/
                fd = $fopen("../sw/xtea/program.hex", "r");
                if (fd) begin
                    hex_file = "../sw/xtea/program.hex";
                    $fclose(fd);
                end else begin
                    // Case C: Simulator launched from quartus/simulation/modelsim/
                    fd = $fopen("../../../sw/xtea/program.hex", "r");
                    if (fd) begin
                        hex_file = "../../../sw/xtea/program.hex";
                        $fclose(fd);
                    end else begin
                        // Fallback: local directory
                        hex_file = "program.hex";
                    end
                end
            end
        end

        // Verify that target file exists before calling $readmemh
        fd = $fopen(hex_file, "r");
        if (!fd) begin
            $error("[TB ERROR] Could not open hex file: %s. Verify working directory!", hex_file);
        end else begin
            $fclose(fd);
            $display("[TB] Successfully located firmware: %s", hex_file);
        end

        // Default memory clearing
        for (int i = 0; i < IMEM_DEPTH; i++) imem[i] = 32'h00000013;
        for (int i = 0; i < DMEM_DEPTH; i++) dmem[i] = 32'h00000000;

        // Load binary into IMEM (code) and DMEM (initial data & constants)
        $readmemh(hex_file, imem);
        $readmemh(hex_file, dmem);

        // Reset release
        #25;
        rst_n = 1'b1;
    end

    // Execution watchdog and termination monitor
    logic [31:0] prev_pc;
    int          halt_cycles;
    int          total_cycles;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            prev_pc      <= 32'hFFFFFFFF;
            halt_cycles  <= 0;
            total_cycles <= 0;
        end else begin
            total_cycles <= total_cycles + 1;
            prev_pc      <= pc;

            // Detect infinite loop: while(1) or j halt (PC remains constant)
            if (pc == prev_pc) begin
                halt_cycles <= halt_cycles + 1;
            end else begin
                halt_cycles <= 0;
            end

            // Stop simulation cleanly when CPU reaches halt state
            if (halt_cycles >= 10) begin
                $display("\n=======================================================");
                $display("  SIMULATION HALT DETECTED AT PC = 0x%08X", pc);
                $display("  Total execution cycles: %0d", total_cycles);
                $display("=======================================================\n");
                
                check_results();
                $stop; // Pauses simulation without exit prompt
            end

            // Watchdog limit to catch infinite execution bugs
            if (total_cycles >= 50000) begin
                $display("\n[ERROR] Watchdog timeout reached! CPU did not halt.");
                $stop;
            end
        end
    end

    // Memory verification task
    task check_results();
        // data[0] is at byte address 0x000001A4 -> Word index 105 (0x1A4 / 4)
        int data_word_idx;
        data_word_idx = 32'h000001A4 / 4; 

        $display("--- Final Memory Verification ---");
        $display("Data[0] Word Index: %0d (Addr: 0x%08X) = 0x%08X", data_word_idx,     data_word_idx * 4,       dmem[data_word_idx]);
        $display("Data[1] Word Index: %0d (Addr: 0x%08X) = 0x%08X", data_word_idx + 1, (data_word_idx + 1) * 4, dmem[data_word_idx + 1]);

        if (dmem[data_word_idx] == 32'h00C0FFEE && dmem[data_word_idx + 1] == 32'hFEE1600D) begin
            $display("\n==================================================================");
            $display(">>> [PASS] XTEA encryption & decryption verified successfully! <<<");
            $display("==================================================================\n");
        end else begin
            $display("\n>>> [FAIL] Memory content does not match expected plaintext! <<<\n");
        end
    endtask

endmodule