`timescale 1ns / 1ps

module pe_no_fifo #(
    parameter DATA_WIDTH = 32,
    parameter ACC_WIDTH = 32
)(
    input                   clk,
    input                   clr_n,
    input                   start,       // Reset accumulator at new sequence
    input                   valid_in,    // Valid input for this step
    input                   last,        // Last input in sequence
    input  [DATA_WIDTH-1:0] a,
    input  [DATA_WIDTH-1:0] b,
    output [ACC_WIDTH-1:0]  c,
    output                  output_valid // Asserted when output is valid
);

    // Stage 1: Latch input and control signals
    reg  [DATA_WIDTH-1:0] a_reg1, b_reg1;
    reg                   valid_reg1, last_reg1, start_reg1;

    always @(posedge clk or negedge clr_n) begin
        if (!clr_n) begin
            a_reg1     <= 0;
            b_reg1     <= 0;
            valid_reg1 <= 0;
            last_reg1  <= 0;
            start_reg1 <= 0;
        end else begin
            a_reg1     <= a;
            b_reg1     <= b;
            valid_reg1 <= valid_in;
            last_reg1  <= last;
            start_reg1 <= start;
        end
    end

    // Stage 2: Floating-point multiplication (combinational)
    wire [DATA_WIDTH-1:0] mul_res;
    wire                  mul_overflow;

    multiplier_32bit u_multiplier (
        .i_a(a_reg1),
        .i_b(b_reg1),
        .o_res(mul_res),
        .overflow(mul_overflow)
    );

    reg [DATA_WIDTH-1:0] mul_reg2;
    reg                  valid_reg2, last_reg2, start_reg2;

    always @(posedge clk or negedge clr_n) begin
        if (!clr_n) begin
            mul_reg2    <= 0;
            valid_reg2  <= 0;
            last_reg2   <= 0;
            start_reg2  <= 0;
        end else begin
            mul_reg2    <= mul_res;
            valid_reg2  <= valid_reg1;
            last_reg2   <= last_reg1;
            start_reg2  <= start_reg1;
        end
    end

    // Stage 3: Floating-point accumulation (combinational)
    reg  [ACC_WIDTH-1:0] acc_reg3;
    reg                  valid_reg3, last_reg3;

    wire [ACC_WIDTH-1:0] add_res;
    wire                 add_overflow;

    adder_32bit u_adder (
        .i_a(acc_reg3),
        .i_b(mul_reg2),
        .o_res(add_res),
        .overflow(add_overflow)
    );

    always @(posedge clk or negedge clr_n) begin
        if (!clr_n) begin
            acc_reg3    <= 0;
            valid_reg3  <= 0;
            last_reg3   <= 0;
        end else if (valid_reg2) begin
            if (start_reg2)
                acc_reg3 <= mul_reg2;  // Reset accumulator with first product
            else
                acc_reg3 <= add_res;   // Accumulate
            valid_reg3 <= 1;
            last_reg3  <= last_reg2;
        end else begin
            valid_reg3 <= 0;
            last_reg3  <= 0;
        end
    end

    assign c = acc_reg3;
    assign output_valid = last_reg3 && valid_reg3;

endmodule
