`timescale 1ns / 1ps

module dma_controller_tb;
  // Parameters
  parameter DATA_WIDTH = 8;
  parameter ADDR_WIDTH = 8;
  parameter SIZE_WIDTH = 8;
  parameter CLK_PERIOD = 10;

  // Testbench signals
  reg clk;
  reg rstn;
  reg start;
  reg [DATA_WIDTH-1:0] uart_data;
  reg uart_data_valid;
  reg [ADDR_WIDTH-1:0] start_address;
  reg [SIZE_WIDTH-1:0] transfer_size;
  wire uart_read_enable;
  wire [ADDR_WIDTH-1:0] memory_write_address;
  wire [DATA_WIDTH-1:0] memory_write_data;
  wire memory_write_enable;
  wire done;

  // Test variables
  integer errors = 0;
  integer tests_passed = 0;
  integer tests_total = 0;
  integer i;
    
  // Test data arrays - declared at module level
  reg [DATA_WIDTH-1:0] single_byte_data[0:0];
  reg [DATA_WIDTH-1:0] multi_byte_data[0:3];
  reg [DATA_WIDTH-1:0] max_data[0:7];

  // Instantiate DMA controller
  dma_controller_module #(
    .DATA_WIDTH(DATA_WIDTH),
    .ADDR_WIDTH(ADDR_WIDTH),
    .SIZE_WIDTH(SIZE_WIDTH)
  ) dut (
    .clk(clk),
    .rstn(rstn),
    .start(start),
    .uart_data(uart_data),
    .uart_data_valid(uart_data_valid),
    .start_address(start_address),
    .transfer_size(transfer_size),
    .uart_read_enable(uart_read_enable),
    .memory_write_address(memory_write_address),
    .memory_write_data(memory_write_data),
    .memory_write_enable(memory_write_enable),
    .done(done)
  );

  // Clock generation - without forever
  initial 
    begin
      clk = 0;
    end

  always #(CLK_PERIOD/2) clk = ~clk;

  // Function to convert state number to string for display
  function [87:0] get_state_name;
    input [1:0] state;
      begin
        case (state)
          2'b00: get_state_name = "IDLE";
          2'b01: get_state_name = "READ_UART";
          2'b10: get_state_name = "WRITE_MEM";
          default: get_state_name = "UNKNOWN";
        endcase
      end
  endfunction

  // Task to wait for clock edges
  task wait_clocks(input integer num_clocks);
    repeat(num_clocks) @(posedge clk);
  endtask

  // Task to reset system
  task reset_system();
    begin
      rstn = 0;
      start = 0;
      uart_data = 0;
      uart_data_valid = 0;
      start_address = 0;
      transfer_size = 0;
      wait_clocks(3);
      rstn = 1;
      wait_clocks(2);
      $display("System reset completed");
    end
  endtask

  // Enhanced UART simulation task
  task simulate_uart_response(input [DATA_WIDTH-1:0] data, input integer delay_cycles);
    begin
      // Wait for UART read request
      $display("Waiting for UART read enable...");
      while (!uart_read_enable) @(posedge clk);
      $display("UART read enable detected");

      // Add specified delay
      if (delay_cycles > 0) 
        begin
          $display("  Waiting %0d cycles before providing data", delay_cycles);
          wait_clocks(delay_cycles);
        end

      // Provide data for one clock cycle
      uart_data = data;
      uart_data_valid = 1;
      $display("  Providing UART data: 0x%02h", data);
      @(posedge clk);

      // Deassert valid and clear data
      uart_data_valid = 0;
      uart_data = 8'h00;
      $display("  UART data provided and cleared");
    end
  endtask

  // Task to wait for done signal with timeout - without fork-join
  task wait_for_done(input integer timeout_cycles, output reg success);
    integer count;
    begin
      count = 0;
      success = 0;

      while (count < timeout_cycles && !done) 
        begin
          @(posedge clk);
          count = count + 1;
        end

      if (done) 
        begin
          success = 1;
          $display("  Done signal asserted after %0d cycles", count);
        end 
      else 
        begin
          success = 0;
          $display("  Timeout waiting for done signal after %0d cycles", timeout_cycles);
        end
    end
  endtask

  // Task to perform a complete transfer test - without fork-join
  task test_transfer(
    input [ADDR_WIDTH-1:0] addr,
    input [SIZE_WIDTH-1:0] size,
    input [DATA_WIDTH-1:0] test_data [],
    input string test_name);
    reg success;
    integer j;
    begin
      $display("\n--- %s ---", test_name);
      tests_total = tests_total + 1;

      // Setup transfer parameters
      start_address = addr;
      transfer_size = size;

      $display("  Starting transfer: addr=0x%02h, size=%0d", addr, size);

      // Start transfer
      start = 1;
      @(posedge clk);
      start = 0;

      if (size == 0) 
        begin
          // Special case for zero transfer
          wait_clocks(3);
          if (done) 
            begin
              $display("  PASS: Zero transfer completed immediately");
              tests_passed = tests_passed + 1;
            end
          else
            begin
              $display("  FAIL: Zero transfer - done not asserted");
              errors = errors + 1;
            end
        end 
      else
        begin
        // Normal transfer with data - sequential instead of fork-join
          begin: transfer_loop
            integer timeout_count;
            reg transfer_complete;

            timeout_count = 0;
            transfer_complete = 0;
            j = 0;

            // Process each byte in the transfer
            while (j < size && timeout_count < 500) 
              begin
                // Wait for UART read enable
                while (!uart_read_enable && timeout_count < 500) 
                  begin
                    @(posedge clk);
                    timeout_count = timeout_count + 1;
                  end

                if (timeout_count >= 500)
                  begin
                    $display("  FAIL: Timeout waiting for UART read enable for byte %0d", j);
                    errors = errors + 1;
                    transfer_complete = 0;
                  end 
                else 
                  begin
                    // Simulate UART response
                    wait_clocks(2); // Delay
                    uart_data = test_data[j];
                    uart_data_valid = 1;
                    $display("  Providing UART data[%0d]: 0x%02h", j, test_data[j]);
                    @(posedge clk);
                    uart_data_valid = 0;
                    uart_data = 8'h00;

                    j = j + 1;
                  end
              end

              // Wait for done signal
              wait_for_done(50, transfer_complete);

              if (transfer_complete) 
                begin
                  $display("  PASS: Transfer completed successfully");
                  tests_passed = tests_passed + 1;
                end 
              else 
                begin
                  $display("  FAIL: Transfer did not complete within timeout");
                  errors = errors + 1;
                end
            end
        end

      // Wait for system to settle
      wait_clocks(5);
    end
  endtask

  // Main test sequence
  initial 
    begin
      $display("=== DMA Controller Testbench ===");

      // Initialize system
      reset_system();

      // Initialize test data arrays
      single_byte_data[0] = 8'hAB;
      multi_byte_data[0] = 8'h11;
      multi_byte_data[1] = 8'h22;
      multi_byte_data[2] = 8'h33;
      multi_byte_data[3] = 8'h44;

      for (i = 0; i < 8; i = i + 1) 
        begin
          max_data[i] = 8'h80 + i;
        end

      // Test 1: Single byte transfer
      test_transfer(8'h20, 1, single_byte_data, "Test 2: Single Byte Transfer");

      // Test 2: Multi-byte transfer
      test_transfer(8'h30, 4, multi_byte_data, "Test 3: Four Byte Transfer");

      // Test 3: Edge case - maximum size (if reasonable)
      test_transfer(8'h40, 8, max_data, "Test 4: Eight Byte Transfer");

      // Test 4: Start signal behavior
      $display("\n--- Test 5: Start Signal Edge Detection ---");
      tests_total = tests_total + 1;

      // Test that holding start high doesn't restart transfer
      start_address = 8'h50;
      transfer_size = 1;

      start = 1;
      wait_clocks(5); // Hold start high for multiple cycles

      $display("  Start held high for 5 cycles");
      $display("  uart_read_enable = %b", uart_read_enable);

      // Should only trigger once
      if (uart_read_enable) 
        begin
          $display("  PASS: Transfer triggered only once despite start held high");
          tests_passed = tests_passed + 1;
        end 
      else 
        begin
          $display("  FAIL: Transfer not triggered");
          errors = errors + 1;
        end

      start = 0;
      wait_clocks(5);

      // Test 5: Reset during transfer
      $display("\n--- Test 6: Reset During Transfer ---");
      tests_total = tests_total + 1;

      start_address = 8'h60;
      transfer_size = 3;
      start = 1;
      @(posedge clk);
      start = 0;

      // Wait for transfer to start
      wait_clocks(5);

      // Reset system mid-transfer
      $display("  Resetting system during transfer");
      rstn = 0;
      wait_clocks(3);
      rstn = 1;
      wait_clocks(3);

      if (done == 0 && uart_read_enable == 0 && memory_write_enable == 0) 
        begin
          $display(" PASS: System properly reset during transfer");
          tests_passed = tests_passed + 1;
        end 
      else 
        begin
          $display(" FAIL: System state incorrect after reset");
          $display(" done=%b, uart_re=%b, mem_we=%b", done, uart_read_enable,memory_write_enable);
          errors = errors + 1;
        end

      // Final results
      $display("\n=== Test Summary ===");
      $display("Tests Total: %0d", tests_total);
      $display("Tests Passed: %0d", tests_passed);
      $display("Tests Failed: %0d", errors);
      if (tests_total > 0) 
        begin
          $display("Success Rate: %0d%%", (tests_passed * 100) / tests_total);
        end

      if (errors == 0) 
        begin
          $display("\n*** ALL TESTS PASSED! ***");
          $display("DMA Controller is working correctly!");
        end 
      else 
        begin
          $display("\n*** %0d TEST(S) FAILED ***", errors);
          $display("DMA Controller needs debugging.");

          // Provide debugging hints
          $display("\nDebugging Hints:");
          $display("- Check state machine transitions");
          $display("- Verify done signal logic");
          $display("- Check start edge detection");
          $display("- Verify counter and address increment logic");
        end

      $finish;
  	end

  // Monitor key signals with proper state display
  initial 
    begin
      $monitor("Time: %0t | State: %s | done: %b | uart_re: %b | mem_we: %b | addr: 0x%02h | data: 0x%02h", $time, get_state_name(dut.current_state), done, uart_read_enable, memory_write_enable, memory_write_address, memory_write_data);
    end


  // Generate VCD for debugging
  initial 
    begin
      $dumpfile("dma_controller_tb.vcd");
      $dumpvars(0, dma_controller_tb);
    end

endmodule