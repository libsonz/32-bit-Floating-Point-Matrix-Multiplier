module bram
#(
    parameter ADDR_WIDTH = 10,
    parameter DATA_WIDTH = 32
)(
    input                       clk,    // Common clock for both ports
    input                       en_a,   // Port A enable
    input                       we_a,   // Port A write enable
    input [ADDR_WIDTH-1:0]      addr_a, // Port A address
    input [DATA_WIDTH-1:0]      din_a,  // Port A data in
    output reg [DATA_WIDTH-1:0] dout_a, // Port A data out

    input                       en_b,   // Port B enable
    input                       we_b,   // Port B write enable
    input [ADDR_WIDTH-1:0]      addr_b, // Port B address
    input [DATA_WIDTH-1:0]      din_b,  // Port B data in
    output reg [DATA_WIDTH-1:0] dout_b  // Port B data out
);

   (* ram_style = "block" *) reg [DATA_WIDTH-1:0] mem [(1<<ADDR_WIDTH)-1:0];

   // Port A operation
   always @(posedge clk) begin
      if (en_a) begin
         if (we_a) begin
            mem[addr_a] <= din_a;
            // In NO CHANGE mode, output doesn't change on write
        end
        else begin
            dout_a <= mem[addr_a]; // Read operation
        end
    end
    // When disabled, output retains its value (NO CHANGE mode)
end

// Port B operation
always @(posedge clk) begin
   if (en_b) begin
        if (we_b) begin
            mem[addr_b] <= din_b;
            // In NO CHANGE mode, output doesn't change on write
        end
        else begin
            dout_b <= mem[addr_b]; // Read operation
        end
    end
    // When disabled, output retains its value (NO CHANGE mode)
end

endmodule
