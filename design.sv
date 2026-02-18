// uart module 
// sec1 , miassar 1210519 and taleen 1211305
////////

module uart_module #(
    parameter BUFFER_SIZE = 16,
    parameter DATA_WIDTH = 8
)(
    input clk,
    input rstn,
    input re,
    output reg [DATA_WIDTH-1:0] data_out,
    output reg data_valid
);
  
  // Internal buffer with preloaded data
  reg [DATA_WIDTH-1:0] buffer [0:BUFFER_SIZE-1];
  reg [$clog2(BUFFER_SIZE)-1:0] read_ptr;
  reg re_prev;
    
  // Initialize buffer with sample data
  initial 
    begin
      buffer[0]  = 8'h41; // 'A'
	  buffer[1]  = 8'h64; // 'd'
      buffer[2]  = 8'h76; // 'v'
      buffer[3]  = 8'h61; // 'a'
      buffer[4]  = 8'h6E;// 'n'
      buffer[5]  = 8'h63; // 'c'
      buffer[6]  = 8'h65; // 'e'
      buffer[7]  = 8'h64; // 'd'
      buffer[8]  = 8'h20; // ' '
      buffer[9]  = 8'h44; // 'D'
      buffer[10] = 8'h69; // 'i'
      buffer[11] = 8'h67; // 'g'
      buffer[12] = 8'h69; // 'i'
      buffer[13] = 8'h74; // 't'
      buffer[14] = 8'h61; // 'a'
      buffer[15] = 8'h6C; // 'l
    end
  
  always @(posedge clk or negedge rstn) 
    begin
      if (!rstn)
        begin
          read_ptr <= 0;
          data_out <= 0;
          data_valid <= 0;
          re_prev <= 0;
        end
      else
        begin
          re_prev <= re;
          
          if (re && !re_prev && read_ptr < BUFFER_SIZE)
            begin
              data_out <= buffer[read_ptr];
              read_ptr <= read_ptr + 1;
              data_valid <= 1;
            end 
          else if (!re)
            begin
              data_valid <= 0;
            end
        end
    end
    
    // Method to reset read pointer (for new transfers)
    task reset_pointer();
        read_ptr = 0;
    endtask
    
endmodule

//////////////////////////////////////////////////////////////////////////////////
// memory module

module memory_module #(
    parameter DATA_WIDTH = 8,
    parameter ADDR_WIDTH = 8,
    parameter MEMORY_DEPTH = 256
)(
    input clk,
    input rstn,
    input [ADDR_WIDTH-1:0] write_address,
    input [DATA_WIDTH-1:0] data_in,
    input we,
    input [ADDR_WIDTH-1:0] read_address,
    output reg [DATA_WIDTH-1:0] data_out,
    input re
);
  
  // memory array
  reg [DATA_WIDTH-1:0] mem [0:MEMORY_DEPTH-1];
    
  always @(posedge clk or negedge rstn)
    begin
      if (!rstn)
        begin
            data_out <= 0;
            // Clear memory on reset
            for (int i = 0; i < MEMORY_DEPTH; i++) 
              begin
                mem[i] <= 0;
              end
        end 
      else 
        begin
            // Write operation
            if (we) 
              begin
                mem[write_address] <= data_in;
              end
            
            // Read operation
            if (re) 
              begin
                data_out <= mem[read_address];
              end
        end
    end
    
endmodule

//////////////////////////////////////////////////////////////////////
// DMA Controller module


