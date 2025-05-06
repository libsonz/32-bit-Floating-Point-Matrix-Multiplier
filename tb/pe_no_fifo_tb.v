`timescale 1ns/1ps

module pe_no_fifo_tb;

   // Parameters
   parameter DATA_WIDTH = 4;
   // ACC_WIDTH should be large enough to hold the sum of N products.
   // Maximum product is (2^DATA_WIDTH - 1) * (2^DATA_WIDTH - 1).
   // Maximum sum is N * (2^DATA_WIDTH - 1) * (2^DATA_WIDTH - 1).
   // A safe width is $clog2(N) + 2*DATA_WIDTH.
   // Let's use the original ACC_WIDTH definition for now, but be aware of potential overflow.
   parameter ACC_WIDTH = DATA_WIDTH**2; // Original definition from PE module
   parameter N = 16; // Number of inputs (corresponds to K in matrix multiplication)

   // PE pipeline latency from input registration to final acc_reg update
   // Based on the corrected PE: 1 (input reg) + 1 (mul reg) + 1 (acc reg) = 3 cycles.
   localparam PE_ACC_LATENCY = 3;
   localparam NUM_TESTCASE = 10;

   // Testbench signals
   reg        clk;
   reg        clr_n;
   reg        start;    // Start of a new accumulation
   reg        valid_in; // Valid input data for accumulation step
   reg        last;     // Last input data for accumulation step
   reg [DATA_WIDTH-1:0] a;        // Input 'a' to PE
   reg [DATA_WIDTH-1:0] b;        // Input 'b' to PE
   wire [ACC_WIDTH-1:0] c;        // Final accumulated output from PE
   wire                 output_valid; // Output valid signal from PE

   // Expected result calculation
   reg [ACC_WIDTH-1:0]  expected_final_result;
   reg [DATA_WIDTH-1:0] input_a_values [0:N-1]; // Store input values for expected calculation
   reg [DATA_WIDTH-1:0] input_b_values [0:N-1];

   integer              pass;
   integer              fail;

   // Instantiate the PE module (using the corrected version with output_valid)
   pe_no_fifo #(
                .DATA_WIDTH(DATA_WIDTH),
                .ACC_WIDTH(ACC_WIDTH)
                ) uut (
                       .clk(clk),
                       .clr_n(clr_n),
                       .start(start),
                       .valid_in(valid_in),
                       .last(last),
                       .a(a),
                       .b(b),
                       .c(c),
                       .output_valid(output_valid) // Connect the new output_valid port
                       );

   task execute;
      integer k_step, i;
      begin
         $display("@%0t: Starting accumulation sequence with %0d inputs...", $time, N);

         // Feed inputs to the PE over N cycles
         for (k_step = 0; k_step < N; k_step = k_step + 1)
           begin
              // Generate and store inputs
              a = $random;
              b = $random;
              input_a_values[k_step] = a;
              input_b_values[k_step] = b;

              // Set PE control signals for this cycle
              valid_in = 1;             // Input is valid
              start = (k_step == 0);    // Start high only on the first input cycle
              last = (k_step == N - 1); // Last high only on the last input cycle

              // Wait for the positive clock edge to register inputs
              @(posedge clk); #1;

              // Debug displays (optional - waveform viewer is better)
              // $display("@%0t: Input cycle %0d: a=%h, b=%h, start=%b, valid_in=%b, last=%b",
              //          $time, k_step, a, b, start, valid_in, last);
           end // for (k_step = 0; k_step < N; k_step = k_step + 1)

         // Deassert control signals after the last input cycle
         valid_in = 0;
         start = 0;
         last = 0;
         $display("@%0t: Finished feeding inputs. Waiting for pipeline to drain...", $time);

         // Calculate expected final result based on stored inputs
         expected_final_result = 0;
         for (i = 0; i < N; i = i + 1)
        begin
           expected_final_result = expected_final_result + (input_a_values[i] * input_b_values[i]);
        end
         $display("@%0t: Calculated expected final result: %h", $time, expected_final_result);


         // Wait for PE pipeline to drain (PE_ACC_LATENCY cycles)
         // The final result in acc_reg and output_valid are ready PE_ACC_LATENCY cycles
         // after the LAST input was registered (at the end of the last loop iteration).
         for (i = 0; i < PE_ACC_LATENCY; i = i + 1)
           begin
              @(posedge clk);
              // $display("@%0t: Waiting for drain cycle %0d/%0d", $time, i+1, PE_ACC_LATENCY);
           end
         $display("@%0t: Pipeline drain complete. Checking output.", $time);


         // Check the final result when output_valid is high
         // The output_valid signal should be high at the start of this cycle
         // if the PE and timing are correct.
         $display("@%0t: Checking PE output:", $time);
         $display("Actual PE output (c):%h", uut.c);
         $display("PE output_valid:%b", uut.output_valid);
      end
   endtask // execute

   task verify;
      begin
      // Verification
         if (uut.output_valid === 1 && uut.c === expected_final_result)
           begin
              $display("Verification PASSED!");
              pass = pass + 1;
           end
         else
           begin
              $display("Verification FAILED!");
              $display("Expected: %h", expected_final_result);
              $display("Actual:%h", uut.c);
              $display("Output Valid: %b", uut.output_valid);
              fail = fail + 1;
           end // else: !if(uut.output_valid === 1 && uut.c === expected_final_result)
      end
   endtask // verify

   task apply_reset;
      begin
         // Apply reset
         $display("@%0t: Applying reset...", $time);
         clr_n = 0; // Assert active-low reset
         @(posedge clk); #1; // Wait one clock cycle
         clr_n = 1; // Deassert reset
         $display("@%0t: Reset deasserted.", $time);
      end
   endtask // apply_reset


   // Clock generation
   always
     begin
        #5 clk = ~clk; // 100 MHz clock (10ns period)
     end

   // Stimulus
   initial
    begin : stimulus
       integer i;

       // Initialize signals
       clk = 0;
       clr_n = 1; // Start with reset deasserted initially, will assert later
       start = 0;
       valid_in = 0;
       last = 0;
       a = 0;
       b = 0;
       expected_final_result = 0;
       pass = 0;
       fail = 0;

       apply_reset();
       // Wait for the reset to propagate and module to settle
       #10;

       for(i = 0; i < NUM_TESTCASE; i = i + 1)
         begin
            $display("Testcase %d", i);
            execute();
            verify();
	    #10;
            $display("------------------------------------------------");
         end

       #100; // Wait a bit before finishing
       $display("@%0t: Test Completed.", $time);
       $display("Number of pass: %0d", pass);
       $display("Number of fail: %0d", fail);

       $finish; // End simulation
    end // initial begin
endmodule // pe_no_fifo_tb2
