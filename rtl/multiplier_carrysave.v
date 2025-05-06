module multiplier_carrysave
#(
    parameter N = 24  // Data width parameter
)(
    input  wire [N-1:0]    a,  // Multiplicand
    input  wire [N-1:0]    b,  // Multiplier
    output wire [N*2-1:0]  p   // Product
);

    // Internal signals
    wire [N+1:0] s [N:0];  // Sum wires array
    wire [N+1:0] c [N:0];  // Carry wires array

    generate
        genvar i, j;

        // Generate multiplier array
        for (i = 0; i <= N; i = i + 1) begin : gen_rows
            for (j = 0; j < N; j = j + 1) begin : gen_columns
                // Instantiate multiplier-adder block
                multiplier_adder ma(
                    .a  ( (i < N) ? a[j] : ((j > 0) ? c[N][j-1] : 1'b0)),
                    .b  ( (i < N) ? b[i] : 1'b1),
                    .s_in ( (i > 0 && j < N-1) ? s[i-1][j+1] : 1'b0),
                    .c_in ( (i > 0) ? c[i-1][j] : 1'b0),
                    .s_out ( s[i][j] ),
                    .c_out ( c[i][j] )
                );

                // Assign upper product bits in final row
                if (i == N) begin
                    assign p[N+j] = s[N][j];
                end
            end

            // Assign lower product bits
            assign p[i] = s[i][0];
        end

        // Note: Last carry is intentionally ignored
        // Instead of: assign p[N*2] = c[N][N-1];
    endgenerate

endmodule
