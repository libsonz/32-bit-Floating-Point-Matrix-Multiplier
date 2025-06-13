`timescale 1ns / 1ps

module adder_32bit(
    input  [31:0] i_a,
    input  [31:0] i_b,
    output [31:0] o_res,
    output        overflow
);

// Internal wires
wire [7:0] shift;
wire [23:0] al_man_a, al_man_b;
wire sign_a, sign_b, sign_res;
wire [7:0] exp_a, exp_b, exp_res;
wire [23:0] man_a, man_b, man_res;
wire [24:0] res;
wire operation_overflow;

// Unpacking the inputs - 32bit single precision
assign sign_a = i_a[31];
assign sign_b = i_b[31];
assign exp_a  = i_a[30:23];
assign exp_b  = i_b[30:23];
assign man_a  = (exp_a == 8'b0) ? {1'b0, i_a[22:0]} : {1'b1, i_a[22:0]};
assign man_b  = (exp_b == 8'b0) ? {1'b0, i_b[22:0]} : {1'b1, i_b[22:0]};

wire is_nan_a  = ((exp_a == 8'b11111111) && (man_a[22:0] != 0));
wire is_nan_b  = ((exp_b == 8'b11111111) && (man_b[22:0] != 0));
wire is_inf_a  = ((exp_a == 8'b11111111) && (man_a[22:0] == 0));
wire is_inf_b  = ((exp_b == 8'b11111111) && (man_b[22:0] == 0));
wire is_zero_a = (i_a[30:0] == 0);
wire is_zero_b = (i_b[30:0] == 0);

// Align mantissa
CompareAndShift32Bit u_CompareAndShift32Bit (
    .exp_a(exp_a),
    .exp_b(exp_b),
    .man_a(man_a),
    .man_b(man_b),
    .al_man_a(al_man_a),
    .al_man_b(al_man_b),
    .shift(shift)
);

// Addition/Subtraction
Addition32Bit u_Addition32Bit (
    .sign_a(sign_a),
    .sign_b(sign_b),
    .a(al_man_a),
    .b(al_man_b),
    .res(res),
    .sign_res(sign_res)
);

// Normalization
Normalization32Bit u_Normalization32Bit (
    .res(res),
    .exp_base((exp_a > exp_b) ? exp_a : exp_b),
    .man_res(man_res),
    .exp_res(exp_res),
    .overflow(operation_overflow)
);

// Output assignment combinational logic
assign o_res =
    (is_nan_a || is_nan_b || (is_inf_a && is_inf_b && (sign_a != sign_b)))
        ? 32'h7FC00000 // Quiet NaN
    : (is_inf_a)
        ? i_a
    : (is_inf_b)
        ? i_b
    : (is_zero_a && is_zero_b)
        ? 32'b0
    : {sign_res, exp_res, man_res[22:0]};

assign overflow =
    (is_nan_a || is_nan_b || is_inf_a || is_inf_b)
    ? 1'b1
    : operation_overflow;

endmodule
