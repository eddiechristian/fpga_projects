# VGA Implementation for Nexys Video FPGA

This project demonstrates VGA output from the Nexys Video FPGA board, implementing the VGA protocol from scratch in VHDL.

## Project Structure

```
vga_nexys_video/
├── src/
│   ├── vga_top.vhd          # Top-level VHDL module with VGA controller
│   └── nexys_video.xdc      # Pin constraints for Nexys Video board
├── build/                    # Vivado project and build outputs
├── build_project.tcl         # Creates Vivado project
├── build_and_program.tcl     # Synthesizes, implements, generates bitstream
└── program_fpga.tcl          # Programs the FPGA with bitstream
```

## VGA Protocol Overview

### VGA Signal Basics

VGA uses **analog RGB signals** with **digital sync signals**:
- **RGB**: 3 analog signals (Red, Green, Blue) - 0.7V peak-to-peak
- **HSYNC**: Horizontal sync pulse (digital)
- **VSYNC**: Vertical sync pulse (digital)

The Nexys Video provides 8-bit DACs for each color channel (256 levels per color).

### VGA 640x480 @ 60Hz Timing

This is the most common VGA mode and requires a **25.175 MHz pixel clock**.

#### Horizontal Timing (per line)
| Parameter | Pixels | Time @ 25.175MHz |
|-----------|--------|------------------|
| Visible area | 640 | 25.422 μs |
| Front porch | 16 | 0.636 μs |
| Sync pulse | 96 | 3.813 μs |
| Back porch | 48 | 1.907 μs |
| **Total** | **800** | **31.778 μs** |

#### Vertical Timing (per frame)
| Parameter | Lines | Time |
|-----------|-------|------|
| Visible area | 480 | 15.253 ms |
| Front porch | 10 | 0.318 ms |
| Sync pulse | 2 | 0.064 ms |
| Back porch | 33 | 1.048 ms |
| **Total** | **525** | **16.683 ms (59.94 Hz)** |

### How VGA Works

1. **Raster Scan**: The monitor draws the image line by line from left to right, top to bottom
2. **Horizontal Sync**: At the end of each line, HSYNC pulses to tell the monitor to start a new line
3. **Vertical Sync**: At the end of the frame, VSYNC pulses to tell the monitor to return to the top
4. **Blanking Periods**: During sync and porch periods, RGB signals must be driven to 0 (black)
5. **Active Video**: RGB values are only valid during the visible display area

### Sync Signal Polarity

For 640x480 @ 60Hz:
- **HSYNC**: Active LOW (0 during sync pulse)
- **VSYNC**: Active LOW (0 during sync pulse)

## Implementation Details

### Clock Generation

The Nexys Video has a 100 MHz system clock. We need 25 MHz for VGA:
```vhdl
-- Divide by 4: 100 MHz / 4 = 25 MHz
if clk_counter = 1 then
    clk_25mhz <= not clk_25mhz;  -- Toggles every 2 cycles
end if
```

### Counter Logic

Two counters track the current pixel position:
- **h_count**: Horizontal pixel counter (0 to 799)
- **v_count**: Vertical line counter (0 to 524)

```vhdl
-- h_count increments every pixel clock
-- When h_count reaches 799, it resets and v_count increments
-- When both counters reach their max, we've completed one frame
```

### Test Pattern

The included design displays 8 vertical color bars:
1. White
2. Yellow
3. Cyan
4. Green
5. Magenta
6. Red
7. Blue
8. Black

This is a classic test pattern to verify all color channels work correctly.

## Hardware Setup

This design outputs VGA through **PMOD connectors JA and JB**.

### Pin Mapping

**PMOD JA:**
- Pins 1-4 (top row): Red channel (4-bit)
- Pins 7-10 (bottom row): Green channel (4-bit)

**PMOD JB:**
- Pins 1-4 (top row): Blue channel (4-bit)
- Pins 7-8 (bottom row): HSYNC, VSYNC

### Required Hardware

1. **Resistor DACs**: You need three 4-bit resistor ladders (one per RGB channel)
   - Simple approach: One resistor per bit (270Ω for MSB works for testing)
   - Proper approach: R-2R ladder with 470Ω and 1kΩ resistors
2. **VGA cable**: Cut one open or use a breakout board
3. **Breadboard**: For wiring the resistor network
4. **PMOD breakout**: Or direct wire to PMOD headers

See `WIRING_GUIDE.md` for detailed wiring instructions.

