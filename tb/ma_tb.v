`timescale 1ns/1ps
module ma_tb;

  // Declare testbench signals corresponding to the module's ports
  reg a_tb;
  reg b_tb;
  reg c_in_tb;
  reg s_in_tb;
  wire c_out_tb;
  wire s_out_tb;

  // Instantiate the Unit Under Test (UUT)
  multiplier_adder uut (
    .a(a_tb),
    .b(b_tb),
    .c_in(c_in_tb),
    .s_in(s_in_tb),
    .c_out(c_out_tb),
    .s_out(s_out_tb)
  );

  //----------------------------------------------------------------------------
  // Task: run_test_case
  // Description: Applies input stimulus and checks the output against expected values.
  //----------------------------------------------------------------------------
  task run_test_case;
    // Task arguments: inputs to the UUT and expected outputs
    input in_a;
    input in_b;
    input in_c_in;
    input in_s_in;
    input exp_c_out; // Expected carry out
    input exp_s_out; // Expected sum out

    // Internal variable to calculate the expected product for display
    reg expected_product;

    begin
      // Apply inputs to the testbench registers
      a_tb = in_a;
      b_tb = in_b;
      c_in_tb = in_c_in;
      s_in_tb = in_s_in;

      // Calculate expected product for display
      expected_product = in_a & in_b;

      // Wait for the outputs to settle (a small delay)
      #10;

      // Display the test case inputs, expected outputs, and actual outputs
      $display("Time=%0t: Inputs (a, b, c_in, s_in) = (%b, %b, %b, %b), Product = %b",
               $time, a_tb, b_tb, c_in_tb, s_in_tb, expected_product);
      $display("          Expected (s_out, c_out) = (%b, %b), Actual (s_out, c_out) = (%b, %b)",
               exp_s_out, exp_c_out, s_out_tb, c_out_tb);

      // Check if the actual outputs match the expected outputs
      if (s_out_tb == exp_s_out && c_out_tb == exp_c_out) begin
        $display("          Result: PASS");
      end else begin
        $display("          Result: FAIL");
        // Optional: Stop simulation on first failure
        // $finish;
      end
      $display("------------------------------------------------------");

    end
  endtask // run_test_case

  //----------------------------------------------------------------------------
  // Initial block to sequence test cases
  //----------------------------------------------------------------------------
  initial begin
    // Initialize inputs to a known state at the beginning of simulation
    a_tb = 0;
    b_tb = 0;
    c_in_tb = 0;
    s_in_tb = 0;
    #20; // Allow initial values to propagate

    $display("--- Starting Multiplier Adder Testbench ---");
    $display("------------------------------------------------------");

    // Run at least 10 different test cases by calling the task

    // Test Case 1: 0*0 + 0 + 0 = 0 (sum=0, carry=0)
    run_test_case(0, 0, 0, 0, 0, 0); // in_a, in_b, in_c_in, in_s_in, exp_s_out, exp_c_out

    // Test Case 2: 0*1 + 0 + 0 = 0 (sum=0, carry=0)
    run_test_case(0, 1, 0, 0, 0, 0);

    // Test Case 3: 1*0 + 0 + 0 = 0 (sum=0, carry=0)
    run_test_case(1, 0, 0, 0, 0, 0);

    // Test Case 4: 1*1 + 0 + 0 = 1 (sum=1, carry=0)
    run_test_case(1, 1, 0, 0, 1, 0); // Product is 1, adding 0+0+1 -> sum=1, cout=0

    // Test Case 5: 0*0 + 1 + 0 = 1 (sum=1, carry=0)
    run_test_case(0, 0, 1, 0, 1, 0); // Product is 0, adding 0+0+1 -> sum=1, cout=0

    // Test Case 6: 0*0 + 0 + 1 = 1 (sum=1, carry=0)
    run_test_case(0, 0, 0, 1, 1, 0); // Product is 0, adding 0+1+0 -> sum=1, cout=0

    // Test Case 7: 1*1 + 1 + 0 = 2 (sum=0, carry=1)
    run_test_case(1, 1, 1, 0, 0, 1); // Product is 1, adding 1+0+1 -> sum=0, cout=1

    // Test Case 8: 1*1 + 0 + 1 = 2 (sum=0, carry=1)
    run_test_case(1, 1, 0, 1, 0, 1); // Product is 1, adding 1+1+0 -> sum=0, cout=1

    // Test Case 9: 0*1 + 1 + 1 = 2 (sum=0, carry=1)
    run_test_case(0, 1, 1, 1, 0, 1); // Product is 0, adding 0+1+1 -> sum=0, cout=1

    // Test Case 10: 1*0 + 1 + 1 = 2 (sum=0, carry=1)
    run_test_case(1, 0, 1, 1, 0, 1); // Product is 0, adding 0+1+1 -> sum=0, cout=1

    // Test Case 11: 1*1 + 1 + 1 = 3 (sum=1, carry=1) - All inputs high
    run_test_case(1, 1, 1, 1, 1, 1); // Product is 1, adding 1+1+1 -> sum=1, cout=1

    // Test Case 12: 0*0 + 1 + 1 = 2 (sum=0, carry=1) - Product is 0
    run_test_case(0, 0, 1, 1, 0, 1); // Product is 0, adding 0+1+1 -> sum=0, cout=1


    $display("--- End of Multiplier Adder Testbench ---");
    $display("------------------------------------------------------");

    // Terminate the simulation
    $finish;
  end

endmodule
