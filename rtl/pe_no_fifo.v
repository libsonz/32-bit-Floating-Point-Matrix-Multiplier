module pe_no_fifo
#(
  parameter DATA_WIDTH = 32,
  parameter ACC_WIDTH = DATA_WIDTH*2 // Assuming simple integer accumulation
)
(
 input                  clk,
 input                  clr_n,
 input                  start,       // Start of a new accumulation (clears accumulator)
 input                  valid_in,    // Valid input data for accumulation step
 input                  last,        // Last input data for accumulation step
 input [DATA_WIDTH-1:0] a,
 input [DATA_WIDTH-1:0] b,
 output [ACC_WIDTH-1:0] c,           // Final accumulated output
 output                 output_valid // Indicates when 'c' is valid
);

   // Internal multiplication signals
   wire [DATA_WIDTH*2-1:0] mul_wire;

   // Pipeline stage 1: inputs
   reg [DATA_WIDTH-1:0]    a_reg, b_reg;
   reg                     stage1_valid_reg; // Valid flag for stage 1
   reg                     last_reg1;        // Pipelined 'last' signal

   // Pipeline stage 2: multiplication
   reg [DATA_WIDTH*2-1:0]  mul_reg;
   reg                     stage2_valid_reg; // Valid flag for stage 2
   reg                     last_reg2;        // Pipelined 'last' signal

   // Pipeline stage 3: accumulation
   reg [ACC_WIDTH-1:0]     acc_reg;
   reg                     stage3_valid_reg; // Valid flag for stage 3
   reg                     last_reg3;        // Pipelined 'last' signal

   // Multiplier instance (assuming multiplier_carrysave is a combinational module)
   // Ensure multiplier_carrysave is correctly defined elsewhere
   multiplier_carrysave #(.N(DATA_WIDTH)) csm(.a(a_reg),
                                              .b(b_reg),
                                              .p(mul_wire));

   // Stage 1: Input Registration
   always @(posedge clk, negedge clr_n)
     begin
        if (!clr_n)
          begin
             a_reg <= 0;
             b_reg <= 0;
             stage1_valid_reg <= 0;
             last_reg1 <= 0;
          end
        else
          begin
             // Register inputs and control signals when valid_in is high
             if (valid_in)
               begin
                  a_reg <= a;
                  b_reg <= b;
                  stage1_valid_reg <= 1; // Input stage is valid if valid_in is high
                  last_reg1 <= last;      // Register the 'last' signal
               end
             else
               begin
                  // If valid_in is low, inputs are not valid for this cycle
                  stage1_valid_reg <= 0;
                  last_reg1 <= 0; // Clear pipelined 'last' if no valid input
               end // else: !if(valid_in)
          end // else: !if(!clr_n)
     end // always @ (posedge clk, negedge clr_n)

   // Stage 2: Multiplication Result Registration
   always @(posedge clk, negedge clr_n)
     begin
        if (!clr_n)
          begin
             mul_reg <= 0;
             stage2_valid_reg <= 0;
             last_reg2 <= 0;
          end
        else
          begin
             // Register multiplication result and control signals if stage 1 was valid
             if (stage1_valid_reg)
               begin
                  mul_reg <= mul_wire;
                  stage2_valid_reg <= 1; // Stage 2 is valid if stage 1 was valid
                  last_reg2 <= last_reg1; // Propagate pipelined 'last'
               end
             else
               begin
                  stage2_valid_reg <= 0;
                  last_reg2 <= 0;
               end
          end
     end

   // Stage 3: Accumulation
   always @(posedge clk, negedge clr_n)
     begin
        if (!clr_n || start)
          begin
             acc_reg <= 0;
             stage3_valid_reg <= 0;
             last_reg3 <= 0;
          end
        else
          begin
             // Accumulate if stage 2 was valid
             if (stage2_valid_reg)
               begin
                  // If 'start' is high (and this is the first valid product), initialize accumulator
                  // Otherwise, add the current product to the accumulator
                  //if (start)
                    //begin
                      // acc_reg <= mul_reg; // Initialize with the 0
                    //end
                  //else
                    //begin
                       //acc_reg <= acc_reg + mul_reg; // Accumulate
                    //end
                  acc_reg <= acc_reg + mul_reg;
                  stage3_valid_reg <= 1; // Stage 3 is valid if stage 2 was valid
                  last_reg3 <= last_reg2; // Propagate pipelined 'last'
               end
             else
               begin
                  // If stage 2 was not valid, accumulator holds its value, valid flag is low
                  stage3_valid_reg <= 0;
                  last_reg3 <= 0;
               end
          end
     end

   // Output Logic
   // The final accumulated result is in acc_reg when the pipelined 'last' signal
   // reaches stage 3 (last_reg3), indicating the last product has been added
   // and the accumulation is complete.
   assign c = acc_reg; // Output the accumulator value
   assign output_valid = last_reg3; // Output is valid when the last product has been added

endmodule // pe_no_fifo
