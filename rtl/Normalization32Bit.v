module Normalization32Bit (
    input [24:0] res,
    input [7:0] exp_base,
    output reg [23:0] man_res,
    output reg [7:0] exp_res,
    output reg overflow
);
    reg [24:0] normalized_result;
    integer i;

    always @(*) begin
        normalized_result = res;
        exp_res = exp_base;
        overflow = 0;
        man_res = 0;

        if (normalized_result == 0) begin // explicit zero
            man_res = 0;
            exp_res = 0;
            overflow = 0;
        end
        else if (normalized_result[24]) begin // MSB là 1, shift phải 1 lần, tăng exponent
            normalized_result = normalized_result >> 1;
            exp_res = exp_base + 1;
            man_res = normalized_result[23:0];
            if (exp_res == 8'b11111111) overflow = 1;
        end
        else begin
            // Shift trái đến khi bit 23 là 1 (chuẩn hóa), giảm exponent
            for (i = 0; i < 24 && normalized_result[23] == 0 && exp_res > 0; i = i + 1) begin
                normalized_result = normalized_result << 1;
                exp_res = exp_res - 1;
            end
            man_res = normalized_result[23:0];
            if (exp_res == 8'b11111111) overflow = 1;
        end
    end
endmodule
