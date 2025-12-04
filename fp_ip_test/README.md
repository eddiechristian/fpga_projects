# Floating Point IP Test Project

This project demonstrates the use of Vivado Floating Point IP cores for simulation, including post-synthesis and post-implementation timing simulations.

## Overview

The project includes four Xilinx Floating Point IP cores:
- **Square Root**: Computes sqrt(a)
- **Multiplication**: Computes a × b
- **Addition**: Computes a + b
- **Compare**: Compares a and b

All IP cores use IEEE 754 single precision (32-bit) floating point format.

## Project Structure

```
fp_ip_test/
├── build.tcl              # Vivado build script
├── build/                 # Build output (generated)
├── README.md              # This file
└── src/
    ├── hdl/               # VHDL source files
    │   └── top_module.vhd
    ├── sim/               # Testbench files
    │   └── top_module_tb.vhd
    └── constraints/       # Constraint files (empty for sim-only)
```

## IP Core Configurations

### Square Root IP
- Operation: Square Root
- Precision: Single (32-bit)
- Latency: 28 cycles
- Flow Control: Non-blocking

### Multiplication IP
- Operation: Multiply
- Precision: Single (32-bit)
- Latency: 8 cycles
- Flow Control: Non-blocking

### Addition IP
- Operation: Add
- Precision: Single (32-bit)
- Latency: 11 cycles
- Flow Control: Non-blocking

### Compare IP
- Operation: Compare
- Precision: Single (32-bit)
- Latency: 2 cycles
- Output: 8-bit comparison result
- Flow Control: Non-blocking

## Building the Project

### Option 1: Full Build (Recommended)

Run the complete build script which generates IP, runs behavioral simulation, synthesis, and implementation:

```bash
vivado -mode batch -source build.tcl
```

This will:
1. Create the Vivado project
2. Generate all four floating point IP cores
3. Run behavioral simulation
4. Run synthesis
5. Run implementation
6. Generate timing simulation files
7. Create utilization, timing, and power reports

### Option 2: Manual Steps

1. **Generate IP and create project**:
   ```bash
   vivado -mode tcl
   ```
   Then run the script up to the simulation steps.

2. **Open the project in GUI**:
   ```bash
   vivado build/fp_ip_test.xpr
   ```

## Running Simulations

### Behavioral Simulation

From Vivado TCL console:
```tcl
launch_simulation
run all
```

Or from GUI: Flow > Run Simulation > Run Behavioral Simulation

### Post-Synthesis Functional Simulation

After synthesis completes:
```tcl
launch_simulation -mode post-synthesis -type functional
run all
```

Or from GUI: Flow > Run Simulation > Run Post-Synthesis Functional Simulation

### Post-Implementation Timing Simulation

After implementation completes:
```tcl
launch_simulation -mode post-implementation -type timing
run all
```

Or from GUI: Flow > Run Simulation > Run Post-Implementation Timing Simulation

The timing simulation includes:
- Accurate gate-level netlist
- Routing delays
- SDF annotation for precise timing
- Real FPGA behavior simulation

## Test Cases

The testbench includes 5 test cases with different floating point values:

1. a=9.0, b=3.0 → sqrt(9)=3.0, 9×3=27, 9+3=12, compare(9,3)
2. a=16.0, b=4.0 → sqrt(16)=4.0, 16×4=64, 16+4=20, compare(16,4)
3. a=2.5, b=1.5 → sqrt(2.5)≈1.58, 2.5×1.5=3.75, 2.5+1.5=4.0, compare(2.5,1.5)
4. a=100.0, b=50.0 → sqrt(100)=10.0, 100×50=5000, 100+50=150, compare(100,50)
5. a=0.25, b=0.5 → sqrt(0.25)=0.5, 0.25×0.5=0.125, 0.25+0.5=0.75, compare(0.25,0.5)

## Simulation Files

After implementation, the following timing simulation files are generated in `build/`:

- `timing_sim.vhd` - Post-implementation VHDL netlist
- `timing_sim.sdf` - Standard Delay Format file with timing annotations

These files can be used with external simulators (ModelSim, Questa, etc.) for timing-accurate simulation.

## Customization

### Changing Target FPGA

Edit `build.tcl` line 10:
```tcl
set part_number "xc7a100tcsg324-1"
```

Replace with your target part number.

### Adjusting IP Latency

Edit the `CONFIG.C_Latency` values in `build.tcl` for each IP core to trade off between speed and resource usage.

### Adding Constraints

For FPGA deployment, add constraint files (.xdc) to `src/constraints/`:
- Clock definitions
- Pin assignments
- Timing constraints

## Reports

After implementation, reports are generated in `build/`:
- `utilization.rpt` - Resource utilization
- `timing.rpt` - Timing analysis summary
- `power.rpt` - Power consumption estimates

## Notes

- The testbench includes a helper function to convert real numbers to IEEE 754 format
- All IP cores use AXI4-Stream interfaces (TVALID/TDATA)
- Non-blocking flow control is used (no TREADY signals)
- Results are available when `valid_out` is asserted

## Troubleshooting

**IP generation fails**: Ensure you have the Xilinx Floating Point IP license and Vivado version 7.1 or compatible.

**Simulation doesn't show results**: Check the latency values - results appear after the IP latency cycles.

**Timing errors in post-implementation**: This is normal for unconstrained designs. Add proper clock constraints for real FPGA deployment.
