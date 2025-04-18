module mem_read_m0 // read Matrix M0 from BRAM ( Pipeline N stage)
#
(
    parameter   N = 3, // s? stage 
    parameter   M = 6 // matrix M*M
)
(
    input                                   clk,
    input   [$clog2(M/N)-1:0]               row, // so bit de danh dia chi
    input   [$clog2(M)-1:0]                 column,
    input                                   rd_en,

    output  wire    [$clog2((M*M)/N)-1:0]   rd_addr_bram_0,
    output  wire    rd_en_bram_0
);

wire    [31:0]  address;
assign address = (row*M) + column ; // ??i ma tr?n 2 chi?u sang 1 chi?u

assign rd_addr_bram_0  = address; // stage 0
assign rd_en_bram_0    = rd_en;  

// Declaration of arrays inside the module
reg     [$clog2((M*M)/N)-1:0]      rd_addr_bram_reg [N-1:0];
reg     [N-1:0]     rd_en_bram_reg;


// stage 1 and 2
integer x;
always @(posedge clk) begin
    for (x = 1; x < N; x = x + 1) begin
        rd_addr_bram_reg[x] <= rd_addr_bram_reg[x-1]; 
        rd_en_bram_reg[x] <= rd_en_bram_reg[x-1];
    end
end

/*generate
    genvar i;
    for (i = 1; i < N; i = i + 1) begin: addr_gen
        assign rd_addr_bram_0 = rd_addr_bram_reg[i];
        assign rd_en_bram_0 = rd_en_bram_reg[i];
    end
endgenerate */

assign rd_addr_bram_0 = rd_addr_bram_reg[N-1];
assign rd_en_bram_0   = rd_en_bram_reg[N-1];

endmodule


