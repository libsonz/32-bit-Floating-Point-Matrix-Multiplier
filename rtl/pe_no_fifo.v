`timescale 1ns / 1ps

module pe_no_fifo
#(
    parameter DATA_WIDTH = 32,
    parameter ACC_WIDTH = 32
)
(
    input                   clk,
    input                   clr_n,
    input                   start,
    input                   valid_in,
    input                   last,
    input  [DATA_WIDTH-1:0] a,
    input  [DATA_WIDTH-1:0] b,
    output [ACC_WIDTH-1:0]  c,
    output                  output_valid
);

    // Wires for multiplier and adder outputs
    wire [DATA_WIDTH-1:0] mul_res;
    wire                  mul_overflow;

    wire [ACC_WIDTH-1:0] add_res;
    wire                 add_overflow;

    reg  [ACC_WIDTH-1:0] acc_reg;
    reg                  acc_last;

    // Floating-point multiplier
    multiplier_32bit u_multiplier (
        .i_a(a),
        .i_b(b),
        .o_res(mul_res),
        .overflow(mul_overflow)
    );

    // Floating-point adder
    adder_32bit u_adder (
        .i_a(acc_reg),
        .i_b(mul_res),
        .o_res(add_res),
        .overflow(add_overflow)
    );

    always @(posedge clk or negedge clr_n) begin
        if (!clr_n) begin
            acc_reg  <= 0;
            acc_last <= 0;
        end else if (valid_in) begin
            if (start)
                acc_reg <= mul_res;    // bắt đầu mới, reset tích đầu tiên
            else
                acc_reg <= add_res;    // phép cộng float bình thường
            acc_last <= last;
        end else if (acc_last) begin
            // giữ giá trị sau last
            acc_last <= 0;
        end
    end

    assign c = acc_reg;
    assign output_valid = acc_last;

endmodule
