//----------------------------------------------------------------------------
// Module: datapath_tb
// Description: Testbench for the datapath module for matrix multiplication.
//              Refactored using tasks for improved readability.
//----------------------------------------------------------------------------
module datapath_tb;

  // Parameters - Must match the datapath module instantiation
  parameter DATA_WIDTH = 4; // Data width of matrix elements A and B
  parameter M = 3;           // Number of rows in Matrix A and C
  parameter K = 3;           // Number of columns in Matrix A and rows in Matrix B
  parameter N = 3;           // Number of columns in Matrix B and C
  parameter N_BANKS = 3;     // Number of BRAM banks for Matrix A and B

  // Parameters for the 2D PE Array dimensions (Must match datapath)
  parameter PE_ROWS = M; // Number of PE rows = M
  parameter PE_COLS = N; // Number of PE columns = N
  parameter N_PE = PE_ROWS * PE_COLS; // Total number of PEs

  // Derived parameters (calculated by datapath, but useful for testbench)
  // Ensure dimensions are positive to avoid $clog2(0) issues
  parameter ADDR_WIDTH_A_BANK = (M/N_BANKS * K > 0) ? $clog2(M/N_BANKS * K) : 1;
  parameter ADDR_WIDTH_B_BANK = (K * N/N_BANKS > 0) ? $clog2(K * N/N_BANKS) : 1;
  parameter ADDR_WIDTH_C = (M * N > 0) ? $clog2(M * N) : 1;
  // Accumulator width: DATA_WIDTH*2 for product + $clog2(K) for K additions
  parameter ACC_WIDTH = DATA_WIDTH * 2 + ((K > 1) ? $clog2(K) : 1);

  // Calculated Sizes for BRAMs and Matrices
  parameter A_BANK_SIZE = (M/N_BANKS) * K; // Size of each A BRAM bank (3/3)*3 = 3
  parameter B_BANK_SIZE = K * (N/N_BANKS); // Size of each B BRAM bank 3*(3/3) = 3
  parameter C_BRAM_SIZE = M * N;           // Size of the C BRAM (3*3 = 9)


  // Testbench Control Parameters
  parameter NUM_TEST_CASES = 100; // How many test case directories to read (test_000 to test_099)
  // !! IMPORTANT: Update this path to where your test case directories are located !!
  // Use a reg array for the base path
  parameter [8*100-1:0] TEST_CASE_DIR_BASE = "/home/lamar/Documents/git/matrix-multiplier/testcases"; // Base directory for test cases (Max 100 chars)
  parameter             MAX_FILENAME_LEN = 150; // Maximum length for generated filenames

  // Testbench Signals (Inputs to Datapath)
  reg                    clk;
  reg                    clr_n;

  reg [$clog2(K)-1:0]    k_idx_in; // Current index for accumulation (0 to K-1)

  // A BRAMs Control Inputs (N_BANKS instances) - Flattened Vectors
  reg [N_BANKS-1:0]      en_a_brams_in;
  reg [N_BANKS-1:0]      we_a_brams_in; // Added write enable signal
  reg [N_BANKS * ADDR_WIDTH_A_BANK - 1:0] addr_a_brams_in;
  reg [N_BANKS * DATA_WIDTH - 1:0]        din_a_brams_in; // Added write data signal

  // B BRAMs Control Inputs (N_BANKS instances) - Flattened Vectors
   reg [N_BANKS-1:0]                      en_b_brams_in ; // Corrected declaration to unpacked array
   reg [N_BANKS-1:0]                      we_b_brams_in ; // Corrected declaration to unpacked array
   reg [N_BANKS * ADDR_WIDTH_B_BANK - 1:0] addr_b_brams_in;
   reg [N_BANKS * DATA_WIDTH - 1:0]        din_b_brams_in; // Corrected declaration to unpacked array

  // C BRAM Write Control Inputs
  reg                      en_c_bram_in;
  reg                      we_c_bram_in;
  reg [ADDR_WIDTH_C-1:0]   addr_c_bram_in;
  reg [$clog2(N_PE)-1:0]   pe_write_idx_in; // Index for writing PE outputs from buffer (0 to N_PE-1)
  //wire [ACC_WIDTH-1:0]     din_c_bram; // Connected internally in datapath, not driven here

  // PE Control Inputs - Broadcast to all PEs
  reg                      pe_start_in;      // Start signal for PEs (high for first K cycle)
  reg                      pe_valid_in_in;   // Valid input signal for PEs (high during K cycles)
  reg                      pe_last_in;       // Last input signal for PEs (high on last K cycle)

  reg                      pe_output_capture_en;   // Enable to capture PE outputs into buffer
  reg                      pe_output_buffer_reset; // Reset the PE output buffer

  // Testbench Signals (Outputs from Datapath)
  wire [N_PE * ACC_WIDTH - 1:0]      pe_c_out_out;     // PE output (flattened) - Captured by buffer
  wire [N_PE-1:0]                    pe_outputs_valid_out; // Flattened PE output_valid signals <-- NEW WIRE
  wire                               pe_output_buffer_valid_out; // Flag indicating valid data in the buffer

  // C BRAM External Read Interface (used by testbench for verification)
  reg                      read_en_c;        // External read enable for C BRAM Port B
  reg [ADDR_WIDTH_C-1:0]   read_addr_c;      // External read address for C BRAM Port B
  wire [(DATA_WIDTH * 2 + ((K > 1) ? $clog2(K) : 1))-1:0] dout_c; // Data output from C BRAM


  // Internal testbench arrays to hold matrix data and expected results
  // These store the data read from input files and the expected result
  reg [DATA_WIDTH-1:0] testbench_A [0:M-1][0:K-1];
  reg [DATA_WIDTH-1:0] testbench_B [0:K-1][0:N-1];
  reg [ACC_WIDTH-1:0]  expected_C  [0:M-1][0:N-1];

  // This stores the actual result read from the DUT's C BRAM
  reg [ACC_WIDTH-1:0]  actual_C [0:M-1][0:N-1];


  // Internal variables for file handling, loops, and address calculation
  integer i, j, k; // Loop variables
  integer test_case; // Current test case number (0 to NUM_TEST_CASES-1)
  integer pass_count; // Counter for passed test cases
  integer fail_count; // Counter for failed test cases
  integer total_errors; // Total element mismatches across all test cases


  genvar bank_idx_gen; // Declare genvar here, within the generate block
  genvar bank_idx_read; // Declare genvar here, within the generate block
  // Clock Generation
  always #5 clk = ~clk; // 10ns clock period (adjust as needed)

  // Instantiate the Datapath module - Connect testbench signals to datapath ports
  datapath2
  #(
    .DATA_WIDTH(DATA_WIDTH),
    .M(M),
    .K(K),
    .N(N),
    .N_BANKS(N_BANKS),
    .PE_ROWS(PE_ROWS),
    .PE_COLS(PE_COLS)
  )
  dut (
    .clk(clk),
    .clr_n(clr_n),

    .k_idx_in(k_idx_in), // Accumulation index

    .en_a_brams_in(en_a_brams_in),
    .addr_a_brams_in(addr_a_brams_in),
    .we_a_brams_in(we_a_brams_in),
    .din_a_brams_in(din_a_brams_in),

    .en_b_brams_in(en_b_brams_in),
    .addr_b_brams_in(addr_b_brams_in),
    .we_b_brams_in(we_b_brams_in),
    .din_b_brams_in(din_b_brams_in),

    .en_c_bram_in(en_c_bram_in),
    .we_c_bram_in(we_c_bram_in),
    .addr_c_bram_in(addr_c_bram_in),
    .pe_write_idx_in(pe_write_idx_in), // Index for writing from buffer
    //.din_c_bram_in(din_c_bram), // Connected internally in datapath

    .pe_start_in(pe_start_in),
    .pe_valid_in_in(pe_valid_in_in),
    .pe_last_in(pe_last_in),

    .pe_output_capture_en(pe_output_capture_en),
    .pe_output_buffer_reset(pe_output_buffer_reset),

    .pe_c_out_out(pe_c_out_out), // Flattened PE outputs
    .pe_outputs_valid_out(pe_outputs_valid_out), // <-- CONNECTED THE NEW OUTPUT
    .pe_output_buffer_valid_out(pe_output_buffer_valid_out),

    .read_en_c(read_en_c),
    .read_addr_c(read_addr_c),
    .dout_c(dout_c)
  );


   // ------------------------------------------------------------------------- //
   // Task to load the DUT's A and B BRAMs by driving the top-level write ports //
   // ------------------------------------------------------------------------- //
   task load_dut_brams_via_top_ports;
      integer matrix_row; // Declare variables at start of task
      integer matrix_col; // Declare variables at start of task
      integer bank_a_idx; // Declare variables at start of task
      integer addr_a; // Declare variables at start of task
      integer bank_b_idx; // Declare variables at start of task
      integer addr_b; // Declare variables at start of task

      begin // Start of task body
         $display("Loading DUT BRAMs by driving top-level write ports...");

         // Initialize local BRAM write control signals
         en_a_brams_in = 0;
         we_a_brams_in = 0;
         addr_a_brams_in = 0;
         din_a_brams_in = 0;

         en_b_brams_in = 0;
         we_b_brams_in = 0;
         addr_b_brams_in = 0;
         din_b_brams_in = 0;

         // Load A BRAMs from testbench_A array by driving write ports
         // A[i][k] is in A_BRAM[i % N_BANKS] at address (i / N_BANKS) * K + k
         for (matrix_row = 0; matrix_row < M; matrix_row = matrix_row + 1)
           begin
              for (matrix_col = 0; matrix_col < K; matrix_col = matrix_col + 1)
                begin
                   bank_a_idx = matrix_row % N_BANKS;
                   addr_a = (matrix_row / N_BANKS) * K + matrix_col;

                   if (addr_a < A_BANK_SIZE)
                     begin
                        // Drive write signals for the specific A bank using flattened ports
                        en_a_brams_in[bank_a_idx] = 1;
                        we_a_brams_in[bank_a_idx] = 1;
                        addr_a_brams_in[(bank_a_idx * ADDR_WIDTH_A_BANK) +: ADDR_WIDTH_A_BANK] = addr_a;
                        din_a_brams_in[(bank_a_idx * DATA_WIDTH) +: DATA_WIDTH] = testbench_A[matrix_row][matrix_col];


                        @(posedge clk); #1; // Apply signals and wait for clock edge

                        // Deassert write signals for this bank
                        en_a_brams_in[bank_a_idx] = 0;
                        we_a_brams_in[bank_a_idx] = 0;

                        $display("  Loading A Bank %0d Addr %0h with Data %h (Expected %h)",
                                 bank_a_idx, addr_a_brams_in[(bank_a_idx * ADDR_WIDTH_A_BANK) +: ADDR_WIDTH_A_BANK],
                                 din_a_brams_in[(bank_a_idx * DATA_WIDTH) +: DATA_WIDTH], testbench_A[matrix_row][matrix_col]);

                        @(posedge clk);
                     end // if (addr_a < A_BANK_SIZE)
                   else
                     begin
                        $warning("A matrix element [%0d][%0d] address %0d exceeds A_BANK_SIZE %0d for bank %0d during top-level port load", matrix_row, matrix_col, addr_a, A_BANK_SIZE, bank_a_idx);
                     end // else: !if(addr_a < A_BANK_SIZE)

                end // for (matrix_col = 0; matrix_col < K; matrix_col = matrix_col + 1)
           end // for (matrix_row = 0; matrix_row < M; matrix_row = matrix_row + 1)

         $display("----------------------------------------------------");

         // Load B BRAMs from testbench_B array by driving write ports
         // B[k][j] is in B_BRAM[j % N_BANKS] at address k * (N / N_BANKS) + j / N_BANKS
         for (matrix_row = 0; matrix_row < K; matrix_row = matrix_row + 1)
           begin // Matrix B has K rows
              for (matrix_col = 0; matrix_col < N; matrix_col = matrix_col + 1)
                begin // Matrix col has N columns
                   bank_b_idx = matrix_col % N_BANKS;
                   addr_b = matrix_row * (N / N_BANKS) + matrix_col / N_BANKS;

                   if (addr_b < B_BANK_SIZE)
                     begin
                        // Drive write signals for the specific B bank using flattened ports
                        en_b_brams_in[bank_b_idx] = 1;
                        we_b_brams_in[bank_b_idx] = 1;
                        addr_b_brams_in[(bank_b_idx * ADDR_WIDTH_B_BANK)+:ADDR_WIDTH_B_BANK] = addr_b;
                        din_b_brams_in[(bank_b_idx * DATA_WIDTH)+:DATA_WIDTH] = testbench_B[matrix_row][matrix_col];


                        @(posedge clk); #1; // Apply signals and wait for clock edge

                        // Deassert write signals for this bank
                        en_b_brams_in[bank_b_idx] = 0;
                        we_b_brams_in[bank_b_idx] = 0;

                        $display("  Loading B Bank %0d Addr %0h with Data %h (Matrix B[%0d][%0d])",
                            bank_b_idx, addr_b, testbench_B[matrix_row][matrix_col], matrix_row, matrix_col);
                     end // if (addr_b < B_BANK_SIZE)
                   else
                     begin
                        $warning("B matrix element [%0d][%0d] address %0d exceeds B_BANK_SIZE %0d for bank %0d during top-level port load", matrix_row, matrix_col, addr_b, B_BANK_SIZE, bank_b_idx);
                     end // else: !if(addr_b < B_BANK_SIZE)

                end // for (matrix_col = 0; matrix_col < N; matrix_col = matrix_col + 1)
           end // for (matrix_row = 0; matrix_row < K; matrix_row = matrix_row + 1)

         $display("BRAM loading completed!");
         #20; // Wait for BRAMs to settle
      end // End of task body

   endtask // load_dut_brams_via_top_ports


   // ----------------------------------------------------------------------------------- //
   // Task to verify the DUT's A and B BRAM contents by reading from top-level read ports
   // ----------------------------------------------------------------------------------- //
   task verify_bram_contents_via_top_ports;
      integer bank_idx; // Declare variables at start of task
      integer addr; // Declare variables at start of task
      integer matrix_row_a, matrix_col_a; // For mapping A BRAM address back to matrix index
      integer matrix_row_b, matrix_col_b; // For mapping B BRAM address back to matrix index

      begin // Start of task body
         $display("\nVerifying DUT BRAM contents by reading from top-level read ports...");

         // Initialize local BRAM read control signals
         en_a_brams_in = 0;
         addr_a_brams_in = 0;

         en_b_brams_in = 0;
         addr_b_brams_in = 0;

         // Ensure write enables are off during reading
         we_a_brams_in = 0;
         we_b_brams_in = 0;


         // Read and display contents of DUT A_BRAM banks
         $display("\nContents of DUT A_BRAMs after loading:");
         for (bank_idx = 0; bank_idx < N_BANKS; bank_idx = bank_idx + 1)
           begin
              $display("  Bank %0d:", bank_idx);
              en_a_brams_in[bank_idx] = 1; // Enable read for this bank
              we_a_brams_in[bank_idx] = 0;
              for (addr = 0; addr < A_BANK_SIZE; addr = addr + 1)
                begin
                   addr_a_brams_in[(bank_idx * ADDR_WIDTH_A_BANK) +: ADDR_WIDTH_A_BANK] = addr; // Set read address

                   @(posedge clk); #1; // Apply address and wait for clock edge
                   //@(posedge clk); #1; // Wait for read data (assuming 1-cycle latency)

                   // Map BRAM address back to matrix index for comparison
                   // Address 'addr' in bank 'bank_idx' corresponds to A[matrix_row_a][matrix_col_a]
                   // addr = (matrix_row_a / N_BANKS) * K + matrix_col_a
                   // matrix_row_a = bank_idx + (addr / K) * N_BANKS
                   // matrix_col_a = addr % K
                   matrix_row_a = bank_idx + (addr / K) * N_BANKS;
                   matrix_col_a = addr % K;


                   $display("    Addr %0d (%h): Read %h (Expected %h)",
                            addr,  addr_a_brams_in[(bank_idx * ADDR_WIDTH_A_BANK) +: ADDR_WIDTH_A_BANK],
                            dut.dout_a_brams[bank_idx], // Read from flattened output
                            testbench_A[matrix_row_a][matrix_col_a] // Compare with testbench array
                            );

                end // for (addr = 0; addr < A_BANK_SIZE; addr = addr + 1)

              en_a_brams_in[bank_idx] = 0; // Disable read for this bank
           end // for (bank_idx = 0; bank_idx < N_BANKS; bank_idx = bank_idx + 1)

         $display("--------------------------------------");


         // Read and display contents of DUT B_BRAM banks
         $display("\nContents of DUT B_BRAMs after loading:");
         for (bank_idx = 0; bank_idx < N_BANKS; bank_idx = bank_idx + 1)
           begin
              $display("  Bank %0d:", bank_idx);
              en_b_brams_in[bank_idx] = 1; // Enable read for this bank
              we_b_brams_in[bank_idx] = 0;
              for (addr = 0; addr < B_BANK_SIZE; addr = addr + 1)
                begin
                   addr_b_brams_in[(bank_idx * ADDR_WIDTH_B_BANK) +: ADDR_WIDTH_B_BANK] = addr; // Set read address

                   @(posedge clk); #1; // Apply address and wait for clock edge
                   //@(posedge clk); #1; // Wait for read data (assuming 1-cycle latency)

                   // Map BRAM address back to matrix index for comparison
                   // Address 'addr' in bank 'bank_idx' corresponds to B[matrix_row_b][matrix_col_b]
                   // addr = matrix_row_b * (N / N_BANKS) + matrix_col_b / N_BANKS
                   // This mapping is a bit trickier. Let's assume N/N_BANKS = 1 for simplicity for now.
                   // If N/N_BANKS > 1, the mapping needs adjustment.
                   // Assuming N/N_BANKS = 1: addr = matrix_row_b * 1 + matrix_col_b / N_BANKS
                   // matrix_row_b = addr
                   // matrix_col_b = bank_idx + (addr % 1) * N_BANKS --> this doesn't look right.

                   // Let's re-evaluate the BRAM mapping:
                   // B[k][j] goes to B_BRAM[j % N_BANKS] at address k * (N / N_BANKS) + j / N_BANKS
                   // To reverse: Given bank_idx and addr, find k and j.
                   // bank_idx = j % N_BANKS
                   // addr = k * (N / N_BANKS) + j / N_BANKS
                   // From bank_idx, we know j must be bank_idx, bank_idx+N_BANKS, bank_idx+2*N_BANKS, ...
                   // From addr, we know k * (N / N_BANKS) must be roughly 'addr'.
                   // Let's assume N/N_BANKS = 1 again for simplicity:
                   // bank_idx = j % N_BANKS --> j = bank_idx (if N_BANKS = N)
                   // addr = k * 1 + j / N_BANKS --> addr = k + bank_idx / N_BANKS
                   // If N_BANKS = N, then N/N_BANKS = 1.
                   // addr = k + j / N  (if N_BANKS = N)
                   // Let's use the original mapping logic in reverse:
                   // Given bank_idx and addr:
                   // Find matrix_row_b (k) and matrix_col_b (j) such that:
                   // bank_idx = matrix_col_b % N_BANKS
                   // addr = matrix_row_b * (N / N_BANKS) + matrix_col_b / N_BANKS

                   // This mapping is correct:
                   matrix_row_b = addr / (N / N_BANKS); // k = addr / (N/N_BANKS)
                   matrix_col_b = (addr % (N / N_BANKS)) * N_BANKS + bank_idx; // j = (addr % (N/N_BANKS)) * N_BANKS + bank_idx


                   $display("    Addr %0d (%h): Read %h (Expected %h)",
                            addr, addr_b_brams_in[(bank_idx * ADDR_WIDTH_B_BANK) +: ADDR_WIDTH_B_BANK],
                            dut.dout_b_brams[bank_idx], // Read from flattened output
                            testbench_B[matrix_row_b][matrix_col_b] // Compare with testbench array
                            );

                end // for (addr = 0; addr < B_BANK_SIZE; addr = addr + 1)
              en_b_brams_in[bank_idx] = 0; // Disable read for this bank
           end // for (bank_idx = 0; bank_idx < N_BANKS; bank_idx = bank_idx + 1)
         $display("--------------------------------------");
         // Assign local registers to top-level datapath input ports for reading
         // Note: These are the same ports used for writing, assuming dual-port BRAMs
         // where Port A is write and Port B is read, and the datapath multiplexes correctly.
         // If your datapath uses separate ports for read/write, adjust connections here.
         /*
          en_a_brams_in = local_read_en_a_brams; // Re-purpose these signals for reading
          addr_a_brams_in = local_read_addr_a_brams; // Re-purpose these signals for reading

          en_b_brams_in = local_read_en_b_brams; // Re-purpose these signals for reading
          addr_b_brams_in = local_read_addr_b_brams; // Re-purpose these signals for reading
         */

      end // task verify_bram_contents_via_top_ports
   endtask // verify_bram_contents_via_top_ports




   // -------------------------------------- //
   // --- Tasks for Test Case Management ---
   // -------------------------------------- //
  // Task to read A and B matrices from external text files
  task read_matrices_and_expected_C;
    input integer test_num;
    // Use reg arrays for filenames instead of string
    reg [8*MAX_FILENAME_LEN-1:0] dir_path;
    reg [8*MAX_FILENAME_LEN-1:0] a_filename;
    reg [8*MAX_FILENAME_LEN-1:0] b_filename;
    reg [8*MAX_FILENAME_LEN-1:0] c_filename;
    integer matrix_row; // Declare variables at start of task
    integer matrix_col; // Declare variables at start of task
    reg [DATA_WIDTH-1:0] read_value_data; // Declare variables at start of task
    reg [ACC_WIDTH-1:0] read_value_acc; // Declare variables at start of task
    integer scan_ret; // Declare variables at start of task
    integer file_handle; // Declare variables at start of task

    begin // Start of task body
      // Construct filenames using $sformatf - Breaking it down
      $sformat(dir_path, "%0s/test_%0d", TEST_CASE_DIR_BASE, test_num);
      $sformat(a_filename, "%0s/matrix_A.txt", dir_path);
      $sformat(b_filename, "%0s/matrix_B.txt", dir_path);
      $sformat(c_filename, "%0s/expected_C.txt", dir_path);


      $display("Reading test case %0d: %s, %s, and %s", test_num, a_filename, b_filename, c_filename);

      // Read A matrix (assuming hexadecimal values in file)
      file_handle = $fopen(a_filename, "r"); // Open file for reading
      if (file_handle == 0) begin
        $error("Could not open A matrix file: %s", a_filename);
        $finish; // Abort simulation on error
      end
      // Read matrix elements row by row
      for (matrix_row = 0; matrix_row < M; matrix_row = matrix_row + 1) begin
        for (matrix_col = 0; matrix_col < K; matrix_col = matrix_col + 1) begin
          // Read hexadecimal value (%h)
          scan_ret = $fscanf(file_handle, "%h", read_value_data);
          if (scan_ret != 1) begin
            $error("Error reading A matrix file %s at row %0d, col %0d", a_filename, matrix_row, matrix_col);
            $fclose(file_handle);
            $finish;
          end
          testbench_A[matrix_row][matrix_col] = read_value_data; // Store in testbench array
        end
      end
      $fclose(file_handle); // Close file

      // Display the contents of testbench_A after reading
      $display("\nContents of testbench_A after reading:");
      for (matrix_row = 0; matrix_row < M; matrix_row = matrix_row + 1) begin
          $write("Row %0d: ", matrix_row);
          for (matrix_col = 0; matrix_col < K; matrix_col = matrix_col + 1) begin
              $write("%h ", testbench_A[matrix_row][matrix_col]);
          end
          $display(""); // Newline after each row
      end
      $display("--------------------------------------");


      // Read B matrix (assuming hexadecimal values in file)
      file_handle = $fopen(b_filename, "r"); // Open file for reading
       if (file_handle == 0) begin
        $error("Could not open B matrix file: %s", b_filename);
        $finish;
      end
      // Read matrix elements row by row
      for (matrix_row = 0; matrix_row < K; matrix_row = matrix_row + 1) begin // B has K rows
        for (matrix_col = 0; matrix_col < N; matrix_col = matrix_col + 1) begin // B has N columns
           // Read hexadecimal value (%h)
           scan_ret = $fscanf(file_handle, "%h", read_value_data);
           if (scan_ret != 1) begin
            $error("Error reading B matrix file %s at row %0d, col %0d", b_filename, matrix_row, matrix_col);
            $fclose(file_handle);
            $finish;
          end
          testbench_B[matrix_row][matrix_col] = read_value_data; // Store in testbench array
        end
      end
      $fclose(file_handle); // Close file

       // Display the contents of testbench_B after reading
      $display("\nContents of testbench_B after reading:");
      for (matrix_row = 0; matrix_row < K; matrix_row = matrix_row + 1) begin
          $write("Row %0d: ", matrix_row);
          for (matrix_col = 0; matrix_col < N; matrix_col = matrix_col + 1) begin
              $write("%h ", testbench_B[matrix_row][matrix_col]);
          end
          $display(""); // Newline after each row
      end
      $display("--------------------------------------");


      // Read expected C matrix (assuming hexadecimal values in file)
      file_handle = $fopen(c_filename, "r"); // Open file for reading
      if (file_handle == 0) begin
        $error("Could not open expected C matrix file: %s", c_filename);
        $finish;
      end
      for (matrix_row = 0; matrix_row < M; matrix_row = matrix_row + 1) begin
        for (matrix_col = 0; matrix_col < N; matrix_col = matrix_col + 1) begin
           // Read hexadecimal value (%h)
           scan_ret = $fscanf(file_handle, "%h", read_value_acc);
           if (scan_ret != 1) begin
            $error("Error reading expected C matrix file %s at row %0d, col %0d", c_filename, matrix_row, matrix_col);
            $fclose(file_handle);
            $finish;
          end
          expected_C[matrix_row][matrix_col] = read_value_acc; // Store in testbench array
        end
      end
      $fclose(file_handle); // Close file

      $display("Matrices and expected C read successfully.");
    end // End of task body
  endtask // read_matrices_and_expected_C





   // --------------------------------------------------------------------- //
   // Task to execute matrix multiplication sequence for 2D independent PEs //
   // Designed to work with the CORRECTED pe_no_fifo module's output_valid. //
   // --------------------------------------------------------------------- //
   task execute_matrix_mult;
      integer k_step; // Declare variables at start of task
      integer bank_idx; // Declare variables at start of task
      integer pe_write_idx; // Declare variables at start of task
      integer c_addr; // Declare variables at start of task
      integer i; // Loop variable for draining
      // Removed pr_idx, pc_idx - not needed for valid hierarchical paths in $display loops

      // PE pipeline latency from input registration to final acc_reg update is 3 cycles
      // (1 cycle input reg + 1 cycle mul reg + 1 cycle acc reg).
      // The final result is ready in acc_reg 3 cycles AFTER the last input was REGISTERED.
      // The last input is registered at the end of the cycle where k_step = K-1 and valid_in is high.
      localparam PE_ACC_LATENCY = 3; // This is the latency for the PE itself

      begin // Start of task body
         $display("Executing matrix multiplication sequence for 2D independent PEs...");

         // Initialize control signals for execution
         k_idx_in = 0;
         pe_start_in = 0;
         pe_valid_in_in = 0;
         pe_last_in = 0;
         en_a_brams_in = 'b0;
         addr_a_brams_in = 'b0;
         we_a_brams_in = 'b0; // Ensure write is off
         din_a_brams_in = 'b0;
         en_b_brams_in = 'b0;
         addr_b_brams_in = 'b0;
         we_b_brams_in = 'b0; // Ensure write is off
         din_b_brams_in = 'b0;
         pe_output_capture_en = 0;
         pe_write_idx_in = 0;
         en_c_bram_in = 0;
         we_c_bram_in = 0;
         addr_c_bram_in = 0;


         // Reset the PE output buffer before starting accumulation
         pe_output_buffer_reset = 'b1;
         @(posedge clk); #1;
         pe_output_buffer_reset = 'b0;
         @(posedge clk); #1; // Wait for reset to clear

         // Iterate through accumulation steps (K steps for each C element)
         for (k_step = 0; k_step < K; k_step = k_step + 1)
           begin

              // Set the current accumulation index (0 to K-1)
              k_idx_in = k_step;

              // Set PE control signals for this accumulation step (broadcast)
              pe_valid_in_in = 1;               // Inputs are valid during accumulation
              pe_start_in = (k_step == 0);      // Start high ONLY on first k_step
              pe_last_in = (k_step == K - 1);   // Last high on final k_step

              // --- Drive A BRAM Addresses and Enables ---
              // For each PE row pr, need A[pr][k_step] from A_BRAM[pr % N_BANKS] at address (pr / N_BANKS) * K + k_step
              // The datapath connects dout_a_brams[bank_idx] to PEs in rows pr where pr % N_BANKS == bank_idx.
              // To feed A[pr][k_step] to PE row pr, we need to read it from A_BRAM[pr % N_BANKS].
              // The address for A[pr][k_step] in A_BRAM[pr % N_BANKS] is (pr / N_BANKS) * K + k_step.
              // The testbench needs to set addr_a_brams_in such that for each bank_idx, the address
              // for a row 'i' where i % N_BANKS == bank_idx is provided.
              // Assuming for bank_idx, we read A[bank_idx][k_step] if M >= N_BANKS.
              // Address for A[bank_idx][k_step] in A_BRAM[bank_idx]: (bank_idx / N_BANKS) * K + k_step
              for (bank_idx = 0; bank_idx < N_BANKS; bank_idx = bank_idx + 1)
                begin
                   // This address calculation assumes PE row index == bank index for the data needed by that bank.
                   // This is a simplification based on the datapath routing and partitioning comments.
                   // A more general approach might require iterating through PE rows and calculating the bank/address for each.
                   addr_a_brams_in[(bank_idx * ADDR_WIDTH_A_BANK) +: ADDR_WIDTH_A_BANK] = (bank_idx / N_BANKS) * K + k_step;
                end
              en_a_brams_in = {N_BANKS{1'b1}}; // Enable read for all A banks

              // --- Drive B BRAM Addresses and Enables ---
              // For each PE col pc, need B[k_step][pc] from B_BRAM[pc % N_BANKS] at address k_step * (N / N_BANKS) + pc / N_BANKS
              // The datapath connects dout_b_brams[bank_idx] to PEs in cols pc where pc % N_BANKS == bank_idx.
              // To feed B[k_step][pc] to PE col pc, we need to read it from B_BRAM[pc % N_BANKS].
              // The address for B[k_step][pc] in B_BRAM[pc % N_BANKS] is k_step * (N / N_BANKS) + pc / N_BANKS.
              // The testbench needs to set addr_b_brams_in such that for each bank_idx, the address
              // for a col 'j' where j % N_BANKS == bank_idx is provided.
              // Assuming for bank_idx, we read B[k_step][bank_idx] if N >= N_BANKS.
              // Address for B[k_step][bank_idx] in B_BRAM[bank_idx]: k_step * (N / N_BANKS) + bank_idx / N_BANKS
              for (bank_idx = 0; bank_idx < N_BANKS; bank_idx = bank_idx + 1)
                begin
                   // This address calculation assumes PE column index == bank index for the data needed by that bank.
                   addr_b_brams_in[(bank_idx * ADDR_WIDTH_B_BANK) +: ADDR_WIDTH_B_BANK] = k_step * (N / N_BANKS) + bank_idx / N_BANKS;
                end
              en_b_brams_in = {N_BANKS{1'b1}}; // Enable read for all B banks



              // Wait for BRAM read latency (1 cycle)
              // Data becomes available at dout_a_brams and dout_b_brams
              // PE inputs (pe_a_in, pe_b_in) update combinationally


              @(posedge clk); #1; // PE registers the data into a_reg/b_reg. This is the end of the input cycle.

              $display("@%0t: Accumulation step %0d complete.", $time, k_step);

           end // for (k_step = 0; k_step < K; k_step = k_step + 1)

         // Deassert control signals after the loop
         pe_valid_in_in = 0;
         pe_start_in = 0;
         pe_last_in = 0;
         en_a_brams_in = 'b0; // Disable BRAM reads
         en_b_brams_in = 'b0;

         $display("@%0t: Finished feeding inputs. Waiting for PE outputs to become valid...", $time);
         for(i = 0; i < PE_ACC_LATENCY; i = i + 1)
           begin
              @(posedge clk);
           end

         $display("@%0t: Pipeline drain complete. Checking output.", $time);
         // Wait for all PE outputs to become valid
         // This assumes all PEs finish at the same time and their output_valid signals
         // are synchronous. Wait until all bits of pe_outputs_valid_out are high.
         // Need to wait at least PE_ACC_LATENCY cycles after the last input was registered.
         // The last input was registered at the end of the second @(posedge clk) in the last loop iteration.
         // So we wait PE_ACC_LATENCY more cycles from that point.
         // The 'wait' condition will handle the exact timing based on the PE's output_valid.

         wait (pe_outputs_valid_out == {(PE_ROWS * PE_COLS){1'b1}}); // Wait for all PE output_valid flags to be high
         $display("@%0t: All PE outputs are valid.", $time);

         // --- Capture PE Outputs into Buffer ---
         // Capture PE outputs now that they are valid.
         $display("@%0t: Capturing PE outputs...", $time);
         pe_output_capture_en = 1; // Enable capture for one cycle
         @(posedge clk); #1;
         pe_output_capture_en = 0; // Disable capture

         @(posedge clk); #1; // Wait for buffer registers and valid flag to update

         $display("\n@%0t: After PE Output Capture", $time);
         // Display buffer content (optional - use waveform viewer for detailed debug)
         for (pe_write_idx = 0; pe_write_idx < PE_ROWS * PE_COLS; pe_write_idx = pe_write_idx + 1)
           begin
              //Adjust hierarchical path if needed, e.g., dut.pe_output_buffer[pe_write_idx]
              $display("PE Output Buffer[%0d]: %h", pe_write_idx, dut.pe_output_buffer[pe_write_idx]);
           end
         $display("--------------------------------------");


         // --- Write PE Buffer to C BRAM ---
         // This part remains the same, writing from the captured buffer.
         $display("@%0t: Writing buffered PE outputs to C BRAM...", $time);
         en_c_bram_in = 1; // Enable C BRAM Port A (Write)
         we_c_bram_in = 1; // Enable write operation

         for (pe_write_idx = 0; pe_write_idx < PE_ROWS * PE_COLS; pe_write_idx = pe_write_idx + 1)
           begin
              // The flattened buffer index maps directly to the flattened C BRAM address
              addr_c_bram_in = pe_write_idx;
              pe_write_idx_in = pe_write_idx; // Select element from buffer

              @(posedge clk); #1; // Perform the write operation on the positive clock edge
           end

         // Disable C BRAM write signals after writing all buffered elements
         en_c_bram_in = 0;
         we_c_bram_in = 0;
         #10; // Wait a bit before finishing

         $display("Matrix multiplication sequence complete.");
         #20; // Wait for everything to settle

      end
   endtask // execute_matrix_mult




   // ---------------------- //
   // Task to verify results //
   // ---------------------- //
   task verify_results;
      // No inputs/outputs needed as it compares expected_C and actual_C
      integer row_v; // Declare variables at start of task
      integer col_v; // Declare variables at start of task
      integer element_errors; // Declare variables at start of task
      real    error_percentage; // Declare variables at start of task

      begin // Start of task body
         $display("Verifying results for test case %0d...", test_case);
         element_errors = 0; // Reset error count for this test case

         // The actual_C matrix is assumed to be populated by the read_actual_c task
         // Compare the actual result with the calculated expected result
         read_en_c = 1;
         for (row_v = 0; row_v < M; row_v = row_v + 1)
           begin // Loop through rows of C
              for (col_v = 0; col_v < N; col_v = col_v + 1)
                begin // Loop through columns of C
                   read_addr_c = row_v * M + col_v;
                   @(posedge clk); #1;
                   actual_C[row_v][col_v] = dut.dout_c;
                   if (actual_C[row_v][col_v] !== expected_C[row_v][col_v])
                     begin
                        $display("Test Case %0d FAIL: C[%0d][%0d] mismatch! Actual %h, Expected %h",
                                 test_case, row_v, col_v, actual_C[row_v][col_v], expected_C[row_v][col_v]);
                        element_errors = element_errors + 1; // Increment error count
                     end // else begin
                   else
                     begin
                        $display("Test Case %0d PASS: C[%0d][%0d] = %h",
                                 test_case, row_v, col_v, dut.dout_c);
                     end // else: !if(actual_C[row_v][col_v] !== expected_C[row_v][col_v])
                   // $display("  C[%0d][%0d] matches: %h", row_v, col_v, actual_C[row_v][col_v]); // Uncomment for successful matches
                   // end
                end
           end // for (row_v = 0; row_v < M; row_v = row_v + 1)
         read_en_c = 0;

         // Update overall statistics
         total_errors = total_errors + element_errors;
         error_percentage = (element_errors * 100.0) / (M * N);

         // Report test case result
         if (element_errors == 0)
           begin
              $display("Test Case %0d PASSED.", test_case);
              pass_count = pass_count + 1;
           end
         else
           begin
              $display("Test Case %0d FAILED - %0d errors (%0.2f%%).",
                       test_case, element_errors, error_percentage);
              fail_count = fail_count + 1;
           end
         $display("--------------------------------------");

      end // task verify_results
   endtask // verify_results

   task apply_reset;
      begin
         $display("\n--- Applying Reset ---");
         clr_n = 0; // Assert reset
         #100; // Hold reset for 20 time units
         clr_n = 1; // Release reset
         #100; // Wait for reset to propagate
         $display("Reset complete.");
      end
   endtask // apply_reset



   
   // -------------------------- //
   // --- Main Initial Block --- //
   // -------------------------- //
   // This initial block contains the main test sequence flow.
   initial
     begin
        // Setup waveform dumping for debugging
        $dumpfile("datapath_tb.vcd");
        $dumpvars(0, datapath_tb2); // Dump all signals in the testbench module

        // Initialize all testbench inputs to a known state at time 0
        clk = 0;
        clr_n = 0;
        k_idx_in = 0;
        pe_write_idx_in = 0;
        en_a_brams_in = 0; // Initialize flattened ports directly
        we_a_brams_in = 0; // Initialize added signal
        addr_a_brams_in = 'b0; // Initialize flattened ports directly
        din_a_brams_in = 'b0; // Initialize added signal
        en_b_brams_in = 0; // Initialize flattened ports directly
        we_b_brams_in = 0; // Initialize added signal
        addr_b_brams_in = 'b0; // Initialize flattened ports directly
        din_b_brams_in = 'b0; // Initialize added signal
        en_c_bram_in = 0;
        we_c_bram_in = 0;
        addr_c_bram_in = 0;
        pe_start_in = 0;
        pe_valid_in_in = 0;
        pe_last_in = 0;
        pe_output_capture_en = 0;
        pe_output_buffer_reset = 0;
        read_en_c = 0;
        read_addr_c = 0;

        // Initialize test counters
        pass_count = 0;
        fail_count = 0;
        total_errors = 0;

        // Wait for initial setup time
        #100;

        // --- Apply Reset ---
        apply_reset();


        // --- Loop through all defined test cases ---
        // Loop from 0 to NUM_TEST_CASES - 1
        for (test_case = 0; test_case < NUM_TEST_CASES; test_case = test_case + 1)
          begin
             $display("\n===================================================");
             $display("Starting Test Case %0d of %0d", test_case, NUM_TEST_CASES);
             $display("===================================================");

             // 1. Read input matrices (A and B) and expected C from external files
             // This populates the testbench_A, testbench_B, and expected_C arrays.
             read_matrices_and_expected_C(test_case);

             // 2. Load the DUT's BRAMs by driving the top-level write ports
             load_dut_brams_via_top_ports();

             // 3. Verify the DUT's BRAM contents by reading from top-level read ports
             verify_bram_contents_via_top_ports();

             // 4. Simulate the datapath for this test case
             execute_matrix_mult();

             // 5. Verify the results by reading from the DUT's C BRAM
             verify_results();

             $display("===================================================");
             $display("Finished Test Case %0d", test_case);
             $display("===================================================\n");

	     #10;

          end // end test_case loop

        $display("\n--- All %0d Test Cases Finished ---", NUM_TEST_CASES);
        $display("--- Test Summary ---");
        $display("Passed: %0d", pass_count);
        $display("Failed: %0d", fail_count);
        $display("Total element errors: %0d", total_errors);
        $display("--------------------");

        $finish; // End the simulation

     end // initial begin
endmodule
