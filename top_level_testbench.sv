//// SEC 1 , TALEEN 1211305 MIASSAR 1210519
// Comprehensive TestBench WORK AS CPU

module dma_system_tb;
  // Parameters
  parameter DATA_WIDTH = 8;
  parameter ADDR_WIDTH = 8;
  parameter SIZE_WIDTH = 8;
  parameter MEMORY_DEPTH = 256;
  parameter UART_BUFFER_SIZE = 16;
  parameter CLK_PERIOD = 10;
    
  // Testbench signals   
  reg clk;
  reg rstn;
  reg start;
  reg [ADDR_WIDTH-1:0] start_address;
  reg [SIZE_WIDTH-1:0] transfer_size;
  wire done;
  reg [ADDR_WIDTH-1:0] mem_read_address;
  reg mem_read_enable;
  wire [DATA_WIDTH-1:0] mem_read_data;
  reg uart_reset_ptr;
    
  // Test control variables
  integer test_count;
  integer pass_count;
  integer fail_count;
    
  // instance of top module
  dma_system_top #(
    .DATA_WIDTH(DATA_WIDTH),
    .ADDR_WIDTH(ADDR_WIDTH),
    .SIZE_WIDTH(SIZE_WIDTH),
    .MEMORY_DEPTH(MEMORY_DEPTH),
    .UART_BUFFER_SIZE(UART_BUFFER_SIZE))
  top_inst (
    .clk(clk),
    .rstn(rstn),
    .start(start),
    .start_address(start_address),
    .transfer_size(transfer_size),
    .done(done),
    .mem_read_address(mem_read_address),
    .mem_read_enable(mem_read_enable),
    .mem_read_data(mem_read_data),
    .uart_reset_ptr(uart_reset_ptr));
  
  // Waveform dump
  initial 
    begin
      $dumpfile("dma_system.vcd");
      $dumpvars(0, dma_system_tb);
    end
    
  // Clock generation
  initial 
    begin
      clk = 0;
    end

  always #(CLK_PERIOD/2) clk = ~clk;
    
  initial 
    begin
      // Initialize test variables
      test_count = 0;
      pass_count = 0;
      fail_count = 0;
        
      // Initialize signals
      rstn = 0;
      start = 0;
      start_address = 0;
      transfer_size = 0;
      mem_read_address = 0;
      mem_read_enable = 0;
      uart_reset_ptr = 0;
      
      $display("  Advanced digital system project sec 1 dr.Ayman Hroub  ");
      $display("  DMA Controller System TestBench Started  ");
      $display("Time: %0t", $time);
      // Reset sequence
      #(CLK_PERIOD * 2);
      rstn = 1;
      #(CLK_PERIOD * 2);
        
      //test 1 Basic transfer 4 bytes 
      reset_uart_pointer();
      run_test("Basic DMA Transfer of 4 bytes size and start at address 10: ", 8'h10, 8'd4);
        
      //test 2 Single byte transfer 
      reset_uart_pointer();
      run_test("Single Byte Transfer", 8'h20, 8'd1);
        
      // Test 3 Maximum buffer transfer
      reset_uart_pointer();
      run_test("Maximum Buffer Transfer 16 bytes start at address 40: ", 8'h40, 8'd16);
        
      // Test 4 Reset during transfer
      test_reset_during_transfer();
        
      // summary of tests
      $display("\n Test Summary ");
      $display("Total Tests: %0d", test_count);
      $display("Passed: %0d", pass_count);
      $display("Failed: %0d", fail_count);
      $display("Success Rate: %.1f%%", (pass_count * 100.0) / test_count);
      $display("\n  TestBench Completed  ");
      $finish;
    end
  // Task to reset UART pointer
  task reset_uart_pointer();
    begin
      @(posedge clk);
      uart_reset_ptr = 1;
      @(posedge clk);
      uart_reset_ptr = 0;
      @(posedge clk);
    end
    endtask
    
    // Task to run a single DMA test
    task run_test(
      input string test_name,
      input [ADDR_WIDTH-1:0] addr,
      input [SIZE_WIDTH-1:0] size);
      begin
        test_count = test_count + 1;
        $display("\n ---Test %0d: %s--- ", test_count, test_name);
        $display("Start Address: 0x%02X, Transfer Size: %0d", addr, size);
            
        // Start DMA transfer
        @(posedge clk);
        start_address = addr;
        transfer_size = size;
        start = 1;
            
        @(posedge clk);
        start = 0;
            
        // Wait for completion or timeout
        begin: wait_for_completion
          integer timeout_counter;
          timeout_counter = 0;
                
          while (!done && timeout_counter < 200) 
            begin
              @(posedge clk);
              timeout_counter = timeout_counter + 1;
            end
          if (done)
            begin
              $display("DMA transfer completed at time %0t", $time);
            end 
          else 
            begin
              $display("ERROR: DMA transfer timeout!");
            end
          end
   
        // Wait for done to be stable
        #(CLK_PERIOD * 2);
            
        // Verify transfer if size > 0
        if (size > 0) 
          begin
                verify_memory_contents(addr, size);
          end 
        else 
          begin
            $display("Zero size transfer - checking done signal");
            if (done) 
              begin
                $display("PASS: Zero transfer handled correctly");
                pass_count = pass_count + 1;
              end 
            else 
              begin
                $display("FAIL: Done signal not asserted for zero transfer");
                fail_count = fail_count + 1;
              end
          end
            
          // Wait a few cycles before next test
          repeat(5) @(posedge clk);
      end
    endtask
    
    // Task to verify memory contents
    task verify_memory_contents(
        input [ADDR_WIDTH-1:0] base_addr,
        input [SIZE_WIDTH-1:0] size
    );
      reg [DATA_WIDTH-1:0] expected_data [0:15];
      reg [DATA_WIDTH-1:0] actual_data;
      integer i;
      integer errors;
      
      begin
        // Expected UART data
        expected_data[0] = 8'h41; // 'A'
        expected_data[1] = 8'h64; // 'd'
        expected_data[2] = 8'h76; // 'v
        expected_data[3] = 8'h61; // 'a'
        expected_data[4] = 8'h6E; // 'n'
        expected_data[5] = 8'h63; // 'c'
        expected_data[6] = 8'h65; // 'e'
        expected_data[7] = 8'h64; // 'd'
        expected_data[8] = 8'h20; // ' '
        expected_data[9] = 8'h44;  // 'D'
        expected_data[10] = 8'h69; // 'i'
        expected_data[11] = 8'h67; // 'g'
        expected_data[12] = 8'h69; // 'i'
        expected_data[13] = 8'h74; // 't'
        expected_data[14] = 8'h61; //  'a'
        expected_data[15] = 8'h6C; //  'l'
        
        errors = 0;
        $display("Verifying memory contents:");
            
        for (i = 0; i < size; i = i + 1) 
          begin
            // Read from memory
            @(posedge clk);
            mem_read_address = base_addr + i;
            mem_read_enable = 1;                
            @(posedge clk);
            @(posedge clk); // Extra cycle for memory read
            mem_read_enable = 0;
            actual_data = mem_read_data;
                
            // Compare with expected
            if (i < 16)
              begin
                if (actual_data === expected_data[i])
                  begin
                    $display(" Address 0x%02X: 0x%02X (Expected: 0x%02X) ✓",base_addr + i, actual_data, expected_data[i]);
                    end 
                else 
                  begin
                    $display(" Address 0x%02X: 0x%02X (Expected: 0x%02X) ✗",base_addr + i, actual_data, expected_data[i]);
                        errors = errors + 1;
                  end
              end 
            else 
              begin
                $display("  Address 0x%02X: 0x%02X (beyond expected data)", base_addr + i, actual_data);
              end
          end
        if (errors == 0)
          begin
            $display("PASS: All memory contents verified successfully");
            pass_count = pass_count + 1;
          end 
        else 
          begin
            $display("FAIL: %0d verification errors found", errors);
            fail_count = fail_count + 1;
          end
      end
    endtask
    
    // Task to test reset during transfer
    task test_reset_during_transfer();
        begin
          test_count = test_count + 1;
          $display("\n--- Test %0d: Reset During Transfer ---", test_count);
          reset_uart_pointer();
            
          // Start a transfer
          @(posedge clk);
          start_address = 8'h60;
          transfer_size = 8'd8;
          start = 1; 
          @(posedge clk);
          start = 0;
            
          // Wait a few cycles then reset
          repeat(5) @(posedge clk);
          rstn = 0;
          repeat(2) @(posedge clk);
          rstn = 1;
          repeat(3) @(posedge clk);
            
          // Check if system is back to idle
          if (!done && !top_inst.uart_read_enable && !top_inst.memory_write_enable) 
            begin
              $display("PASS: Reset during transfer handled correctly");
              pass_count = pass_count + 1;
            end 
          else
            begin
              $display("FAIL: Reset during transfer not handled properly");
              $display("  done=%b, uart_re=%b, mem_we=%b", done, top_inst.uart_read_enable, top_inst.memory_write_enable);
              fail_count = fail_count + 1;
            end
        end
    endtask
    
    // Monitor important signals
    initial 
      begin
        $monitor("Time: %0t | State: %s | Done: %b | UART_RE: %b | UART_Valid: %b | MEM_WE: %b | Address: 0x%02X | Data: 0x%02X", $time,  top_inst.dma_inst.current_state, done, top_inst.uart_read_enable, top_inst.uart_data_valid, top_inst.memory_write_enable, top_inst.memory_write_address, top_inst.memory_write_data);
      end   
endmodule