## Building and Running

### Prerequisites

- Xilinx Vivado 2019.1 or later
- Nexys Video FPGA board
- VGA monitor and VGA cable
- USB cable for FPGA programming
- Resistors and wiring for PMOD-to-VGA connection

### Step 1: Create the Project

```bash
cd /home/eddie/fpga_projects/vga_nexys_video
vivado -mode batch -source build_project.tcl
```

This creates a Vivado project in the `build/` directory.

### Step 2: Build the Bitstream

```bash
vivado -mode batch -source build_and_program.tcl
```

This runs:
1. **Synthesis**: Converts VHDL to gate-level netlist
2. **Implementation**: Places and routes the design
3. **Bitstream generation**: Creates the .bit file for programming

Build time: ~5-10 minutes depending on your system.

### Step 3: Program the FPGA

Connect your Nexys Video board via USB and VGA, then:

```bash
vivado -mode batch -source program_fpga.tcl
```

Or use the Vivado GUI:
```bash
vivado build/vga_nexys_video.xpr
# In Vivado: Flow > Open Hardware Manager > Program Device
```

### Step 4: Test

1. Press **BTNC (center button)** if you need to reset
2. You should see 8 vertical color bars on your VGA monitor
3. If nothing appears, check:
   - VGA cable connections
   - Monitor input selection
   - Monitor supports 640x480 @ 60Hz

## Customizing the Design

### Change the Test Pattern

Edit the pattern generation process in `src/vga_top.vhd`:

```vhdl
process(clk_25mhz)
begin
    if rising_edge(clk_25mhz) then
        if video_on = '1' then
            -- Add your custom pattern here
            -- Use h_count and v_count to determine position
            vga_r <= your_red_value;
            vga_g <= your_green_value;
            vga_b <= your_blue_value;
        else
            vga_r <= x"00";
            vga_g <= x"00";
            vga_b <= x"00";
        end if;
    end if;
end process;
```

### Example: Checkerboard Pattern

```vhdl
if ((h_count(5) xor v_count(5)) = '1') then
    vga_r <= x"FF"; vga_g <= x"FF"; vga_b <= x"FF";
else
    vga_r <= x"00"; vga_g <= x"00"; vga_b <= x"00";
end if;
```

### Example: Gradient

```vhdl
vga_r <= std_logic_vector(h_count(9 downto 2));
vga_g <= std_logic_vector(v_count(9 downto 2));
vga_b <= x"80";
```

## Other VGA Resolutions

To implement different resolutions, change the timing constants:

### 800x600 @ 60Hz (40 MHz pixel clock)
- H: 800 + 40 + 128 + 88 = 1056 total
- V: 600 + 1 + 4 + 23 = 628 total
- Sync: Both positive (high during pulse)

### 1024x768 @ 60Hz (65 MHz pixel clock)
- H: 1024 + 24 + 136 + 160 = 1344 total
- V: 768 + 3 + 6 + 29 = 806 total
- Sync: Both negative (low during pulse)

You'll need to adjust the clock divider and timing constants accordingly.

## Troubleshooting

| Issue | Solution |
|-------|----------|
| No display | Check VGA cable, verify monitor supports 640x480, check power |
| Wrong colors | Check RGB pin assignments in XDC file |
| Flickering | Ensure sync signals are correct polarity and timing |
| Distorted image | Check pixel clock frequency (should be 25 MHz) |
| Screen shifted | Verify front/back porch timing values |

## Hardware Resources Used

- **LUTs**: ~50
- **Flip-Flops**: ~40
- **Max Clock**: 100 MHz (system), 25 MHz (pixel clock)
- **I/O Pins**: 26 (8 red + 8 green + 8 blue + HSYNC + VSYNC)

## Next Steps

1. **Add framebuffer**: Store image data in block RAM
2. **Text display**: Implement character ROM for text rendering
3. **Graphics primitives**: Draw lines, rectangles, circles
4. **Video input**: Capture from HDMI/camera and display on VGA
5. **Games**: Implement Pong, Snake, or other simple games

## References

- [VGA Signal Timing](http://www.tinyvga.com/vga-timing)
- [Nexys Video Reference Manual](https://digilent.com/reference/programmable-logic/nexys-video/reference-manual)
- [VESA Display Timing Standards](https://en.wikipedia.org/wiki/VESA_BIOS_Extensions)

## License

This is educational example code - feel free to use and modify as needed.
