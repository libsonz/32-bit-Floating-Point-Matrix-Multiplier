module pe_no_fifo #(
  parameter DATA_WIDTH = 32
)(
  input                  clk,
  input                  rst_n,
  input                  start,
  input                  valid_in,
  input                  last,
  input [DATA_WIDTH-1:0] a,
  input [DATA_WIDTH-1:0] b,
  output [DATA_WIDTH-1:0] c,          // Accumulated result (FP32)
  output                 output_valid // Indicates 'c' is valid
);

  // Stage 1: Register Inputs
  reg [DATA_WIDTH-1:0] a_reg, b_reg;
  reg                  valid1, last1;
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      a_reg <= 0; b_reg <= 0; valid1 <= 0; last1 <= 0;
    end else if (valid_in) begin
      a_reg <= a; b_reg <= b; valid1 <= 1; last1 <= last;
    end else begin
      valid1 <= 0; last1 <= 0;
    end
  end

  // Stage 2: Floating-point multiplication
  wire [DATA_WIDTH-1:0] mult_out;
  wire                  mult_vld;
  multiplier_32bit u_mult (
    .clk(clk),
    .rst(~rst_n),
    .i_a(a_reg),
    .i_b(b_reg),
    .i_vld(valid1),
    .o_res(mult_out),
    .o_res_vld(mult_vld),
    .overflow()
  );
  reg last2;
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n)
      last2 <= 0;
    else if (valid1)
      last2 <= last1;
    else
      last2 <= 0;
  end

  // Stage 3: Floating-point accumulation
  reg [DATA_WIDTH-1:0] acc_reg;
  reg                  acc_valid;
  reg                  last3;
  wire [DATA_WIDTH-1:0] add_out;
  wire                  add_vld;
  adder_32bit u_adder (
    .clk(clk),
    .rst(~rst_n),
    .i_a(acc_reg),
    .i_b(mult_out),
    .i_vld(mult_vld),
    .o_res(add_out),
    .o_res_vld(add_vld)
  );
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n || start) begin
      acc_reg <= 0; acc_valid <= 0; last3 <= 0;
    end else if (mult_vld) begin
      if (!acc_valid)
        acc_reg <= mult_out; 
      else
        acc_reg <= add_out;
      acc_valid <= 1;
      last3 <= last2;
    end else begin
      last3 <= 0;
    end
  end

  assign c = acc_reg;
  assign output_valid = last3;

endmodule
