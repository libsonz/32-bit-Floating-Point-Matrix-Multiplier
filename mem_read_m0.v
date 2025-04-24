module mem_read_m0 # //read matrix m0
(
    parameter D_W = 8, //data width
    parameter N   = 3, // N banks
    parameter M   = 6 // Matrix M*M
)
(
    input clk,
    input [$clog2(M/N)-1:0] row,
    input [$clog2(M)-1:0]   column,
    input                   rd_en,

    output reg [$clog2((M*M)/N)-1:0] rd_addr_bram0,
    output reg [$clog2((M*M)/N)-1:0] rd_addr_bram1,
    output reg [$clog2((M*M)/N)-1:0] rd_addr_bram2,
    output reg                  rd_en_bram0,
    output reg                  rd_en_bram1,
    output reg                  rd_en_bram2
);

    wire [$clog2(M*M)-1:0] address;
    assign address = row * M + column;

    // Internal pipeline registers
    reg [$clog2((M*M)/N)-1:0] rd_addr_pipe [0:N-1];
    reg                       rd_en_pipe [0:N-1];

    integer i;
    always @(posedge clk) begin
        // Stage 0
        rd_addr_pipe[0] <= address[$clog2((M*M)/N)-1:0];
        rd_en_pipe[0]   <= rd_en;

        // Pipeline propagation
        for (i = 1; i < N; i = i + 1) begin
            rd_addr_pipe[i] <= rd_addr_pipe[i-1];
            rd_en_pipe[i]   <= rd_en_pipe[i-1];
        end

        // Assign the final pipeline values to outputs
        rd_addr_bram0 <= rd_addr_pipe[0];
        rd_addr_bram1 <= rd_addr_pipe[1];
        rd_addr_bram2 <= rd_addr_pipe[2];

        rd_en_bram0   <= rd_en_pipe[0];
        rd_en_bram1   <= rd_en_pipe[1];
        rd_en_bram2   <= rd_en_pipe[2];
    end

endmodule

