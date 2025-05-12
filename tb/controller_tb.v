//----------------------------------------------------------------------------
// Module: matrix_controller_tb
// Description: Testbench for the matrix_controller module.
//              Provides stimulus to test state transitions and outputs.
//              Does NOT include the datapath or BRAMs.
//              Refactored using tasks for better readability.
//----------------------------------------------------------------------------
`timescale 1ns/1ps
module controller_tb;

   // Parameters - Must match the controller instantiation
   parameter DATA_WIDTH = 16; // Data width of matrix elements A and B
   parameter M = 3;           // Number of rows in Matrix A and C
   parameter K = 3;           // Number of columns in Matrix A and rows in Matrix B
   parameter N = 3;           // Number of columns in Matrix B and C
   parameter N_BANKS = 3;     // Number of BRAM banks for Matrix A and B

   // Parameters for the 2D PE Array dimensions (Must match controller)
   parameter PE_ROWS = M;     // Number of PE rows = M
   parameter PE_COLS = N;     // Number of PE columns = N
   parameter N_PE = PE_ROWS * PE_COLS; // Total number of PEs

   // Derived parameters (matching controller, used here for sizing)
   // Ensure dimensions are positive to avoid $clog2(0) issues
   parameter ADDR_WIDTH_A_BANK = (M/N_BANKS * K > 0) ? $clog2(M/N_BANKS * K) : 1;
   parameter ADDR_WIDTH_B_BANK = (K * N/N_BANKS > 0) ? $clog2(K * N/N_BANKS) : 1;
   parameter ADDR_WIDTH_C = (M * N > 0) ? $clog2(M * N) : 1;
   parameter ACC_WIDTH_PE = DATA_WIDTH * 2 + ((K > 1) ? $clog2(K) : 1); // PE accumulator width must match

   // Testbench Signals (Inputs to Controller - Declared as regs)
   reg       clk;         // Clock signal
   reg       rst_n;       // Asynchronous active-low reset
   reg       start_mult;  // Start signal to controller

   // Testbench Signals (Outputs from Controller - Declared as wires)
   wire [$clog2(K)-1:0] k_idx_in;
   wire [N_BANKS-1:0]   en_a_brams_in;
   wire [N_BANKS * ADDR_WIDTH_A_BANK - 1:0] addr_a_brams_in;
   wire [N_BANKS-1:0]                       we_a_brams_in;
   wire [N_BANKS * DATA_WIDTH - 1:0]        din_a_brams_in;
   wire [N_BANKS-1:0]                       en_b_brams_in;
   wire [N_BANKS * ADDR_WIDTH_B_BANK - 1:0] addr_b_brams_in;
   wire [N_BANKS-1:0]                       we_b_brams_in;
   wire [N_BANKS * DATA_WIDTH - 1:0]        din_b_brams_in;
   wire                                     en_c_bram_in;
   wire                                     we_c_bram_in;
   wire [ADDR_WIDTH_C-1:0]                  addr_c_bram_in;
   wire [$clog2(N_PE)-1:0]                  pe_write_idx_in;
   wire                                     pe_start_in;
   wire                                     pe_valid_in_in;
   wire                                     pe_last_in;
   wire                                     pe_output_capture_en;
   wire                                     pe_output_buffer_reset;
   wire                                     mult_done;

   // Testbench Signals (Inputs to Controller simulating Datapath Status - Declared as regs)
   // We will manually control these signals in the testbench to simulate datapath behavior
   reg [(PE_ROWS * PE_COLS)-1:0]            pe_outputs_valid_out_tb;
   reg                                      pe_output_buffer_valid_out_tb;


   // Clock Generation
   always #5 clk = ~clk; // 10ns clock period (adjust as needed)

  // Instantiate the Controller module
   controller
     #(
       .DATA_WIDTH(DATA_WIDTH),
       .M(M),
       .K(K),
       .N(N),
       .N_BANKS(N_BANKS)
       )
   controller_inst (
                    .clk(clk),
                    .rst_n(rst_n),
                    .start_mult(start_mult),

                    // Connected to Testbench Regs simulating Datapath Status
                    .pe_outputs_valid_out(pe_outputs_valid_out_tb),
                    .pe_output_buffer_valid_out(pe_output_buffer_valid_out_tb),

                    // Connected to Testbench Wires (Controller Outputs)
                    .k_idx_in(k_idx_in),
                    .en_a_brams_in(en_a_brams_in),
                    .addr_a_brams_in(addr_a_brams_in),
                    .we_a_brams_in(we_a_brams_in),
                    .din_a_brams_in(din_a_brams_in),
                    .en_b_brams_in(en_b_brams_in),
                    .addr_b_brams_in(addr_b_brams_in),
                    .we_b_brams_in(we_b_brams_in),
                    .din_b_brams_in(din_b_brams_in),
                    .en_c_bram_in(en_c_bram_in),
                    .we_c_bram_in(we_c_bram_in),
                    .addr_c_bram_in(addr_c_bram_in),
                    .pe_write_idx_in(pe_write_idx_in),
                    .pe_start_in(pe_start_in),
                    .pe_valid_in_in(pe_valid_in_in),
                    .pe_last_in(pe_last_in),
                    .pe_output_capture_en(pe_output_capture_en),
                    .pe_output_buffer_reset(pe_output_buffer_reset),
                    .mult_done(mult_done) // Connect to testbench done signal
                    );

   // PE pipeline latency from input registration to output_valid high
   // This should match the PE module's PE_ACC_LATENCY parameter
   localparam PE_ACC_LATENCY = 3;


   //--------------------------------------------------------------------------
   // Testbench Tasks
   //--------------------------------------------------------------------------

   // Task to apply and release reset
   task apply_reset;
      begin
         $display("\n--- Applying Reset ---");
         rst_n = 0; // Assert reset
         #100; // Hold reset for 100 time units
         rst_n = 1; // Release reset
         $display("Reset complete.");
         #100; // Wait for controller to settle in IDLE
         $display("@%0t: Controller should be in IDLE state.", $time);
      end
   endtask


   // Task to start multiplication by asserting start_mult
   task start_multiplication;
      begin
         $display("@%0t: Asserting start_mult...", $time);
         start_mult = 1;
         @(posedge clk); #1; // Wait one clock cycle for controller to register start
      end
   endtask


   // Task to simulate the ACCUMULATE phase duration
   task simulate_accumulation_phase;
      input integer num_cycles;
      begin
         $display("@%0t: Simulating ACCUMULATE phase for %0d cycles...", $time, num_cycles);
         repeat (num_cycles)
           begin
              @(posedge clk); #1;
           end
      end
   endtask


   // Task to simulate the PE pipeline latency
   task simulate_pe_latency;
      input integer latency;
      begin
         $display("@%0t: Simulating PE pipeline latency (%0d cycles)...", $time, latency);
         repeat (latency)
           begin
              @(posedge clk); #1;
           end
      end
   endtask


   // Task to simulate PE outputs becoming valid
   task simulate_pe_outputs_valid;
      begin
         $display("@%0t: Simulating pe_outputs_valid_out going high...", $time);
         pe_outputs_valid_out_tb = {(PE_ROWS * PE_COLS){1'b1}}; // Assert all PE output_valid flags high
         @(posedge clk); #1; // Wait one clock cycle for controller to register valid outputs
      end
   endtask


   // Task to simulate the WRITE_C_BRAM phase duration
   task simulate_write_phase;
      input integer num_elements; // Number of elements to write (M*N)
      begin
         $display("@%0t: Simulating WRITE_C_BRAM phase for %0d cycles...", $time, num_elements);
         // Simulate buffer valid going high after capture
         pe_output_buffer_valid_out_tb = 1;
         repeat (num_elements)
           begin
              @(posedge clk); #1;
           end
         // Simulate buffer valid going low after the last write
         pe_output_buffer_valid_out_tb = 0;
         pe_outputs_valid_out_tb = 'b0; // Deassert PE valid signals after write
      end
   endtask


   // Task to verify the mult_done signal
  task verify_completion;
     begin
        $display("@%0t: Simulating DONE phase. Checking mult_done.", $time);
        @(posedge clk); #1; // Wait one clock cycle to ensure mult_done is stable

        if (mult_done)
          begin
             $display("@%0t: Test PASSED: mult_done signal asserted as expected.", $time);
          end
        else
          begin
             $error("@%0t: Test FAILED: mult_done signal NOT asserted.", $time);
          end
     end
  endtask


   // Task to deassert start_mult and wait for IDLE
   task stop_multiplication;
      begin
         $display("@%0t: Deasserting start_mult...", $time);
         start_mult = 0;
         @(posedge clk); #1; // Wait one clock cycle for controller to register deassertion
         $display("@%0t: Controller should return to IDLE state.", $time);
         #100; // Wait a bit to observe IDLE state
      end
   endtask



   //--------------------------------------------------------------------------
   // Main Initial Block - Test Sequence Orchestration
   //--------------------------------------------------------------------------
   initial
     begin
        // Setup waveform dumping for debugging
        $dumpfile("controller_tb.vcd");
        $dumpvars(0, controller_tb); // Dump all signals in the testbench module

        // Initialize inputs to a known state at time 0
        clk = 0;
        rst_n = 0; // Start with reset asserted
        start_mult = 0;
        pe_outputs_valid_out_tb = 'b0;
        pe_output_buffer_valid_out_tb = 0;

        // Wait for initial setup time
        #100;

        // --- Test Case 1: Basic Multiplication Flow ---
        $display("\n===================================================");
        $display("          Starting Test Case 1: Basic Flow");
        $display("===================================================");

        apply_reset();

        start_multiplication();

        // Simulate the K accumulation cycles + 1 cycle for state transition
        simulate_accumulation_phase(K);

        // Simulate the PE pipeline latency before outputs become valid
        simulate_pe_latency(PE_ACC_LATENCY + 2); // Add some margin

        // Simulate the datapath signaling valid PE outputs
        simulate_pe_outputs_valid();

        // Simulate the M*N cycles required to write to the C BRAM
        simulate_write_phase(N_PE);

        // Verify the controller signals completion
        verify_completion();

        // Stop the multiplication and return to IDLE
        stop_multiplication();

        $display("\n===================================================");
        $display("          Test Case 1 Finished");
        $display("===================================================\n");


        // Add more test cases here if needed (e.g., testing reset during operation)

        #100; // Wait before finishing
        $display("@%0t: Testbench simulation finished.", $time);
        $finish; // End simulation

     end // initial begin
endmodule
