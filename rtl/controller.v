
module controller
#(
    parameter DATA_WIDTH = 16, // Data width
    parameter M = 3,          // Number of rows in matrix A and C
    parameter K = 3,          // Number of columns in matrix A and rows in matrix B
    parameter N = 3,          // Number of columns in matrix B and C
    parameter N_BANKS = 3     // Number of BRAM banks
)
(
    input wire clk,          // Clock signal
    input wire rst_n,        // Reset signal, active low
    input wire start,        // Start signal to begin the operation

    // Output control signals for Datapath
    output reg [$clog2(K)-1:0] k_idx_out,                   // Current accumulation index
    output reg [N_BANKS-1:0] en_a_brams_out,               // Enable signal for BRAM A
    output reg [N_BANKS * $clog2(M/N_BANKS * K)-1:0] addr_a_brams_out, // Address for BRAM A
    output reg [N_BANKS-1:0] en_b_brams_out,               // Enable signal for BRAM B
    output reg [N_BANKS * $clog2(K * N/N_BANKS)-1:0] addr_b_brams_out, // Address for BRAM B
    output reg en_c_bram_out,                              // Enable signal for BRAM C
    output reg we_c_bram_out,                              // Write enable signal for BRAM C
    output reg [$clog2(M * N)-1:0] addr_c_bram_out,        // Address for BRAM C
    output reg [$clog2(M * N)-1:0] pe_write_idx_out,       // Index for writing PE outputs
    output reg pe_start_out,                               // Start signal for PEs
    output reg pe_valid_in_out,                            // Valid input signal for PEs
    output reg pe_last_out,                                // Last signal for PEs (marks the end of accumulation)
    output reg pe_output_capture_en,                      // Enable signal to capture PE outputs
    output reg done_out                                    // Signal indicating completion
);

    // FSM states
    reg [2:0] current_state; // Current state of the FSM
    reg [2:0] next_state;    // Next state of the FSM

    reg [$clog2(K):0] k_idx; // Accumulation index (looping over K elements)
    reg [$clog2(M):0] m_idx; // Row index for matrix C
    reg [$clog2(N):0] n_idx; // Column index for matrix C

    // Define FSM states
    localparam IDLE     = 3'b000; // Idle state, waiting for start signal
    localparam LOAD_A_B = 3'b001; // Load data from BRAM A and B
    localparam COMPUTE  = 3'b010; // Perform computation in PEs
    localparam WRITE_C  = 3'b011; // Write results to BRAM C
    localparam DONE     = 3'b100; // Operation completed

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_state <= IDLE; // Reset to IDLE state
            k_idx <= 0;            // Reset accumulation index
            m_idx <= 0;            // Reset row index
            n_idx <= 0;            // Reset column index
        end else begin
            current_state <= next_state; // Transition to the next state

            // Update loop indices
            if (current_state == LOAD_A_B || current_state == COMPUTE) begin
                if (k_idx < K - 1) begin
                    k_idx <= k_idx + 1; // Increment accumulation index
                end else begin
                    k_idx <= 0;        // Reset accumulation index
                    if (n_idx < N - 1) begin
                        n_idx <= n_idx + 1; // Increment column index
                    end else if (m_idx < M - 1) begin
                        n_idx <= 0;        // Reset column index
                        m_idx <= m_idx + 1; // Increment row index
                    end else begin
                        n_idx <= 0;        // Reset column index
                        m_idx <= 0;        // Reset row index
                    end
                end
            end
        end
    end

    // FSM state transitions
    always @(*) begin
        next_state = current_state; // Default to the current state
        case (current_state)
            IDLE: begin
                if (start) begin
                    next_state = LOAD_A_B; // Transition to LOAD_A_B state
                end
            end
            LOAD_A_B: begin
                next_state = COMPUTE; // Transition to COMPUTE state
            end
            COMPUTE: begin
                if (k_idx == K - 1) begin
                    next_state = WRITE_C; // Transition to WRITE_C state after accumulation
                end
            end
            WRITE_C: begin
                if (m_idx == M - 1 && n_idx == N - 1) begin
                    next_state = DONE; // Transition to DONE state after writing all results
                end else begin
                    next_state = LOAD_A_B; // Continue loading data for the next computation
                end
            end
            DONE: begin
                if (!start) begin
                    next_state = IDLE; // Transition back to IDLE state
                end
            end
        endcase
    end

    // Signal control logic
    always @(*) begin
        // Default values for all outputs
        k_idx_out = k_idx;
        en_a_brams_out = 0;
        addr_a_brams_out = 0;
        en_b_brams_out = 0;
        addr_b_brams_out = 0;
        en_c_bram_out = 0;
        we_c_bram_out = 0;
        addr_c_bram_out = 0;
        pe_write_idx_out = 0;
        pe_start_out = 0;
        pe_valid_in_out = 0;
        pe_last_out = 0;
        pe_output_capture_en = 0;
        done_out = 0;

        case (current_state)
            IDLE: begin
                // No action in IDLE state
            end
            LOAD_A_B: begin
                en_a_brams_out = {N_BANKS{1'b1}}; // Enable all BRAM A banks
                en_b_brams_out = {N_BANKS{1'b1}}; // Enable all BRAM B banks
                addr_a_brams_out = m_idx * K + k_idx; // Address for BRAM A
                addr_b_brams_out = k_idx * N + n_idx; // Address for BRAM B
            end
            COMPUTE: begin
                pe_start_out = (k_idx == 0); // Start signal for PEs
                pe_valid_in_out = 1;        // Mark input as valid
                pe_last_out = (k_idx == K - 1); // Mark last accumulation cycle
            end
            WRITE_C: begin
                en_c_bram_out = 1;          // Enable BRAM C
                we_c_bram_out = 1;          // Enable write to BRAM C
                addr_c_bram_out = m_idx * N + n_idx; // Address for BRAM C
                pe_write_idx_out = m_idx * N + n_idx; // Index for writing PE outputs
                pe_output_capture_en = 1;   // Capture PE outputs
            end
            DONE: begin
                done_out = 1; // Signal that the operation is complete
            end
        endcase
    end

endmodule	