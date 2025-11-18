# LED Test Project

Simple LED blinker project for testing FPGA functionality.

## Description

This project implements a basic LED counter that uses a 27-bit counter to create visible LED patterns. The upper 8 bits of the counter are mapped to 8 LEDs, creating a slow-moving binary count display.

## Hardware Connections

- **clk**: System clock input (typically 100 MHz on Nexys boards)
- **led[7:0]**: 8-bit LED output

## Build Instructions

1. Ensure Vivado is in your PATH
2. Run the build script:
   ```bash
   vivado -mode batch -source build.tcl
   ```
3. The bitstream will be generated in `build/led_test.runs/impl_1/top_module.bit`

## Usage

1. Program the FPGA with the generated bitstream
2. Observe the LEDs counting in a binary pattern
3. The LEDs will change approximately every few seconds

## Customization

- Adjust `part_number` in `build.tcl` to match your FPGA board
- Modify the counter width in `top_module.vhd` to change blink speed
- Add pin constraints in `src/constraints/` to match your board's pinout
