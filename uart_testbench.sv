// sec1 , miassar 1210519 and taleen 1211305
//test bench for UART module
////////

`timescale 1ns / 1ps

module uart_tb;
  ///parameters
  parameter BUFFER_SIZE = 16;
  parameter DATA_WIDTH = 8;
  parameter CLK_PERIOD = 10; //10ns clock period 100MHz
  
  reg clk;
  reg rstn;
  reg re;
  wire [DATA_WIDTH-1:0] data_out;
  wire data_valid;
   
  integer i;
  reg [DATA_WIDTH-1:0] expected_data [0:BUFFER_SIZE-1];
  reg [DATA_WIDTH-1:0] received_data [0:BUFFER_SIZE-1];
  integer read_count;
  reg [DATA_WIDTH-1:0] temp_data;
  reg temp_valid;
    
  
  //instantiate the UART module

  uart_module #(
    .BUFFER_SIZE(BUFFER_SIZE),
    .DATA_WIDTH(DATA_WIDTH))
  dut (
    .clk(clk),
    .rstn(rstn),
    .re(re),
    .data_out(data_out),
    .data_valid(data_valid));
    

  //clock generation
  initial 
    begin
      clk = 0;
      for(int i = 0; i < 20000; i++) 
        begin //10000 cycles
          #(CLK_PERIOD/2) clk = ~clk;
        end
	end
    

  //initialize expected data
  initial
    begin
      expected_data[0] = 8'h41; //'A'
      expected_data[1] = 8'h64; //'d'
      expected_data[2] = 8'h76; //'v
      expected_data[3] = 8'h61; //'a'
      expected_data[4] = 8'h6E; //'n'
      expected_data[5] = 8'h63; //'c'
      expected_data[6] = 8'h65; //'e'
      expected_data[7] = 8'h64; //'d'
      expected_data[8] = 8'h20; //' '
      expected_data[9] = 8'h44;  //'D'
      expected_data[10] = 8'h69; //'i'
      expected_data[11] = 8'h67; //'g'
      expected_data[12] = 8'h69; //'i'
      expected_data[13] = 8'h74; //'t'
      expected_data[14] = 8'h61; //'a'
      expected_data[15] = 8'h6C; //'l'
    end
    

  //task to wait for clock edge
  task wait_clock_edge(input integer num_clocks);
    
    repeat(num_clocks) @(posedge clk);
  
  endtask
    
  //task to perform a single read operation and capture data
  task read_uart_data(output reg [DATA_WIDTH-1:0] captured_data, output reg captured_valid);
    begin
      re = 1;
      wait_clock_edge(1);
      // Capture data while data_valid is high
      captured_data = data_out;
      captured_valid = data_valid;
      re = 0;
      wait_clock_edge(1);     
    end
  endtask
    
  //task to do reset
  task reset_system();
    begin
      rstn = 0;
      re = 0;
      wait_clock_edge(2);
      rstn = 1;
      wait_clock_edge(2);
      $display("system reset at time %0t", $time);
        
    end
  endtask

  //main test sequence
  initial 
    begin
      
      read_count = 0;
      $display("---------------------------------------------");  
      $display("UART Module Testbench Started:");
      $display("Time: %0t", $time);
      $display("---------------------------------------------");
      
      //test 1: Reset test
      $display("---------------------------------------------");
      $display("\n Test 1: check reset working: ");
      reset_system();
        
      //verify reset state
      if (data_out == 0 && data_valid == 0)
        begin
          $display("PASS: Reset state verified - data_out=0x%02h , data_valid=%b", data_out, data_valid); 
        end
      
      else 
        begin
          $display("FAIL: Reset state incorrect - data_out=0x%02h, data_valid=%b", data_out, data_valid);
        end
        
      //test 2: Single read operation
      $display("---------------------------------------------");
      $display("\n Test 2: Single Read Operation ");
      read_uart_data(temp_data, temp_valid);
        
      if (temp_valid == 1 && temp_data == expected_data[0]) 
        begin
          $display("PASS: First read - data_out=0x%02h ('%c'), data_valid=%b",temp_data, temp_data, temp_valid);
      
        end 
      
      else 
        begin
          $display("FAIL: First read - expected=0x%02h, got=0x%02h, data_valid=%b", expected_data[0], temp_data, temp_valid);
      
        end
        
      //test 3: Sequential read of all buffer data
      $display("---------------------------------------------");
      $display("\n Test 3: Sequential Buffer Read ");
        
      reset_system();//reset to start from beginning, it is important after every test

        
      for (i = 0; i < BUFFER_SIZE; i++)
        begin
          read_uart_data(temp_data, temp_valid);
          if (temp_valid == 1) 
            begin
              received_data[read_count] = temp_data;
              if (temp_data == expected_data[i]) 
                begin
                  $display("PASS: Read %0d - data=0x%02h ('%c'), expected=0x%02h ('%c')",  i, temp_data, (temp_data >= 32 && temp_data <= 126) ? temp_data : "?", expected_data[i],(expected_data[i] >= 32 && expected_data[i] <= 126) ? expected_data[i] : "?");
                end
             
              else 
                begin
                  $display("FAIL: Read %0d - data=0x%02h, expected=0x%02h",  i, temp_data, expected_data[i]);
                end
          
              read_count++;
            end
          else 
            begin
              $display("FAIL: Read %0d - data_valid not asserted", i);
            end
        end
        
      
        
      //test 4: Multiple read enable pulses
      $display("---------------------------------------------");
      $display("\n Test 4: Multiple Read Enable Pulses ");
      reset_system();
        
      //send multiple consecutive read enable pulses
      re = 1;
      wait_clock_edge(1);
      //capture data on first rising edge
      temp_data = data_out;
      temp_valid = data_valid;
      wait_clock_edge(2); //to hold re high for 2 cycles
      re = 0;
      wait_clock_edge(2);
        
      //should only get one data output despite multiple cycles with re high
      if (temp_valid == 1 && temp_data == expected_data[0]) 
        begin
          $display("PASS: Multiple RE pulses - only one data output, data=0x%02h", temp_data);
        end 
      else 
        begin
          $display("FAIL: Multiple RE pulses - data=0x%02h, data_valid=%b", temp_data, temp_valid);
        end
        
      //test 5: Edge detection test
      $display("---------------------------------------------"); 
      $display("\n Test 5: Edge Detection Test ");
      reset_system();
        
      //test that only rising edge triggers read
      re = 1;
      wait_clock_edge(1);
      //keep re high, no new data should be output
      wait_clock_edge(2);
      re = 0;
      wait_clock_edge(1);
        
      //now test another rising edge
      re = 1;
      wait_clock_edge(1);
      temp_data = data_out;  //capture the second read data
      re = 0;
      wait_clock_edge(1);
        
      if (temp_data == expected_data[1]) 
        begin
          $display("PASS: Edge detection - second read shows next data: 0x%02h", temp_data);
        end
      else 
        begin
          $display("FAIL: Edge detection - expected=0x%02h, got=0x%02h", expected_data[1], temp_data);
        end
        
      //test 6: Reset pointer functionality
      $display("---------------------------------------------");
      $display("\n Test 6: Reset Pointer Test ");
        
      //read a few bytes first
      reset_system();
      for (i = 0; i < 3; i++) 
        begin
          read_uart_data(temp_data, temp_valid);
        end
        
      $display("Read 3 bytes, last data: 0x%02h", temp_data);
        
      //reset pointer using the task
      dut.reset_pointer();
      wait_clock_edge(1);
       
      //next read should give first byte again
      read_uart_data(temp_data, temp_valid);
        
      if (temp_data == expected_data[0])
        begin
          $display("PASS: Reset pointer - back to first data: 0x%02h", temp_data);
        end
      else 
        begin
          $display("FAIL: Reset pointer - expected=0x%02h, got=0x%02h", expected_data[0], temp_data);
        end
        
      //test 7: data_valid signal behavior
      $display("---------------------------------------------");
      $display("\n Test 7: Data Valid Signal Behavior ");
      reset_system();
        
      //check data_valid is low initially
      if (data_valid == 0) 
        begin
          $display("PASS: data_valid initially low");
        end
      else 
        begin
          $display("FAIL: data_valid should be low initially");
        end
        
      //read and check data_valid timing
      re = 1;
      wait_clock_edge(1);
        
      if (data_valid == 1) 
        begin
          $display("PASS: data_valid asserted after rising edge of re");
    
        end 
      else
        begin
          $display("FAIL: data_valid not asserted after rising edge");
        end
        
      re = 0;
      wait_clock_edge(1);
        
      if (data_valid == 0) 
        begin
          $display("PASS: data_valid deasserted when re goes low");
        end
      else 
        begin
          $display("FAIL: data_valid should be deasserted when re goes low");
        end
        
      //summary
      $display("---------------------------------------------");
      $display("\n Test Summary: ");
      $display("UART Module testbench completed at time %0t", $time);
      $display("Total bytes read successfully: %0d/%0d", read_count, BUFFER_SIZE);
      $display("---------------------------------------------");
        
      //display the complete message that was read
      $display("---------------------------------------------");
      $display("\nComplete message read from UART:");
      $write("\"");
      for (i = 0; i < read_count; i++) 
        begin
          if (received_data[i] >= 32 && received_data[i] <= 126) 
            begin
              $write("%c", received_data[i]);
            end 
          else
            begin
              $write("\\x%02h", received_data[i]);
            end
        end
      
      $display("\n---------------------------------------------");  
      $display("\n UART Module Testbench Finished ");
      $finish;

    end // end of initial begin of main test sequence

    //monitor for debugging
    initial 
      begin
        $monitor("Time: %0t | clk: %b | rstn: %b | re: %b | data_out: 0x%02h | data_valid: %b",  $time, clk, rstn, re, data_out, data_valid);
      end
    
    // Generate VCD file for waveform viewing
    initial 
      begin
        $dumpfile("uart_tb.vcd");
        $dumpvars(0, uart_tb);
      end
endmodule