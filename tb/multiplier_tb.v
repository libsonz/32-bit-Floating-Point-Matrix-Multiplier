`timescale 1ns / 1ps

module multiplier_tb();

    reg [31:0] i_a, i_b;
    wire [31:0] o_res;
    wire        overflow;

    reg [31:0] expected_res;
    integer pass_count = 0, fail_count = 0, test_count = 0;

    // Instantiate DUT
    multiplier_32bit dut (
        .i_a(i_a),
        .i_b(i_b),
        .o_res(o_res),
        .overflow(overflow)
    );

    // Task to run a single test
    task automatic run_test;
        input [31:0] a_val;
        input [31:0] b_val;
        input [31:0] expect_val;
        begin
            i_a = a_val;
            i_b = b_val;
            expected_res = expect_val;

            #1; // Chờ 1 đơn vị thời gian cho mạch tổ hợp settle

            test_count = test_count + 1;
            $display("Test %0d: 0x%08h * 0x%08h", test_count, a_val, b_val);
            $display("  Expected: 0x%08h", expected_res);
            $display("  Actual:   0x%08h", o_res);
            if (o_res === expected_res) begin
                $display("  Result:   PASS");
                pass_count = pass_count + 1;
            end else begin
                $display("  Result:   FAIL");
                fail_count = fail_count + 1;
            end
            $display("----------------------------------");
        end
    endtask

    // Main test sequence
    initial begin
        $display("A\t\t\tB\t\t\tResult\t\t\tOverflow");

        i_a = 0; i_b = 0;

        // 2.0 * 3.0 = 6.0
        run_test(32'h40000000, 32'h40400000, 32'h40c00000);

        // -2.0 * 3.0 = -6.0
        run_test(32'hc0000000, 32'h40400000, 32'hc0c00000);

        // 0.0 * 123.456 = 0.0
        run_test(32'h00000000, 32'h42f6e979, 32'h00000000);

        // inf * 2.0 = inf
        run_test(32'h7f800000, 32'h40000000, 32'h7f800000);

        // inf * -2.0 = -inf
        run_test(32'h7f800000, 32'hc0000000, 32'hff800000);

        // nan * 2.0 = nan (canonical nan)
        run_test(32'h7fc00000, 32'h40000000, 32'h7fc00000);

        // inf * 0.0 = nan (canonical nan)
        run_test(32'h7f800000, 32'h00000000, 32'h7fc00000);

        // 1.5 * -4.25 = -6.375
        run_test(32'h3fc00000, 32'hc0880000, 32'hc0cc0000);

        // 10.24 * -4.25 = -43.52
        run_test(32'h4123ae14, 32'hc0880000, 32'hc22de8f5);

        // 0.000000001 * -10.88888888 = -1.08888895e-8
        run_test(32'h2f5c28f5, 32'hc120e147, 32'hb10a5b56);

        $display("\nTestbench Complete.");
        $display("Tests Run: %0d", test_count);
        $display("Passed:    %0d", pass_count);
        $display("Failed:    %0d", fail_count);
        #10 $finish;
    end

    // Optional: waveform dump for GTKWave
    initial begin
        $dumpfile("multiplier_tb.vcd");
        $dumpvars(0, multiplier_tb);
    end

endmodule