module dma_controller_module #(
    parameter DATA_WIDTH = 8,
    parameter ADDR_WIDTH = 8,
    parameter SIZE_WIDTH = 8
)(
    input clk,
    input rstn,
    input start,
    input [DATA_WIDTH-1:0] uart_data,
    input uart_data_valid,
    input [ADDR_WIDTH-1:0] start_address,
    input [SIZE_WIDTH-1:0] transfer_size,
    output reg uart_read_enable,
    output reg [ADDR_WIDTH-1:0] memory_write_address,
    output reg [DATA_WIDTH-1:0] memory_write_data,
    output reg memory_write_enable,
    output reg done
);
  
  // state parameter 
  parameter IDLE = 2'b00;
  parameter READ_UART = 2'b01;
  parameter WRITE_MEMORY = 2'b10;
  reg [1:0] current_state , next_state;

  // Internal registers
  reg [ADDR_WIDTH-1:0] current_address;
  reg [SIZE_WIDTH-1:0] byte_counter;
  reg [DATA_WIDTH-1:0] data_buffer;
  reg start_prev;
    
  // State register
  always @(posedge clk or negedge rstn) 
    begin
        if (!rstn) 
          begin
            current_state <= IDLE;
          end 
        else 
          begin
            current_state <= next_state;
          end
    end
    
  // Next state logic
  always @(*) 
    begin
        case (current_state)
            IDLE: 
              begin
                if (start && transfer_size > 0)
                    next_state = READ_UART;
                else
                    next_state = IDLE;
              end
            
            READ_UART: 
              begin
                if (uart_data_valid)
                    next_state = WRITE_MEMORY;
                else
                    next_state = READ_UART;
              end
            
            WRITE_MEMORY: 
              begin
                if (byte_counter >= transfer_size - 1)
                    next_state = IDLE;
                else
                    next_state = READ_UART;
              end
            
            default: next_state = IDLE;
        endcase
    end
    
  function [87:0] state_name;
    input [1:0] state;
    begin
      case (state)
        IDLE: state_name = "IDLE";
        READ_UART: state_name = "READ_UART";
        WRITE_MEMORY: state_name = "WRITE_MEM";
        default: state_name = "UNKNOWN";
             
      endcase
    end
  endfunction

  
  
  // Output logic and internal registers
  always @(posedge clk or negedge rstn) 
    begin
        if (!rstn) 
          begin
            memory_write_enable <= 0;
            uart_read_enable <= 0;
            memory_write_data <= 0;
            done <= 0;
            memory_write_address <= 0;
            current_address <= 0;
            byte_counter <= 0;
            start_prev <= 0;
            data_buffer <= 0;
          end 
        else 
          begin
            start_prev <= start;
            uart_read_enable <= 0;
            memory_write_enable <= 0;
            
            case (current_state)
                IDLE: 
                  begin
                    // Handle zero transfer size immediately
                    if (start && !start_prev && transfer_size == 0) 
                      begin
                        done <= 1;
                      end 
                    else if (start && !start_prev && transfer_size > 0) 
                      begin
                        // Initialize for new transfer
                        current_address <= start_address;
                        byte_counter <= 0;
                        done <= 0;
                        uart_read_enable <= 1; // Start reading from UART
                      end 
                    else if (!start) 
                      begin
                        done <= 0;
                      end
                  end
                READ_UART: 
                  begin
                    if (uart_data_valid)
                      begin
                        data_buffer <= uart_data;
                      end 
                    else 
                      begin
                        uart_read_enable <= 1;  // Keep requesting data
                      end
                  end
                WRITE_MEMORY: 
                  begin
                    //write buffered data to memory
                    memory_write_address <= current_address;
                    memory_write_data <= data_buffer;
                    memory_write_enable <= 1;
                    current_address <= current_address + 1; //update counter of add
                    byte_counter <= byte_counter + 1;//update counter of byte
                    
                    // Check if transfer is complete
                    if (byte_counter >= transfer_size - 1) 
                      begin
                        done <= 1;
                      end 
                    else 
                      begin
                        uart_read_enable <= 1;  // Request next byte
                      end
                  end
            endcase
          end
    end
    
endmodule

//////////////////////////////////////////////////////////////////////////////////
// top level module connect 3 modules together 

module dma_system_top #(
    parameter DATA_WIDTH = 8,
    parameter ADDR_WIDTH = 8,
    parameter SIZE_WIDTH = 8,
    parameter MEMORY_DEPTH = 256,
    parameter UART_BUFFER_SIZE = 16
)(
    input clk,
    input rstn,
    // CPU interface
    input start,
    input [ADDR_WIDTH-1:0] start_address,
    input [SIZE_WIDTH-1:0] transfer_size,
    output done,
    // Memory read interface for verification
    input [ADDR_WIDTH-1:0] mem_read_address,
    input mem_read_enable,
    output [DATA_WIDTH-1:0] mem_read_data,
    // UART reset for testing
    input uart_reset_ptr
);
  
  // Internal signals
  wire uart_read_enable;
  wire [DATA_WIDTH-1:0] uart_data;
  wire uart_data_valid;
  wire [ADDR_WIDTH-1:0] memory_write_address;
  wire [DATA_WIDTH-1:0] memory_write_data;
  wire memory_write_enable;
  
  // UART instance
  uart_module #(
    .BUFFER_SIZE(UART_BUFFER_SIZE),
    .DATA_WIDTH(DATA_WIDTH)) 
  uart_inst (
    .clk(clk),
    .rstn(rstn),
    .re(uart_read_enable),
    .data_out(uart_data),
    .data_valid(uart_data_valid));
    

  // Memory instance
  memory_module #(
    .DATA_WIDTH(DATA_WIDTH),
    .ADDR_WIDTH(ADDR_WIDTH),
    .MEMORY_DEPTH(MEMORY_DEPTH))
  memory_inst (
    .clk(clk),
    .rstn(rstn),
    .write_address(memory_write_address),
    .data_in(memory_write_data),
    .we(memory_write_enable),
    .read_address(mem_read_address),
    .data_out(mem_read_data),
    .re(mem_read_enable));
    
  // DMA Controller instance
  dma_controller_module #(
    .DATA_WIDTH(DATA_WIDTH),
    .ADDR_WIDTH(ADDR_WIDTH),
    .SIZE_WIDTH(SIZE_WIDTH)) 
  dma_inst (
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
    .done(done));
    
    // UART pointer reset functionality for testing
  always @(posedge clk) 
    begin
      if (uart_reset_ptr) 
        begin
            uart_inst.reset_pointer();        
        end
    end
    
endmodule

