`timescale 1ns/1ps

module controller_tb;

    // Parameters
    parameter DATA_WIDTH = 16;
    parameter M = 3;
    parameter K = 3;
    parameter N = 3;
    parameter N_BANKS = 3;

    // Inputs
    reg clk;
    reg rst_n;
    reg start;

    // Outputs
    wire [$clog2(K)-1:0] k_idx_out;
    wire [N_BANKS-1:0] en_a_brams_out;
    wire [N_BANKS * $clog2(M/N_BANKS * K)-1:0] addr_a_brams_out;
    wire [N_BANKS-1:0] en_b_brams_out;
    wire [N_BANKS * $clog2(K * N/N_BANKS)-1:0] addr_b_brams_out;
    wire en_c_bram_out;
    wire we_c_bram_out;
    wire [$clog2(M * N)-1:0] addr_c_bram_out;
    wire [$clog2(M * N)-1:0] pe_write_idx_out;
    wire pe_start_out;
    wire pe_valid_in_out;
    wire pe_last_out;
    wire pe_output_capture_en;
    wire done_out;

    // Clock generation
    initial begin
        clk = 0;
        forever #5 clk = ~clk; // Clock period = 10ns
    end

    // Instantiate the controller module
    controller #(
        .DATA_WIDTH(DATA_WIDTH),
        .M(M),
        .K(K),
        .N(N),
        .N_BANKS(N_BANKS)
    ) uut (
        .clk(clk),
        .rst_n(rst_n),
        .start(start),
        .k_idx_out(k_idx_out),
        .en_a_brams_out(en_a_brams_out),
        .addr_a_brams_out(addr_a_brams_out),
        .en_b_brams_out(en_b_brams_out),
        .addr_b_brams_out(addr_b_brams_out),
        .en_c_bram_out(en_c_bram_out),
        .we_c_bram_out(we_c_bram_out),
        .addr_c_bram_out(addr_c_bram_out),
        .pe_write_idx_out(pe_write_idx_out),
        .pe_start_out(pe_start_out),
        .pe_valid_in_out(pe_valid_in_out),
        .pe_last_out(pe_last_out),
        .pe_output_capture_en(pe_output_capture_en),
        .done_out(done_out)
    );

    // Test sequence
    initial begin
        // Initialize inputs
        rst_n = 0;
        start = 0;

        // Reset the system
        #10 rst_n = 1;

        // Test 1: Start the controller
        #20 start = 1;
        #50 start = 0; // Deactivate start signal after a short pulse

        // Wait for the computation to complete
        wait(done_out == 1);

        // End simulation
        #100 $stop;
    end

    // Monitor signals for debugging
    initial begin
        $monitor("Time: %0t | rst_n: %b | start: %b | done_out: %b | k_idx_out: %b | en_a_brams_out: %b | en_b_brams_out: %b | en_c_bram_out: %b",
                 $time, rst_n, start, done_out, k_idx_out, en_a_brams_out, en_b_brams_out, en_c_bram_out);
    end

endmodule