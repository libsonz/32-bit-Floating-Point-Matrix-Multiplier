module multiplier_adder
(
 input a, b,
 input c_in,
 input s_in,
 output c_out, s_out
);

   wire product;

   full_adder fa(.a(product),
                 .b(s_in),
                 .c_in(c_in),
                 .sum(s_out),
                 .c_out(c_out));

   assign product = a & b;

endmodule // multiplier_adder
