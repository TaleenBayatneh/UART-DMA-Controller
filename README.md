# UART-to-Memory DMA Controller

A simplified single-channel DMA (Direct Memory Access) controller designed in SystemVerilog for transferring data from UART to memory without CPU intervention.

## Overview

This project implements a DMA controller that autonomously transfers data from a UART buffer to system memory. The design follows a finite state machine (FSM) approach with three states: IDLE, READ_UART, and WRITE_MEMORY.

## Architecture

```
┌─────────────┐     ┌─────────────────┐     ┌─────────────┐
│    UART     │────►│  DMA Controller │────►│   Memory    │
│   Module    │     │     (FSM)       │     │   Module    │
└─────────────┘     └─────────────────┘     └─────────────┘
                           ▲
                           │
                    ┌──────┴──────┐
                    │     CPU     │
                    │  (Control)  │
                    └─────────────┘
```

## Modules

| Module | Description |
|--------|-------------|
| `uart_module` | Simulates UART with 16-byte buffer and read interface |
| `memory_module` | 256-byte memory with read/write operations |
| `dma_controller_module` | FSM-based controller managing data transfer |
| `dma_system_top` | Top-level module connecting all components |

## FSM States

1. **IDLE**: Waits for start signal, initializes transfer parameters
2. **READ_UART**: Requests and captures data from UART buffer
3. **WRITE_MEMORY**: Writes buffered data to memory at current address

## Parameters

| Parameter | Default | Description |
|-----------|---------|-------------|
| `DATA_WIDTH` | 8 | Data bus width in bits |
| `ADDR_WIDTH` | 8 | Address bus width |
| `MEMORY_DEPTH` | 256 | Memory size in bytes |
| `UART_BUFFER_SIZE` | 16 | UART buffer size |

## Interface Signals

### Inputs
- `clk` - System clock
- `rstn` - Active-low reset
- `start` - Initiates DMA transfer
- `start_address` - Memory destination address
- `transfer_size` - Number of bytes to transfer

### Outputs
- `done` - Transfer complete flag

## Testbenches

| File | Purpose |
|------|---------|
| `uart_testbench.sv` | UART module verification |
| `memory_testbench.sv` | Memory read/write testing |
| `controller_testbench.sv` | DMA controller FSM testing |
| `top_level_testbench.sv` | Full system integration tests |

### Test Cases
- Basic 4-byte transfer
- Single byte transfer
- Maximum buffer transfer (16 bytes)
- Reset during transfer
- Zero-size transfer (edge case)
- Back-to-back transfers

## Simulation

Run with any SystemVerilog simulator:

```bash
# Using Icarus Verilog
iverilog -g2012 -o sim design.sv top_level_testbench.sv
vvp sim

# Using ModelSim
vlog design.sv top_level_testbench.sv
vsim -c dma_system_tb -do "run -all"
```

## Files

```
├── design.sv                 # All design modules
├── uart_testbench.sv         # UART unit tests
├── memory_testbench.sv       # Memory unit tests
├── controller_testbench.sv   # Controller unit tests
├── top_level_testbench.sv    # System integration tests
├── block diagram.pdf         # Architecture diagram
└── project_report.pdf        # Full documentation
```




