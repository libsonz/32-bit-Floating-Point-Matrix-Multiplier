`timescale 1ns / 1ps

module multiplier_carrysave_tb #(
    parameter N = 4  // Default data width for the testbench
)();

    // Local parameters
    localparam P_WIDTH = 2 * N;
    localparam MAX_VAL = (1 << N) - 1;
    
    // Testbench signals
    reg [N-1:0] a_tb;
    reg [N-1:0] b_tb;
    wire [P_WIDTH-1:0] p_tb;
    
    // Test control
    integer pass_count = 0;
    integer fail_count = 0;
    integer test_num = 0;
    
    // Instantiate the Unit Under Test (UUT)
    multiplier_carrysave #(
        .N(N)
    ) uut (
        .a(a_tb),
        .b(b_tb),
        .p(p_tb)
    );

    // Task to run a single test case
    task automatic run_test;
        input [N-1:0] a_val;
        input [N-1:0] b_val;
        reg [P_WIDTH-1:0] expected;
        begin
            a_tb = a_val;
            b_tb = b_val;
            expected = a_val * b_val;
            #(10 * N);  // Delay proportional to multiplier size
            
            test_num = test_num + 1;
            
            $display("Test %0d: %0d * %0d", test_num, a_val, b_val);
            $display("  Expected: %0d (0x%h)", expected, expected);
            $display("  Actual:   %0d (0x%h)", p_tb, p_tb);
            
            if (p_tb === expected) begin
                pass_count = pass_count + 1;
                $display("  Result: PASS");
            end else begin
                fail_count = fail_count + 1;
                $display("  Result: FAIL");
            end
            $display("----------------------------------");
        end
    endtask

    // Main test sequence
    initial begin
        $display("\nStarting Carry-Save Multiplier Testbench");
        $display("Data Width: %0d bits", N);
        $display("Max Value: %0d", MAX_VAL);
        $display("==================================");
        
        // Basic test cases
        run_test(0, 0);               // 0 * 0
        run_test(0, MAX_VAL);         // 0 * max
        run_test(MAX_VAL, 0);         // max * 0
        run_test(1, 1);               // 1 * 1
        
        // Power-of-two tests
        run_test(2, 4);
        run_test(1 << (N/2), 1 << (N/2));
        
        // Edge cases
        run_test(MAX_VAL, 1);         // max * 1
        run_test(1, MAX_VAL);         // 1 * max
        run_test(MAX_VAL, MAX_VAL);   // max * max
        
        // Random tests
        $display("\nRunning random test cases...");
        repeat (10) begin
            run_test($random % (MAX_VAL+1), $random % (MAX_VAL+1));
        end
        
        // Special cases for N > 4
        if (N > 4) begin
            $display("\nTesting larger numbers...");
            run_test(MAX_VAL/2, MAX_VAL/2);
            run_test(MAX_VAL-1, 2);
            run_test(3, MAX_VAL-3);
        end
        
        // Summary
        $display("\nTestbench Complete");
        $display("Tests Run: %0d", test_num);
        $display("Passed:    %0d", pass_count);
        $display("Failed:    %0d", fail_count);
        
        if (fail_count == 0) begin
            $display("\nSUCCESS: All tests passed!");
        end else begin
            $display("\nFAILURE: Some tests failed");
        end
        
        #10 $finish;
    end

    // Optional waveform dump for debugging
    initial begin
        $dumpfile("multiplier_carrysave_tb.vcd");
        $dumpvars(0, multiplier_carrysave_tb);
    end
endmodule
