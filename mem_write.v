module mem_write #
(
    parameter D_W = 8,
    parameter N   = 3,
    parameter M   = 6
)
(
    input clk,
    input rst,
    input [N-1:0] in_valid,
    input [D_W-1:0] in_data0, in_data1, in_data2,  // For N = 3
    output reg [$clog2((M*M)/N)-1:0] wr_addr_bram0, wr_addr_bram1, wr_addr_bram2,
    output [D_W-1:0] wr_data_bram0, wr_data_bram1, wr_data_bram2,
    output [N-1:0] wr_en_bram
);

    // Assigning input data individually
    assign wr_data_bram0 = in_data0;
    assign wr_data_bram1 = in_data1;
    assign wr_data_bram2 = in_data2;

    // Write enable is asserted per channel only when not in reset and input is valid
    assign wr_en_bram = (rst == 1) ? 0 : in_valid;

    // Each address increments independently if corresponding input is valid
    integer x;
    always @(posedge clk) begin
        if (rst) begin
            wr_addr_bram0 <= 0;  // Reset all write addresses to 0
            wr_addr_bram1 <= 0;
            wr_addr_bram2 <= 0;
        end else begin
            if (in_valid[0] == 1'b1) wr_addr_bram0 <= wr_addr_bram0 + 1;
            if (in_valid[1] == 1'b1) wr_addr_bram1 <= wr_addr_bram1 + 1;
            if (in_valid[2] == 1'b1) wr_addr_bram2 <= wr_addr_bram2 + 1;
        end
    end

endmodule
