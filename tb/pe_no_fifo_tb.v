`timescale 1ns/1ps

module pe_no_fifo_tb;

    parameter DATA_WIDTH = 32;
    parameter N = 16; // Number of input pairs per testcase
    parameter NUM_TESTCASE = 10;

    reg clk;
    reg clr_n;
    reg start;
    reg valid_in;
    reg last;
    reg [DATA_WIDTH-1:0] a, b;
    wire [DATA_WIDTH-1:0] c;
    wire output_valid;

    // Store input values for result verification
    reg [DATA_WIDTH-1:0] input_a [0:N-1];
    reg [DATA_WIDTH-1:0] input_b [0:N-1];

    reg [DATA_WIDTH-1:0] expected_result;
    integer i, pass, fail;

    // Instantiate PE
    pe_no_fifo uut(
        .clk(clk),
        .clr_n(clr_n),
        .start(start),
        .valid_in(valid_in),
        .last(last),
        .a(a),
        .b(b),
        .c(c),
        .output_valid(output_valid)
    );

    // 100MHz clock
    always #5 clk = ~clk;

    // Reset task
    task apply_reset;
    begin
        clr_n = 0;
        @(posedge clk); #1;
        clr_n = 1;
        @(posedge clk); #1;
    end
    endtask

    // Compute expected result (must have at least 1 input in function)
    function [DATA_WIDTH-1:0] calc_expected(input dummy);
        integer j;
        begin
            calc_expected = 0;
            for (j = 0; j < N; j = j + 1)
                calc_expected = calc_expected + input_a[j] * input_b[j];
        end
    endfunction

    // Send N pairs of data into PE
    task send_inputs;
        integer k;
        begin
            for (k = 0; k < N; k = k + 1) begin
                a = $urandom;
                b = $urandom;
                input_a[k] = a;
                input_b[k] = b;
                valid_in = 1;
                start = (k == 0);
                last = (k == N-1);

                @(posedge clk); #1;

                valid_in = 0;
                start = 0;
                last = 0;
                @(posedge clk); #1; // Allow PE to transfer data through pipeline stages
            end
        end
    endtask

    // Wait for output_valid to be asserted
    task wait_for_output;
        begin
            while (!output_valid) @(posedge clk);
            #1;
        end
    endtask

    // Check output result
    task check_output;
        begin
            expected_result = calc_expected(0); // Dummy input required
            if (output_valid && c === expected_result) begin
                $display("PASS: Output = %h, Expected = %h", c, expected_result);
                pass = pass + 1;
            end else begin
                $display("FAIL: Output = %h, Expected = %h", c, expected_result);
                fail = fail + 1;
            end
        end
    endtask

    // Main stimulus
    initial begin
        clk = 0; clr_n = 1; start = 0; valid_in = 0; last = 0; a = 0; b = 0;
        pass = 0; fail = 0;

        apply_reset();

        for (i = 0; i < NUM_TESTCASE; i = i + 1) begin
            $display("===== Testcase %0d =====", i);
            send_inputs();
            wait_for_output();
            check_output();
            #10;
        end

        $display("Test completed. PASS: %0d, FAIL: %0d", pass, fail);
        $finish;
    end

endmodule
