//----------------------------------------------------------------------------
// Module: datapath
// Description: Datapath for matrix multiplication using BRAMs and a 2D array
//              of INDEPENDENT PEs. Each PE computes one element of C.
//              Updated to use the corrected 'pe_no_fifo' module with output_valid.
//
// Assumptions:
// - Input matrix A (M x K) is partitioned row-wise into N_BANKS BRAMs.
// - Input matrix B (K x N) is partitioned column-wise into N_BANKS BRAMs.
// - Output matrix C (M x N) is stored in one BRAM.
// - Uses the provided 'bram' module (dual-port, synchronous read/write).
// - Uses a 2D array of PE_ROWS x PE_COLS PEs.
// - **Each PE at (pr, pc) computes C[pr][pc] independently.**
// - **Requires 'pe_no_fifo' module to have ports: clk, clr_n, start, valid_in, last, a, b, c, output_valid.**
// - PE pipeline latency is accounted for externally by the controller.
//
// Partitioning Details:
// - A (M x K) row-wise into N_BANKS: A[i][k] is in A_BRAM[i % N_BANKS] at address (i / N_BANKS) * K + k
// - B (K x N) column-wise into N_BANKS: B[k][j] is in B_BRAM[j % N_BANKS] at address k * (N / N_BANKS) + j / N_BANKS
//----------------------------------------------------------------------------
module datapath
#(
  parameter DATA_WIDTH = 16, // Data width of matrix elements A and B
  parameter M = 3,           // Number of rows in Matrix A and C
  parameter K = 3,           // Number of columns in Matrix A and rows in Matrix B
  parameter N = 3,           // Number of columns in Matrix B and C
  parameter N_BANKS = 3,     // Number of BRAM banks for Matrix A and B

  // Parameters for the 2D PE Array dimensions
  // For independent PEs computing C[pr][pc] in PE(pr,pc)
  parameter PE_ROWS = M,     // Number of PE rows = M
  parameter PE_COLS = N      // Number of PE columns = N
)
(
  input wire                                                                           clk,                        // Clock signal
  input wire                                                                           clr_n,                      // Asynchronous active-low reset

  // Control Inputs from Controller (Standard Verilog Port Declarations)
  // These signals control the overall multiplication process
  input wire [$clog2(K)-1:0]                                                           k_idx_in,                   // Current index for accumulation (0 to K-1)

  // A BRAMs Control Inputs (N_BANKS instances) - Now Vectors
  // Controller needs to provide addresses/enables to feed the PEs
  input wire [N_BANKS-1:0]                                                             en_a_brams_in,              // Enable for A banks
  input wire [N_BANKS * ((M/N_BANKS * K > 0) ? $clog2(M/N_BANKS * K) : 1) - 1:0]       addr_a_brams_in,            // Address for A banks
  input wire [N_BANKS-1:0]                                                             we_a_brams_in,              // Write enable for A banks
  input wire [N_BANKS * DATA_WIDTH - 1:0]                                              din_a_brams_in,             // Data input for writing to A banks

  // B BRAMs Control Inputs (N_BANKS instances) - Now Vectors
  // Controller needs to provide addresses/enables to feed the PEs
  input wire [N_BANKS-1:0]                                                             en_b_brams_in,              // Enable for B banks
  input wire [N_BANKS * ((K * N/N_BANKS > 0) ? $clog2(K * N/N_BANKS) : 1) - 1:0]       addr_b_brams_in,            // Address for B banks
  input wire [N_BANKS-1:0]                                                             we_b_brams_in,              // Write enable for B banks
  input wire [N_BANKS * DATA_WIDTH - 1:0]                                              din_b_brams_in,             // Data input for writing to B banks

  // C BRAM Write Control Inputs
  // Controller manages writing from the PE output buffer
  input wire                                                                           en_c_bram_in,               // Enable for writing to C BRAM
  input wire                                                                           we_c_bram_in,               // Write enable for C BRAM
  input wire [((M * N > 0) ? $clog2(M * N) : 1)-1:0]                                   addr_c_bram_in,             // Address for writing to C BRAM
  input wire [$clog2(PE_ROWS*PE_COLS)-1:0]                                             pe_write_idx_in,            // Index for writing PE outputs from buffer (0 to PE_ROWS*PE_COLS-1)


  // PE Control Signals - Broadcast to all PEs
  input wire                                                                           pe_start_in,                // Start signal for PEs (initialize accumulation)
  input wire                                                                           pe_valid_in_in,             // Valid input signal for PEs
  input wire                                                                           pe_last_in,                 // Last input signal for PEs (end of accumulation)

  // PE Output Buffer Control Inputs
  input wire                                                                           pe_output_capture_en,       // Enable to capture PE outputs into buffer
  input wire                                                                           pe_output_buffer_reset,     // Reset the PE output buffer


  // Status Outputs to Controller (Status signals remain similar)
  // Flattened output of all PE results for capture (used to feed the buffer)
  output wire [(PE_ROWS * PE_COLS * (DATA_WIDTH * 2 + ((K > 1) ? $clog2(K) : 1)))-1:0] pe_c_out_out,
  // Flattened output of all PE output_valid signals
  output wire [(PE_ROWS * PE_COLS)-1:0]                                                pe_outputs_valid_out,
  output reg                                                                           pe_output_buffer_valid_out, // Flag indicating valid data in the buffer

  // Output C BRAM Reading Interface (for external system to read the result)
  // This interface remains the same to read the final result from C BRAM.
  input wire                                                                           read_en_c,                  // External read enable for C BRAM Port B
  input wire [((M * N > 0) ? $clog2(M * N) : 1)-1:0]                                   read_addr_c,                // External read address for C BRAM
  output wire [(DATA_WIDTH * 2 + ((K > 1) ? $clog2(K) : 1))-1:0]                       dout_c                      // Data output from C BRAM
);

   // Derived Parameters (matching datapath)
   parameter ADDR_WIDTH_A_BANK = (M/N_BANKS * K > 0) ? $clog2(M/N_BANKS * K) : 1;
   parameter ADDR_WIDTH_B_BANK = (K * N/N_BANKS > 0) ? $clog2(K * N/N_BANKS) : 1;
   parameter ADDR_WIDTH_C = (M * N > 0) ? $clog2(M * N) : 1;
   parameter ACC_WIDTH_PE = DATA_WIDTH * 2 + ((K > 1) ? $clog2(K) : 1); // PE accumulator width must match

   // Internal Signals
   integer   i, j; // Loop variable
   integer   pr_idx, pc_idx; // Loop variables for PE array
   integer   a_bank_idx, b_bank_idx;

  // Internal BRAM Interface Signals (These are outputs from BRAMs)
  wire [DATA_WIDTH-1:0] dout_a_brams[N_BANKS-1:0]; // Data read from A BRAM banks
  wire [DATA_WIDTH-1:0] dout_b_brams[N_BANKS-1:0]; // Data read from B BRAM banks

  // Internal PE Array Interface Signals (2D arrays for inputs and outputs)
  reg [DATA_WIDTH-1:0]  pe_a_in[PE_ROWS-1:0][PE_COLS-1:0]; // Input 'a' to PE array
  reg [DATA_WIDTH-1:0]  pe_b_in[PE_ROWS-1:0][PE_COLS-1:0]; // Input 'b' to PE array
  wire [ACC_WIDTH_PE-1:0]  pe_c_out[PE_ROWS-1:0][PE_COLS-1:0]; // Output 'c' from PE array
  wire                     pe_output_valid[PE_ROWS-1:0][PE_COLS-1:0]; // Output 'output_valid' from PE array


  // Internal Buffer for PE Outputs before Writing to C BRAM (Flattened 1D buffer)
  reg [ACC_WIDTH_PE-1:0]  pe_output_buffer[PE_ROWS*PE_COLS-1:0]; // Buffer to hold PE results

  // Internal wires to slice the flattened address ports
  wire [ADDR_WIDTH_A_BANK-1:0] addr_a_bram_sliced [N_BANKS-1:0];
  wire [ADDR_WIDTH_B_BANK-1:0] addr_b_bram_sliced [N_BANKS-1:0];

  // Internal wire for C BRAM inputs (from the PE output buffer)
  wire [ACC_WIDTH_PE-1:0]  din_c_bram; // Data input to C BRAM

  // Connect flattened address ports to sliced internal wires
  genvar j_gen;
  generate
    for (j_gen = 0; j_gen < N_BANKS; j_gen = j_gen + 1) begin : slice_addrs
      assign addr_a_bram_sliced[j_gen] = addr_a_brams_in[(j_gen * ADDR_WIDTH_A_BANK) +: ADDR_WIDTH_A_BANK];
      assign addr_b_bram_sliced[j_gen] = addr_b_brams_in[(j_gen * ADDR_WIDTH_B_BANK) +: ADDR_WIDTH_B_BANK];
    end
  endgenerate

  // Connect internal PE outputs (2D array) to the flattened output port (vector)
  genvar pr_gen, pc_gen;
  generate
    for (pr_gen = 0; pr_gen < PE_ROWS; pr_gen = pr_gen + 1) begin : flatten_pe_out_rows
      for (pc_gen = 0; pc_gen < PE_COLS; pc_gen = pc_gen + 1) begin : flatten_pe_out_cols
        // Map 2D PE index (pr_gen, pc_gen) to flattened 1D index (pr_gen * PE_COLS + pc_gen)
        assign pe_c_out_out[((pr_gen * PE_COLS) + pc_gen) * ACC_WIDTH_PE +: ACC_WIDTH_PE] = pe_c_out[pr_gen][pc_gen];
        // Flatten the PE output_valid signals as well
        assign pe_outputs_valid_out[((pr_gen * PE_COLS) + pc_gen)] = pe_output_valid[pr_gen][pc_gen];
      end
    end
  endgenerate


  //--------------------------------------------------------------------------
  // BRAM Instantiations
  //--------------------------------------------------------------------------

  // Matrix A BRAMs (N_BANKS instances) - Row-wise Interleaved
  genvar gi_a;
  generate
    for (gi_a = 0; gi_a < N_BANKS; gi_a = gi_a + 1)
      begin : a_bram_gen
        bram #(.ADDR_WIDTH(ADDR_WIDTH_A_BANK), .DATA_WIDTH(DATA_WIDTH))
        a_bram_inst (
            .clk(clk),
            .en_a(en_a_brams_in[gi_a]),// Port A: Read enable (from controller)
            .we_a(we_a_brams_in[gi_a]),// Port A: Write enable (from controller)
            .addr_a(addr_a_bram_sliced[gi_a]), // Port A: Address (from controller)
            .din_a(din_a_brams_in[gi_a * DATA_WIDTH +: DATA_WIDTH]),// Port A: Data input (from controller)
            .dout_a(dout_a_brams[gi_a]), // Port A: Read data out (to PE array)

            // Port B: External Load Interface (Placeholders - controlled externally or by controller)
            .en_b(1'b0), // External load enable (connect to external signal if needed)
            .we_b(1'b0), // External load write enable (connect to external signal if needed)
            .addr_b(0),  // External load address (connect to external signal if needed)
            .din_b(0),   // External load data in (connect to external signal if needed)
            .dout_b()    // Port B: Not used for external load
            );
      end // block: a_bram_gen
  endgenerate

  // Matrix B BRAMs (N_BANKS instances - Partitioned Column-wise)
  genvar gi_b;
  generate
    for (gi_b = 0; gi_b < N_BANKS; gi_b = gi_b + 1)
      begin : b_bram_gen
        bram #(.ADDR_WIDTH(ADDR_WIDTH_B_BANK), .DATA_WIDTH(DATA_WIDTH)) // Use new address width
        b_bram_inst (
            .clk(clk),
            .en_a(en_b_brams_in[gi_b]),// Port A: Read enable (from controller)
            .we_a(we_b_brams_in[gi_b]),// Port A: Write enable (from controller)
            .addr_a(addr_b_bram_sliced[gi_b]), // Port A: Address (from controller)
            .din_a(din_b_brams_in[gi_b * DATA_WIDTH +: DATA_WIDTH]),// Port A: Data input (from controller)
            .dout_a(dout_b_brams[gi_b]), // Port A: Read data out (to PE array)

            // Port B: External Load Interface (Placeholders - controlled externally or by controller)
            .en_b(1'b0), // External load enable (connect to external signal if needed)
            .we_b(1'b0), // External load write enable (connect to external signal if needed)
            .addr_b(0),  // External load address (connect to external signal if needed)
            .din_b(0),   // External load data in (connect to external signal if needed)
            .dout_b()    // Port B: Not used for external load
            );
    end // block: b_bram_gen
  endgenerate


  // Matrix C BRAM
  // This BRAM stores the final M x N result.
  bram #(.ADDR_WIDTH(ADDR_WIDTH_C), .DATA_WIDTH(ACC_WIDTH_PE)) // C BRAM stores accumulated results
  c_bram_inst (
          .clk(clk),
          .en_a(en_c_bram_in),// Port A: Internal write enable (from controller)
          .we_a(we_c_bram_in),// Port A: Internal write operation (from controller)
          .addr_a(addr_c_bram_in), // Port A: Internal write address (from controller)
          .din_a(din_c_bram),// Port A: Internal write data in (from PE outputs)
          .dout_a(),// Port A: Not used for internal write

          .en_b(read_en_c),// Port B: External read enable (from top module)
          .we_b(1'b0),// Port B: External read operation
          .addr_b(read_addr_c), // Port B: External read address (from top module)
          .din_b(0),// Port B: Not used for external read
          .dout_b(dout_c)// Port B: External read data out (to top module)
          );

  //--------------------------------------------------------------------------
  // 2D Independent PE Array Instantiation
  //--------------------------------------------------------------------------
  // Instantiates PE_ROWS x PE_COLS independent processing elements.
  // PE at (pr, pc) computes C[pr][pc].
  genvar pe_pr, pe_pc;
  generate
    for (pe_pr = 0; pe_pr < PE_ROWS; pe_pr = pe_pr + 1) begin : pe_row_gen
      for (pe_pc = 0; pe_pc < PE_COLS; pe_pc = pe_pc + 1) begin : pe_col_gen

        // Instantiate the PE module (using the corrected version)
        pe_no_fifo #(.DATA_WIDTH(DATA_WIDTH), .ACC_WIDTH(ACC_WIDTH_PE)) // Pass calculated ACC_WIDTH
        pe_inst (
          .clk(clk),
          .clr_n(clr_n),
          .start(pe_start_in),    // Broadcast start signal
          .valid_in(pe_valid_in_in), // Broadcast valid_in signal
          .last(pe_last_in),      // Broadcast last signal
          .a(pe_a_in[pe_pr][pe_pc]),  // Input A data (routed below)
          .b(pe_b_in[pe_pr][pe_pc]),  // Input B data (routed below)
          .c(pe_c_out[pe_pr][pe_pc]), // Output accumulated C data (captured below)
          .output_valid(pe_output_valid[pe_pr][pe_pc]) // Connect the new output_valid port
        );

      end // block: pe_col_gen
    end // block: pe_row_gen
  endgenerate


  //--------------------------------------------------------------------------
  // Data Routing from BRAMs to Independent PEs
  // Route data from A and B BRAMs to each independent PE.
  // PE at (pr, pc) (computing C[pr][pc]) needs A[pr][k_idx_in] and B[k_idx_in][pc]
  // in each accumulation step k_idx_in.
  //--------------------------------------------------------------------------
  always @* // Use always @* for combinational logic
    begin
      // Connect the output of the corresponding A and B BRAMs to each PE input 'a' and 'b'
      for (pr_idx = 0; pr_idx < PE_ROWS; pr_idx = pr_idx + 1)
        begin
          for (pc_idx = 0; pc_idx < PE_COLS; pc_idx = pc_idx + 1)
            begin

              // --- Route A data to pe_a_in[pr_idx][pc_idx] ---
              // PE at (pr_idx, pc_idx) needs A[pr_idx][k_idx_in]
              // A[i][k] is in A_BRAM[i % N_BANKS] at address (i / N_BANKS) * K + k
              a_bank_idx = pr_idx % N_BANKS;
              // The controller should be driving the A BRAMs with addresses to provide A[pr_idx][k_idx_in]
              // to the banks needed by the PEs in that row.
              // The data for A[pr_idx][k_idx_in] will appear on dout_a_brams[a_bank_idx].
              if (pr_idx < M && k_idx_in < K)
                begin // Ensure indices are within bounds
                  pe_a_in[pr_idx][pc_idx] = dout_a_brams[a_bank_idx]; // Connect the output of the relevant A BRAM bank
                end
              else
                begin
                  pe_a_in[pr_idx][pc_idx] = {DATA_WIDTH{1'b0}}; // Feed 0 if indices are out of bounds
                end


              // --- Route B data to pe_b_in[pr_idx][pc_idx] ---
              // PE at (pr_idx, pc_idx) needs B[k_idx_in][pc_idx]
              // B[k][j] is in B_BRAM[j % N_BANKS] at address k * (N / N_BANKS) + j / N_BANKS
              b_bank_idx = pc_idx % N_BANKS;
              // The controller should be driving the B BRAMs with addresses to provide B[k_idx_in][pc_idx]
              // to the banks needed by the PEs in that column.
              // The data for B[k_idx_in][pc_idx] will appear on dout_b_brams[b_bank_idx].
              if (k_idx_in < K && pc_idx < N)
                begin // Ensure indices are within bounds
                  pe_b_in[pr_idx][pc_idx] = dout_b_brams[b_bank_idx]; // Connect the output of the relevant B BRAM bank
                end
              else
                begin
                  pe_b_in[pr_idx][pc_idx] = {DATA_WIDTH{1'b0}}; // Feed 0 if indices are out of bounds
                end
            end
        end
    end // always @ (*)


  //--------------------------------------------------------------------------
  // PE Output Buffer Logic
  //--------------------------------------------------------------------------
  // Capture PE outputs into the buffer when enabled by the controller
  // The buffer is now a flattened version of the 2D PE array outputs.
  always @(posedge clk or negedge clr_n)
    begin
      if (!clr_n)
        begin
          pe_output_buffer_valid_out <= 1'b0;
          for (i = 0; i < PE_ROWS*PE_COLS; i = i + 1)
            begin
              pe_output_buffer[i] <= 'b0;
            end
        end
      else
        begin
          if (pe_output_buffer_reset)
            begin
              pe_output_buffer_valid_out <= 1'b0;
              for (i = 0; i < PE_ROWS*PE_COLS; i = i + 1)
                begin
                  pe_output_buffer[i] <= 'b0;
                end
            end
          // Capture PE outputs when the controller enables it.
          // The controller should assert pe_output_capture_en based on pe_outputs_valid_out.
          else if (pe_output_capture_en)
            begin
              pe_output_buffer_valid_out <= 1'b1; // Signal that the buffer has valid data
              // Capture all PE outputs into the flattened buffer
              for (i = 0; i < PE_ROWS; i = i + 1)
                begin
                  for (j = 0; j < PE_COLS; j = j + 1)
                    begin
                      pe_output_buffer[i * PE_COLS + j] <= pe_c_out[i][j];
                    end
                end
            end
          // Invalidate the buffer after the last element is written to C BRAM
          else if (pe_output_buffer_valid_out && pe_write_idx_in == PE_ROWS*PE_COLS - 1 && en_c_bram_in && we_c_bram_in)
            begin
              pe_output_buffer_valid_out <= 1'b0;
            end
        end
    end

  // Output the PE results from the buffer based on the write index
  // This data is fed to the C BRAM write port.
  assign din_c_bram = pe_output_buffer[pe_write_idx_in];

  // The pe_c_out_out port is a flattened vector of all PE outputs before buffering.
  // This assignment is handled by the generate block above.

  // The pe_outputs_valid_out port is a flattened vector of all PE output_valid signals.
  // This assignment is handled by the generate block above.


endmodule // datapath
