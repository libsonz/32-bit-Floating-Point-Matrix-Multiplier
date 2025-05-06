`timescale 1ns / 1ps

module fa_tb;
    // Inputs
    reg a;
    reg b;
    reg c_in;
    
    // Outputs
    wire sum;
    wire c_out;
    
    // Instantiate the Unit Under Test (UUT)
    full_adder uut (
        .a(a),
        .b(b),
        .c_in(c_in),
        .sum(sum),
        .c_out(c_out)
    );
    
    // Test cases
    initial begin
        // Initialize Inputs
        a = 0;
        b = 0;
        c_in = 0;
        
        // Wait 10 ns for global reset
        #10;
        
        $display("Starting full_adder testbench");
        $display("Truth Table Verification:");
        $display("a b c_in | sum c_out | Expected");
        $display("------------------------------");
        
        // Test all possible input combinations (8 cases)
        // Format: a, b, c_in
        test_case(0, 0, 0);  // 0+0+0
        test_case(0, 0, 1);  // 0+0+1
        test_case(0, 1, 0);  // 0+1+0
        test_case(0, 1, 1);  // 0+1+1
        test_case(1, 0, 0);  // 1+0+0
        test_case(1, 0, 1);  // 1+0+1
        test_case(1, 1, 0);  // 1+1+0
        test_case(1, 1, 1);  // 1+1+1
        
        $display("\nTestbench completed");
        #10 $finish;
    end
    
    task test_case;
        input ta, tb, tc_in;
        reg expected_sum, expected_c_out;
    begin
        a = ta;
        b = tb;
        c_in = tc_in;
        #10; // Allow time for propagation
        
        // Calculate expected values
        expected_sum = a ^ b ^ c_in;
        expected_c_out = (a & b) | (b & c_in) | (a & c_in);
        
        // Display results
        $display("%b %b  %b   |  %b    %b  | %b    %b", 
                a, b, c_in, 
                sum, c_out,
                expected_sum, expected_c_out);
                
        // Verify outputs
        if (sum !== expected_sum || c_out !== expected_c_out) begin
            $display("ERROR: Mismatch detected!");
            $display("Expected: sum=%b, c_out=%b", expected_sum, expected_c_out);
            $display("Got:      sum=%b, c_out=%b", sum, c_out);
        end
    end
    endtask
    
endmodule
