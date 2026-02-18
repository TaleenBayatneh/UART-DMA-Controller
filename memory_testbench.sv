`timescale 1ns / 1ps

module memory_tb;
  //parameters
  parameter DATA_WIDTH = 8;
  parameter ADDR_WIDTH = 8;
  parameter MEMORY_DEPTH = 256;
  parameter CLK_PERIOD = 10; //10ns clock period 100MHz
  reg clk;
  reg rstn;
  reg [ADDR_WIDTH-1:0] write_address;
  reg [DATA_WIDTH-1:0] data_in;
  reg we;
  reg [ADDR_WIDTH-1:0] read_address;
  wire [DATA_WIDTH-1:0] data_out;
  reg [DATA_WIDTH-1:0] prev_data_out;
  reg re;
  reg [DATA_WIDTH-1:0] expected_data;
  integer i, errors, tests_passed, tests_total;

  //instantiate the memory module
  memory_module #(
    .DATA_WIDTH(DATA_WIDTH),
    .ADDR_WIDTH(ADDR_WIDTH),
    .MEMORY_DEPTH(MEMORY_DEPTH)
  ) dut (
    .clk(clk),
    .rstn(rstn),
    .write_address(write_address),
    .data_in(data_in),
    .we(we),
    .read_address(read_address),
    .data_out(data_out),
    .re(re));

  //clock generation
  initial 
    begin
      clk = 0;
      for(int i = 0; i < 20000; i++) 
        begin  // 10000 complete cycles
          #(CLK_PERIOD/2) clk = ~clk;
        end
    end

  //test stimulus
  initial 
    begin  
      rstn = 0;
      write_address = 0;
      data_in = 0;
      we = 0;
      read_address = 0;
      re = 0;
      errors = 0;
      tests_passed = 0;
      tests_total = 0;
      $display("---------------------------------------------");
      $display(" Memory Module Testbench Started ");
      $display("Time: %0t", $time);
      
      //wait for a few clock cycles
      repeat(3) @(posedge clk);

      //test 1: Reset behavior
      $display("---------------------------------------------");
      $display("\n Test 1: Reset Behavior ");
      tests_total = tests_total + 1;
      //apply reset
      rstn = 0;
      @(posedge clk);
        
      //try to read from various addresses during reset
      re = 1;
      read_address = 8'h00;
      @(posedge clk);
      if (data_out == 8'h00) 
        begin
          $display("PASS: Reset - Address 0x00 reads 0x00");
          tests_passed = tests_passed + 1;

        end 
      else 
        begin
          $display("FAIL: Reset - Address 0x00 expected 0x00, got 0x%02h", data_out);
          errors = errors + 1;
        end

      //test 2: Release reset and verify memory is cleared
      $display("\n--- Test 2: Post-Reset Memory State ---");
      rstn = 1;
      @(posedge clk);
        
      //check multiple addresses to ensure they're cleared
      for (i = 0; i < 10; i = i + 1)
        begin
          tests_total = tests_total + 1;
          read_address = i;
          re = 1;
          @(posedge clk);
          if (data_out == 8'h00) 
            begin
              $display("PASS: Address 0x%02h cleared to 0x00", i);
              tests_passed = tests_passed + 1;
            end
          else 
            begin
              $display("FAIL: Address 0x%02h expected 0x00, got 0x%02h", i, data_out);
         	  errors = errors + 1;
       		end
          end
      
      //test 3: Basic write operation
      $display("---------------------------------------------");
      $display("\n Test 3: Basic Write Operations ");
      re = 0; //disable read for write test

      //write test data to various addresses
      for (i = 0; i < 5; i = i + 1) 
        begin
          tests_total = tests_total + 1;
          write_address = i;
          data_in = 8'hA0 + i; //test pattern: A0, A1, A2, A3, A4
          we = 1;
          @(posedge clk);
          we = 0;
          @(posedge clk);
          $display("Written 0x%02h to address 0x%02h", data_in, write_address);
           @(posedge clk);
          if (data_in == (8'hA0 + i))
            begin
              $display("PASS: Address 0x%02h correctly stored 0x%02h", i, data_in);
              tests_passed = tests_passed + 1;
            end
          else
            begin
              $display("FAIL: Address 0x%02h expected 0x%02h, got 0x%02h",   i, (8'hA0 + i), data_in);
              errors = errors + 1;
            end
        end

      //test 4: Basic read operation
      $display("---------------------------------------------");
      $display("\n Test 4: Basic Read Operations ");
      we = 0; //ensure write is disabled

      // Read back the test data
      for (i = 0; i < 5; i = i + 1) 
        begin
          tests_total = tests_total + 1;
          expected_data = 8'hA0 + i;
          read_address = i;
          re = 1;

          
          @(posedge clk);
          if (data_out == expected_data) 
            begin
              $display("PASS: Address 0x%02h read 0x%02h (expected 0x%02h)", read_address, data_out, expected_data);
              tests_passed = tests_passed + 1;

            end 
          else 
            begin
              $display("FAIL: Address 0x%02h read 0x%02h (expected 0x%02h)",  read_address, data_out, expected_data);
              errors = errors + 1;
            end
        end

      //test 5: Read without enable
      $display("---------------------------------------------");
      $display("\n Test 5: Read Without Enable ");
      tests_total = tests_total + 1;
      prev_data_out = data_out;
      re = 0; //disable read
      read_address = 8'h00;
      @(posedge clk);
      //the data_out should retain previous value when re=0
      $display("Read disabled - data_out = 0x%02h", data_out);
      @(posedge clk);
      if (data_out == prev_data_out)
        begin
          $display("PASS: Read disabled, data_out retained value 0x%02h", data_out);
          tests_passed = tests_passed + 1;
        end
      else
        begin
          $display("FAIL: Read disabled, expected data_out = 0x%02h, got 0x%02h", prev_data_out, data_out);
          errors = errors + 1;
        end

      //test 6: Write without enable
      $display("---------------------------------------------");
      $display("\n Test 6: Write Without Enable ");
      tests_total = tests_total + 1;
      write_address = 8'h10;
      data_in = 8'hFF;
      we = 0; //write disabled
      @(posedge clk);

      //verify data wasn't written
      read_address = 8'h10;
      re = 1;
      @(posedge clk);
      if (data_out == 8'h00) 
        begin 
          $display("PASS: Write disabled - no data written to address 0x10");
          tests_passed = tests_passed + 1;
        end 
      else 
        begin
          $display("FAIL: Write disabled - unexpected data 0x%02h at address 0x10", data_out);
          errors = errors + 1;
        end

      //test 7: Simultaneous read and write (different addresses)
      $display("---------------------------------------------");
      $display("\n Test 7: Simultaneous Read/Write Different Addresses ");
      tests_total = tests_total + 1;

      //set up simultaneous operations
      write_address = 8'h20;
      data_in = 8'h55;
      we = 1;
      read_address = 8'h00; //read from previously written location
      re = 1;
      expected_data = 8'hA0; //should read A0 from address 0

      @(posedge clk);

      if (data_out == expected_data) 
        begin
          $display("PASS: Simultaneous R/W - Read correct data 0x%02h from address 0x00", data_out);
          tests_passed = tests_passed + 1;

        end
      else 
        begin
          $display("FAIL: Simultaneous R/W - Read 0x%02h from address 0x00, expected 0x%02h", data_out, expected_data);
          errors = errors + 1;
        end

      //verify the write occurred
      we = 0;
      read_address = 8'h20;
      @(posedge clk);
      tests_total = tests_total + 1;
      if (data_out == 8'h55) 
        begin
          $display("PASS: Simultaneous R/W - Write successful, read 0x%02h from address 0x20", data_out);
          tests_passed = tests_passed + 1;
        end
      else 
        begin
      	  $display("FAIL: Simultaneous R/W - Write failed, read 0x%02h from address 0x20, expected 0x55", data_out);
          errors = errors + 1;
        end

      //test 8: Address boundary testing
      $display("---------------------------------------------");
      $display("\n Test 8: Address Boundary Testing ");

      //test maximum address
      tests_total = tests_total + 1;
      write_address = MEMORY_DEPTH - 1; // 255 for 256-depth memory
      data_in = 8'hBB;
      we = 1;
      re = 0;
      @(posedge clk);

      //read back from max address
      we = 0;
      re = 1;
      read_address = MEMORY_DEPTH - 1;
      @(posedge clk);
      if (data_out == 8'hBB) 
        begin
          $display("PASS: Boundary test - Max address (0x%02h) write/read successful", MEMORY_DEPTH-1);
          tests_passed = tests_passed + 1;
        end
      else 
        begin
          $display("FAIL: Boundary test - Max address read 0x%02h, expected 0xBB", data_out);
          errors = errors + 1;
        end

      //test 9: Overwrite existing data
      $display("---------------------------------------------");
      $display("\n Test 9: Data Overwrite Test ");
      tests_total = tests_total + 1;

      //overwrite address 0
      write_address = 8'h00;
      data_in = 8'hCC;
      we = 1;
      re = 0;
      @(posedge clk);

      // Read back overwritten data
      we = 0;
      re = 1;
      read_address = 8'h00;
      @(posedge clk);
      if (data_out == 8'hCC) 
        begin
          $display("PASS: Overwrite test - Successfully overwrote data at address 0x00");
          tests_passed = tests_passed + 1;
        end
      else 
        begin
          $display("FAIL: Overwrite test - Read 0x%02h from address 0x00, expected 0xCC", data_out);
          errors = errors + 1;
        end

      //test 10: Reset during operation
      $display("---------------------------------------------");
      $display("\n Test 10: Reset During Operation ");
      tests_total = tests_total + 1;

      //start a write operation
      write_address = 8'h30;
      data_in = 8'hDD;
      we = 1;

      //assert reset in the middle
      @(posedge clk);
      rstn = 0;
      @(posedge clk);

      //release reset and check if memory was cleared
      rstn = 1;
      we = 0;
      re = 1;
      read_address = 8'h30;
      @(posedge clk);
      if (data_out == 8'h00) 
        begin
          $display("PASS: Reset during operation - Memory cleared properly");
          tests_passed = tests_passed + 1;
        end
      else 
        begin
          $display("FAIL: Reset during operation - Expected 0x00, got 0x%02h", data_out);
          errors = errors + 1;
        end

      //final results
      $display("---------------------------------------------");
      $display("\n Test Results ");
      $display("Total Tests: %0d", tests_total);
      $display("Tests Passed: %0d", tests_passed);
      $display("Tests Failed: %0d", errors);
      $display("Success Rate: %0.1f%%", (tests_passed * 100.0) / tests_total);
      $display("---------------------------------------------");

      if (errors == 0) 
        begin
          $display(" ALL TESTS PASSED! ");
        end 
      else 
        begin
          $display(" SOME TESTS FAILED ");
        end
      
      $display("\n=== Memory Module Testbench Completed ===");
      $finish;

    end // end of initial of tests

  

  // monitor signals for debugging
  initial 
    begin
      $monitor("Time: %0t | clk: %b | rstn: %b | we: %b | re: %b | wr_addr: 0x%02h | data_in: 0x%02h | rd_addr: 0x%02h | data_out: 0x%02h",  $time, clk, rstn, we, re, write_address, data_in, read_address, data_out);
    end
  // Generate VCD file for waveform viewing
  initial 
    begin
      $dumpfile("memory_tb.vcd");
      $dumpvars(0, memory_tb);
    end

endmodule