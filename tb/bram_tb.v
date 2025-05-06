`timescale 1ns / 1ps

module bram_tb;

   // Parameters
   parameter ADDR_WIDTH = 4;
   parameter DATA_WIDTH = 32;
   localparam DEPTH = 1 << ADDR_WIDTH;

   // Signals
   reg        clk;

   // Port A
   reg        en_a, we_a;
   reg [ADDR_WIDTH-1:0] addr_a;
   reg [DATA_WIDTH-1:0] din_a;
   wire [DATA_WIDTH-1:0] dout_a;

   // Port B
   reg                   en_b, we_b;
   reg [ADDR_WIDTH-1:0]  addr_b;
   reg [DATA_WIDTH-1:0]  din_b;
   wire [DATA_WIDTH-1:0] dout_b;

   // Instantiate DUT
   bram #(
          .ADDR_WIDTH(ADDR_WIDTH),
          .DATA_WIDTH(DATA_WIDTH)
          ) dut (
                 .clk(clk),
                 .en_a(en_a),
                 .we_a(we_a),
                 .addr_a(addr_a),
                 .din_a(din_a),
                 .dout_a(dout_a),
                 .en_b(en_b),
                 .we_b(we_b),
                 .addr_b(addr_b),
                 .din_b(din_b),
                 .dout_b(dout_b)
                 );

   // Clock generation
   always #5 clk = ~clk;

   // Tasks
   task write;
      input port;
      input [ADDR_WIDTH-1:0] addr;
      input [DATA_WIDTH-1:0] data;
      begin
         @(posedge clk);
         if (port == 0) begin
            en_a <= 1; we_a <= 1; addr_a <= addr; din_a <= data;
            $display("[A] WRITE: at %t addr=%0d data=%h", $time, addr, data);
         end else begin
            en_b <= 1; we_b <= 1; addr_b <= addr; din_b <= data;
            $display("[B] WRITE: at %t addr=%0d data=%h", $time, addr, data);
         end
         #1;
         @(posedge clk);
         if (port == 0) begin
            en_a <= 0; we_a <= 0;
         end else begin
            en_b <= 0; we_b <= 0;
         end
      end
   endtask // write

   task read;
      input port;
      input [ADDR_WIDTH-1:0] addr;
      begin
         @(posedge clk);
         if (port == 0) begin
            en_a <= 1; we_a <= 0; addr_a <= addr;
         end else begin
            en_b <= 1; we_b <= 0; addr_b <= addr;
         end
         #1;
         @(posedge clk);
         if (port == 0)
           begin
              $display("[A] READ: at %t addr=%0d dout_a=%h", $time, addr, dout_a);
              en_a <= 0;
           end else begin
              $display("[B] READ: at %t addr=%0d dout_b=%h", $time, addr, dout_b);
              en_b <= 0;
           end
      end
   endtask // read


   // Test Sequence
   initial
     begin
        // Initial state
        clk = 0;
        en_a = 0; we_a = 0; addr_a = 0; din_a = 0;
        en_b = 0; we_b = 0; addr_b = 0; din_b = 0;

        #10;

        // Test 1: Port A write and read

        write(0, 4, 32'hAAAA_0004);
        read(0, 4);

        // Test 2: Port B write and read
        write(1, 7, 32'hBBBB_0007);
        read(1, 7);

        // Test 3: Read from different address (uninitialized)
        read(0, 2); // Should be undefined or X
        read(1, 3); // Should be undefined or X

        // Test 4: Simultaneous write A and read B (different addresses)
        fork
           begin
              write(0, 8, 32'hFACE_0008);
              read(1, 4); // Previously written by A
           end
        join

        // Test 5: Overwrite and confirm NO CHANGE behavior
        fork
           begin
              write(0, 4, 32'h1234_5678); // Overwrite address 4
              read(0, 4); // Should update now
           end
        join

        // Test 6: Simultaneous write A and write B
        fork
           begin
              write(0, 9, 32'h1234_1234);
              write(1, 2, 32'h4321_4312);
           end
        join

        // Test 7: Simultaneous read A and read B
        fork
           begin
              read(0, 9);
              read(1, 2);
           end
        join

        // Test 9: Simultaneous write B and read A
        fork
           begin
              write(1, 4'ha, 32'hacbd_1234);
              read(0, 8);
           end
        join

        #20;
        $display("Test completed.");
        $finish;
     end

endmodule // bram_tb
