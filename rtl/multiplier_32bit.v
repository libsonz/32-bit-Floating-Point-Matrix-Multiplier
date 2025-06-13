`timescale 1ns / 1ps

module multiplier_32bit (
    input  [31:0] i_a,
    input  [31:0] i_b,
    output [31:0] o_res,
    output        overflow
);

// Internal wires
wire sign_a, sign_b, sign_res;
wire [7:0] exp_a, exp_b, final_exp;
wire [22:0] final_mantissa;
wire result_overflow;
wire [23:0] man_a, man_b;

// Unpacking the inputs - 32bit single precision
assign sign_a = i_a[31];
assign sign_b = i_b[31];
assign exp_a  = i_a[30:23];
assign exp_b  = i_b[30:23];
assign man_a  = (exp_a == 8'b0) ? {1'b0, i_a[22:0]} : {1'b1, i_a[22:0]}; // adding explicit 1 for normalized and 0 for denormalised numbers
assign man_b  = (exp_b == 8'b0) ? {1'b0, i_b[22:0]} : {1'b1, i_b[22:0]};

wire is_nan_a  = ((exp_a == 8'b11111111) && (man_a[22:0] != 0));
wire is_nan_b  = ((exp_b == 8'b11111111) && (man_b[22:0] != 0));
wire is_inf_a  = ((exp_a == 8'b11111111) && (man_a[22:0] == 0));
wire is_inf_b  = ((exp_b == 8'b11111111) && (man_b[22:0] == 0));
wire is_zero_a = (i_a[30:0] == 0);
wire is_zero_b = (i_b[30:0] == 0);

// Compute result sign (XOR of input signs)
assign sign_res = sign_a ^ sign_b;

// Core multiplication and normalization
wire [31:0] core_mult_result;

Multiplication32bit u_Multiplication32bit (
    .man_a(man_a),
    .man_b(man_b),
    .exp_a(exp_a),
    .exp_b(exp_b),
    .final_mantissa(final_mantissa),
    .final_exp(final_exp),
    .overflow(result_overflow)
);

// Special case handling and result composition
assign o_res = (is_nan_a || is_nan_b || ((is_inf_a && is_zero_b) || (is_zero_a && is_inf_b)))  ? 32'h7FC00000 : // NaN
               (is_inf_a || is_inf_b || result_overflow)                                       ? {sign_res, 8'hFF, 23'b0} : // Inf/Overflow
               (is_zero_a || is_zero_b)                                                        ? {sign_res, 31'b0} : // Zero
               {sign_res, final_exp, final_mantissa}; // Normal

assign overflow = (is_nan_a || is_nan_b || is_inf_a || is_inf_b || result_overflow);

endmodule
