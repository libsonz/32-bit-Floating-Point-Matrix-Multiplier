module full_adder
(
 input wire  a,   // First input bit
 input wire  b,   // Second input bit
 input wire  c_in, // Carry-in
 output sum, // Sum output
 output c_out // Carry-out
);

   assign sum  = a ^ b ^ c_in;                   // XOR for sum
   assign c_out = (a & b) | (b & c_in) | (a & c_in); // Carry logic

endmodule // full_adder
