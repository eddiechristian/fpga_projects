# FP32 Multiply FIFO - Stage 1

## Overview

This project implements a high-throughput FP32 (floating-point 32-bit) multiplication FIFO system using Xilinx FPGA. The design uses AXI4-Stream infrastructure with IP Integrator (IPI) to route operations to multiple parallel multipliers for maximum performance.

### Stage 1 Goals

1. **Implement multiply FIFO** with configurable number of parallel FP32 multipliers (default: 10)
2. **Test throughput** - measure multiplications per second with 10 multipliers
3. **Determine backpressure threshold** - identify when FIFO becomes backed up (entries > NUM_MULTIPLIERS × 2)
4. **Measure resource usage** - determine FPGA resource utilization for the configuration
5. **Simulation** - validate design with testbench that simulates device timing and delays

## Architecture

### Components

```
Input → TDEST Generator → Input FIFO (AXI-Stream) → AXI Interconnect (1-to-10)
                                                           ↓
                                           [10x FP32 Multipliers]
                                                           ↓
                              Output FIFO (AXI-Stream) ← AXI Combiner (10-to-1)
                                                           ↓
                                                        Output
```

### Key Features

- **AXI4-Stream Infrastructure**: Uses Xilinx AXI4-Stream Interconnect for efficient data routing
- **Round-Robin Distribution**: TDEST generator distributes operations evenly across multipliers
- **BRAM FIFOs**: Input and output buffering using Block RAM FIFOs
- **Configurable Parallelism**: Generic parameter for number of multipliers (default: 10)
- **150 MHz Operation**: Clock wizard generates 150 MHz from 100 MHz input

### IP Cores Used

- **clk_wiz_0**: Clock wizard (100 MHz → 150 MHz)
- **floating_point_mult**: Xilinx FP32 multiplier (8-cycle latency)
- **axis_input_fifo**: AXI4-Stream FIFO for input operations (64-bit: operand_a + operand_b)
- **axis_output_fifo**: AXI4-Stream FIFO for results (32-bit: FP32 result)
- **axis_interconnect_0**: 1-to-10 AXI4-Stream router (TDEST-based routing)
- **axis_combiner_0**: 10-to-1 AXI4-Stream arbiter for result collection

## Project Structure

```
resource_test/
├── build.tcl              # Vivado build script
├── build/                 # Build output directory (gitignored)
├── README.md              # This file
└── src/
    ├── hdl/               # VHDL source files
    │   ├── top_module.vhd
    │   └── tdest_generator.vhd
    ├── sim/               # Simulation/testbench files
    │   └── multiply_fifo_tb.vhd
    └── constraints/       # Constraint files (.xdc)
```

## Building the Project

### Prerequisites

- Xilinx Vivado (tested with 2021.2+)
- Target FPGA: Artix-7 xc7a200tsbg484-1 (configurable in `build.tcl`)

### Build Steps

```bash
# From project directory
vivado -mode batch -source build.tcl
```

This will:
1. Create the Vivado project in `build/` directory
2. Generate all IP cores (clocking, FIFOs, multipliers, interconnects)
3. Synthesize all IPs
4. Add HDL source files
5. Run synthesis
6. Run implementation
7. Generate bitstream
8. Generate reports (utilization, timing, power)

### Build Outputs

After successful build:
- **Project**: `build/resource_test.xpr`
- **Bitstream**: `build/resource_test.runs/impl_1/top_module.bit`
- **Reports**:
  - `build/utilization.rpt` - Resource usage
  - `build/timing.rpt` - Timing analysis
  - `build/power.rpt` - Power estimates

## Simulation

### Running Testbench

```bash
# From Vivado TCL console after build
launch_simulation
run 100us
```

Or use the GUI:
1. Open project: `vivado build/resource_test.xpr`
2. Click "Run Simulation" → "Run Behavioral Simulation"
3. In TCL console: `run 100us`

### Testbench Features

The testbench (`multiply_fifo_tb.vhd`) validates:

- **1000 multiply operations** with random FP32 operands
- **Throughput measurement** - calculates operations per second
- **Backpressure detection** - monitors when input FIFO exceeds threshold (NUM_MULTIPLIERS × 2 = 20 entries)
- **Correctness** - verifies all operations complete successfully

### Expected Results

The testbench reports:
```
STAGE 1 MULTIPLY FIFO TEST RESULTS
========================================
Configuration:
  Number of multipliers: 10
  Total operations: 1000

Performance:
  Total time: ~XXX us
  Throughput: ~XX MOPS
  Operations per second: ~XX million

FIFO Status:
  Backpressure detected: true/false
  Backpressure threshold: 20 entries
  Final input FIFO count: X
  Final output FIFO count: X
========================================
```

## Configuration

### Changing Number of Multipliers

Edit `top_module.vhd` generic:

```vhdl
generic (
    NUM_MULTIPLIERS : integer := 10  -- Change this value
);
```

**Note**: If changing beyond 10 multipliers, you must also:
1. Update `axis_interconnect_0` configuration in `build.tcl`
2. Update `axis_combiner_0` configuration in `build.tcl`
3. Update component instantiations in `top_module.vhd`

### Changing Target FPGA

Edit `build.tcl`:

```tcl
set part_number "xc7a200tsbg484-1"  # Change to your part number
```

### Changing Clock Frequency

Edit clocking wizard configuration in `build.tcl`:

```tcl
CONFIG.CLKOUT1_REQUESTED_OUT_FREQ {150.000}  # Change output frequency
```

## Performance Analysis

### Theoretical Maximum Throughput

With 10 multipliers at 150 MHz:
- **Best case**: 150 MHz × 10 multipliers = 1,500 MOPS (million operations/sec)
- **Actual**: Depends on AXI-Stream handshaking overhead and FIFO latencies

### Resource Usage

Check `build/utilization.rpt` after synthesis for:
- **DSP slices**: ~10-20 (1-2 per multiplier)
- **BRAM**: ~10-20 (FIFOs + multiplier pipelines)
- **LUTs/FFs**: ~5K-10K (interconnect + control logic)

### Backpressure Threshold

Default threshold: **NUM_MULTIPLIERS × 2 = 20 entries**

The system is considered "backed up" when the input FIFO contains more entries than can be processed immediately. This indicates:
- Input rate exceeds processing capacity
- Multipliers are saturated
- Additional buffering may be needed

## Future Stages

### Stage 2
- Multiply-Add (FMA) FIFO with configurable size
- Vec4 dot product FIFO using FMA FIFOs

## Troubleshooting

### Build Errors

- **IP version mismatch**: Update IP versions in `build.tcl` to match your Vivado version
- **Part not found**: Update `part_number` in `build.tcl` to match available parts

### Simulation Issues

- **Long simulation time**: Reduce `NUM_TEST_OPS` in testbench (default: 1000)
- **Clock not locking**: Increase reset time in testbench

## References

- [Xilinx AXI4-Stream Interconnect Product Guide (PG035)](https://www.xilinx.com/support/documentation/ip_documentation/axis_interconnect/v1_1/pg035_axis_interconnect.pdf)
- [Xilinx Floating-Point Operator Product Guide (PG060)](https://www.xilinx.com/support/documentation/ip_documentation/floating_point/v7_1/pg060-floating-point.pdf)
- [Xilinx FIFO Generator Product Guide (PG057)](https://www.xilinx.com/support/documentation/ip_documentation/fifo_generator/v13_2/pg057-fifo-generator.pdf)

## License

This project follows the same license as the parent FPGA projects directory.
