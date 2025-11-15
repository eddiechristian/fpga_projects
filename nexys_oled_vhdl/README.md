# Nexys Video OLED Display Controller (VHDL)

This project is a complete VHDL implementation of an OLED display controller for the **Nexys Video FPGA board's onboard OLED display**. It is based on the original Digilent Verilog example, converted to VHDL and using Vivado Block RAM IP cores.

## Features

- **Pure VHDL Implementation**: All modules converted from original Verilog to VHDL
- **Block RAM IP Integration**: Uses Vivado Block Memory Generator IP for:
  - Character library ROM (8x8 pixel font)
  - Pixel buffer RAM (frame buffer)
  - Initialization sequence ROM
- **Automated Setup**: TCL scripts for complete project creation
- **Character Display**: Displays text strings on 128x32 OLED (4 rows × 16 characters)
- **Demo Sequence**: Alternates between alphabet display and splash screen

## Hardware

- **Target Board**: Digilent Nexys Video (XC7A200T)
- **Display**: Onboard 128x32 OLED (SSD1306 compatible)
- **Interface**: SPI (4-wire)
- **Clock**: 100 MHz system clock

## Project Structure

```
nexys_oled_vhdl/
├── build/                      # Vivado project (generated, ignored by git)
│   └── nexys_oled_vhdl.xpr
├── src/                        # Source files
│   ├── hdl/                    # VHDL source files
│   │   ├── spi_ctrl.vhd
│   │   ├── delay_ms.vhd
│   │   ├── oled_ctrl.vhd
│   │   └── oled_master.vhd
│   ├── constraints/
│   │   └── nexys_video.xdc
│   └── data/
│       ├── characterLib.coe
│       └── init_sequence.coe
├── create_project.tcl          # Create Vivado project
├── build_and_program.tcl       # Build bitstream and program FPGA
├── program.tcl                 # Program existing bitstream
├── .gitignore
└── README.md
```

## Quick Start

### Build and Program (One Command)

```bash
vivado -mode tcl -source build_and_program.tcl
```

This will:
1. Build the bitstream (or use existing project)
2. Automatically detect and program your FPGA board

### Step-by-Step Workflow

**1. Create project (first time only):**
```bash
vivado -mode batch -source create_project.tcl
```

**2. Build bitstream:**
```bash
vivado -mode tcl -source build_and_program.tcl
```
Or open in GUI:
```bash
vivado build/nexys_oled_vhdl.xpr
```

**3. Program existing bitstream:**
```bash
vivado -mode tcl -source program.tcl
```

## Expected Behavior

After programming, the OLED display will:
1. Initialize (may briefly flash)
2. Display the alphabet for 4 seconds
3. Switch to "This is / Digilent's / Nexys Video" for 1 second
4. Repeat the sequence

## Block RAM IP Cores

Three Block Memory Generator IP cores are used:

### 1. charLib (Character Library ROM)
- **Type**: Single Port ROM
- **Size**: 1024 × 8 bits (1 KB)
- **Purpose**: Stores 8×8 pixel bitmaps for ASCII characters
- **Init File**: `data/characterLib.coe`

### 2. pixel_buffer (Pixel Buffer RAM)
- **Type**: Simple Dual Port RAM
- **Size**: 512 × 8 bits (512 bytes)
- **Purpose**: Frame buffer for display content
- **Ports**: 
  - Port A: Write (from character library)
  - Port B: Read (to display controller)

### 3. init_sequence_rom (Initialization ROM)
- **Type**: Single Port ROM
- **Size**: 16 × 16 bits (32 bytes)
- **Purpose**: SSD1306 initialization command sequence
- **Init File**: `data/init_sequence.coe`

## Module Descriptions

### spi_ctrl.vhd
SPI controller for communicating with the SSD1306 OLED controller. Sends 8-bit data over SPI with configurable clock divider.

### delay_ms.vhd
Provides millisecond-accurate delays for initialization timing (OLED power sequencing, reset timing, etc.).

### oled_ctrl.vhd
Main OLED controller that:
- Manages initialization sequence
- Handles character-to-pixel conversion
- Updates display from pixel buffer
- Controls OLED power rails (VDD, VBAT)

### oled_master.vhd
Top-level demo module that:
- Writes text strings to pixel buffer
- Triggers display updates
- Implements demo sequence (alphabet → splash → repeat)

## Display Specifications

- **Resolution**: 128 × 32 pixels
- **Organization**: 4 pages (rows) × 128 columns
- **Character Layout**: 4 rows × 16 characters
- **Character Size**: 8 × 8 pixels
- **Addressing**: Horizontal addressing mode
- **Controller**: Solomon Systech SSD1306

## Pin Assignments

| Signal | FPGA Pin | Description |
|--------|----------|-------------|
| clk | R4 | 100 MHz system clock |
| rstn | G4 | Reset button (active low) |
| oled_sclk | W21 | SPI clock |
| oled_sdin | Y22 | SPI data (MOSI) |
| oled_dc | W22 | Data/Command select |
| oled_res | U21 | Reset (active low) |
| oled_vbat | P20 | VBAT power control |
| oled_vdd | V22 | VDD power control |

## Customization

### Changing Display Text

Edit the string constants in `oled_master.vhd`:

```vhdl
-- SPLASH screen text (lines 54-57)
constant splash_str1 : string := "This is         ";
constant splash_str2 : string := "Digilent's      ";
constant splash_str3 : string := "Nexys Video     ";
constant splash_str4 : string := "                ";

-- ALPHA screen text (lines 59-62)
constant alpha_str1  : string := "ABCDEFGHIJKLMNOP";
-- ... etc
```

Each string must be **exactly 16 characters** (pad with spaces).

### Changing Display Timing

Edit delay values in `oled_master.vhd`:

```vhdl
-- Line 241: Time to show alphabet (milliseconds)
delay_time_ms <= x"FA0";  -- 4000 ms = 4 seconds

-- Line 260: Time to show splash (milliseconds)
delay_time_ms <= x"3E8";  -- 1000 ms = 1 second
```

## Troubleshooting

### OLED doesn't turn on
- Check power connections
- Verify bitstream programmed correctly
- Press reset button (BTN0)
- Check constraint file pin assignments

### Display shows garbage
- Verify COE files are loaded correctly
- Check IP core generation completed
- Ensure all three BRAMs synthesized properly

### Synthesis errors about missing IPs
- Run `create_ips.tcl` or `create_project.tcl`
- Verify COE files exist in `data/` directory
- Check Vivado version compatibility (tested with 2024.2)

## Original Source

This project is based on Digilent's original Verilog OLED demo, converted to VHDL with Block RAM IP integration.

## License

Based on Digilent's example code. Converted to VHDL for educational purposes.

## Additional Resources

- [Nexys Video Reference Manual](https://digilent.com/reference/programmable-logic/nexys-video/reference-manual)
- [SSD1306 Datasheet](https://www.solomon-systech.com/en/product/advanced-display/oled-display-driver-ic/ssd1306/)
- [Block Memory Generator User Guide (UG473)](https://www.xilinx.com/support/documentation/ip_documentation/blk_mem_gen/v8_4/pg058-blk-mem-gen.pdf)
