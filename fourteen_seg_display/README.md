# 14-Segment Display Project for Nexys Video

## Project Overview
This project drives 2x LTP-3786E 14-segment displays (4 digits total) from a Nexys Video FPGA board, displaying a hexadecimal counter from 0000 to FFFF.

## Hardware
- **FPGA**: Nexys Video (Xilinx Artix-7 XC7A200T)
- **Clock**: 100 MHz system clock
- **Displays**: 2x LTP-3786E (2-digit 14-segment common anode displays)
- **Interface**: PMOD ports JA, JB, JC

## Features
- Hexadecimal counter (0000-FFFF)
- Automatic leading zero blanking
- Multiplexed display refresh (~1ms per digit, ~250Hz per digit refresh rate)
- Debounced reset button
- LED debug output (shows lower 8 bits of counter)

## Project Structure
```
fourteen_seg_display/
├── fourteen_seg_display.srcs/
│   ├── sources_1/new/
│   │   ├── top_module.vhd              # Top-level design
│   │   ├── counter.vhd                 # 16-bit counter
│   │   ├── display_dec_to_hex.vhd      # Decimal to hex ASCII converter
│   │   ├── segment_multiplexor.vhd     # Display multiplexor with clock divider
│   │   ├── ascii_to_14seg.vhd          # ASCII to 14-segment decoder
│   │   └── debouncer.vhd               # Button debouncer
│   ├── sim_1/new/
│   │   └── tb_segment_multiplexor.vhd  # Testbench for multiplexor
│   └── constrs_1/new/
│       └── nexys_video.xdc             # Pin constraints for Nexys Video
├── WIRING_DIAGRAM.md                   # Detailed wiring instructions
└── README.md                           # This file
```

## Module Descriptions

### top_module.vhd
Main design that connects all components:
- Instantiates counter, hex converter, and multiplexor
- Decodes digit selector to individual digit enables
- Handles blanking logic for leading zeros

### counter.vhd
Simple up-counter with reset and enable.
- Generic WIDTH parameter (default 16 bits)
- Counts at system clock speed

### display_dec_to_hex.vhd
Converts a binary number to hex ASCII digits.
- Generic NUM_DIGITS parameter
- Outputs ASCII representation of hex digits
- Generates blanking mask for leading zeros

### segment_multiplexor.vhd
Multiplexes between digits and generates segment patterns.
- Generic NUM_DIGITS and CLK_DIV_MAX parameters
- Clock divider for display refresh rate
- Instantiates ascii_to_14seg for segment decoding

### ascii_to_14seg.vhd
Lookup table for ASCII to 14-segment patterns.
- Supports 0-9, A-Z, and special characters
- 14-bit output for segment control

## Building the Project

### In Vivado GUI:
1. Open the project: `fourteen_seg_display.xpr`
2. Run Synthesis (Flow Navigator → Synthesis → Run Synthesis)
3. Run Implementation (Flow Navigator → Implementation → Run Implementation)
4. Generate Bitstream (Flow Navigator → Program and Debug → Generate Bitstream)
5. Program FPGA (Flow Navigator → Program and Debug → Program Device)

### Command Line:
```bash
vivado -mode batch -source <(cat << 'EOF'
open_project fourteen_seg_display.xpr
reset_run synth_1
launch_runs impl_1 -to_step write_bitstream -jobs 4
wait_on_run impl_1
open_hw_manager
connect_hw_server
open_hw_target
set_property PROGRAM.FILE {fourteen_seg_display.runs/impl_1/top_module.bit} [get_hw_devices]
program_hw_devices [get_hw_devices]
close_hw_target
close_project
EOF
)
```

## Simulation
A testbench is provided for the segment_multiplexor module:

```bash
vivado -mode batch -source <(cat << 'EOF'
open_project fourteen_seg_display.xpr
launch_simulation
run 500ns
close_sim
close_project
EOF
)
```

Or run in GUI: Flow Navigator → Simulation → Run Simulation → Run Behavioral Simulation

## Wiring
See `WIRING_DIAGRAM.md` for detailed connection instructions.

**Key Points:**
- Use 220Ω-330Ω current-limiting resistors on each of the 14 segment lines
- PMOD JA + JB: 14 segment signals (shared between both displays)
- PMOD JC: 4 digit select signals (one for each digit)
- Common anode displays: digit select is active LOW

## Configuration Parameters

### In top_module.vhd:
```vhdl
constant NUM_DIGITS : natural := 4;        -- Total number of digits
constant CLK_DIV_MAX : natural := 100_000; -- ~1ms refresh (100MHz / 100_000)
```

Adjust `CLK_DIV_MAX` to change display refresh rate:
- Current: 100,000 = 1ms per digit = 250Hz per digit refresh
- For 2ms per digit: set to 200,000
- For 500μs per digit: set to 50,000

## Usage
1. Program the FPGA with the generated bitstream
2. The 4-digit display will show a hexadecimal counter
3. Press the RST button (CPU_RESET) to reset the counter to 0
4. The 8 onboard LEDs show the lower 8 bits of the counter value

## Troubleshooting
- **Display flickering**: Increase CLK_DIV_MAX value
- **Dim display**: Check current-limiting resistors (may need lower values)
- **Segments not lighting**: Check wiring and polarity (common anode = active LOW digit select)
- **Wrong characters**: Verify segment mapping in ascii_to_14seg.vhd matches your display pinout

## License
This project is provided as-is for educational purposes.
