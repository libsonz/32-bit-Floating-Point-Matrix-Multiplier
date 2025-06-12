module pe_no_fifo
#(
  parameter DATA_WIDTH = 32
)
(
 input                  clk,
 input                  clr_n,
 input                  start,         // Start a new accumulation cycle
 input                  valid_in,      // Input data is valid
 input                  last,          // Indicates the last input of the accumulation cycle
 input [DATA_WIDTH-1:0] a,
 input [DATA_WIDTH-1:0] b,
 output [DATA_WIDTH-1:0] c,            // Final accumulated output
 output                 output_valid   // Output 'c' is valid
);

   // Stage 1: Input register
   reg [DATA_WIDTH-1:0] a_reg, b_reg;
   reg                  valid1, last1;
   always @(posedge clk or negedge clr_n) begin
     if(!clr_n) begin
       a_reg <= 0; b_reg <= 0; valid1 <= 0; last1 <= 0;
     end else begin
       if(valid_in) begin
         a_reg <= a;
         b_reg <= b;
         valid1 <= 1;
         last1 <= last;
       end else begin
         valid1 <= 0;
         last1 <= 0;
       end
     end
   end

   // Stage 2: Multiplier
   wire [31:0] mult_out;
   wire mult_vld, mult_ovf;
   reg  valid2, last2;
   reg  [31:0] mult_reg;
   multiplier_32bit u_mult (
     .i_a(a_reg),
     .i_b(b_reg),
     .i_vld(valid1),
     .o_res(mult_out),
     .o_res_vld(mult_vld),
     .overflow(mult_ovf)
   );
   always @(posedge clk or negedge clr_n) begin
     if(!clr_n) begin
       mult_reg <= 0; valid2 <= 0; last2 <= 0;
     end else begin
       if (mult_vld) begin
         mult_reg <= mult_out;
         valid2 <= 1;
         last2 <= last1;
       end else begin
         valid2 <= 0;
         last2 <= 0;
       end
     end
   end

   // Stage 3: Accumulator (Adder)
   reg [31:0] acc;
   reg        valid3, last3;
   wire [31:0] add_out;
   wire add_vld, add_ovf;
   adder_32bit u_adder (
     .i_a(acc),
     .i_b(mult_reg),
     .i_vld(valid2),
     .o_res(add_out),
     .o_res_vld(add_vld),
     .overflow(add_ovf)
   );
   always @(posedge clk or negedge clr_n) begin
     if (!clr_n || start) begin
       acc <= 0; valid3 <= 0; last3 <= 0;
     end else begin
       if (add_vld) begin
         acc <= add_out;
         valid3 <= 1;
         last3 <= last2;
       end else begin
         valid3 <= 0;
         last3 <= 0;
       end
     end
   end

   // Output assignment
   assign c = acc;
   assign output_valid = last3 && valid3;

endmodule
