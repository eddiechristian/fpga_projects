# HDMI Video Output for Nexys Video

This project generates HDMI video output on the Nexys Video FPGA board using Vivado IP cores.

## Features

- 1920x1080@60Hz (1080p) video output
- Uses Vivado IP cores for video generation:
  - Clocking Wizard (generates 148.5 MHz pixel clock and 742.5 MHz serial clock)
  - Video Timing Controller (generates HSYNC/VSYNC/DE signals)
  - Video Test Pattern Generator (generates test patterns)
  - AXI4-Stream to Video Out (converts AXI stream to video signals)
  - RGB to DVI (Digilent IP - HDMI/DVI encoder with TMDS serialization)

## Hardware Requirements

- Nexys Video FPGA board (Artix-7 XC7A200T)
- HDMI cable
- Monitor with HDMI input supporting 1080p@60Hz

## Build Instructions

1. Ensure Vivado is installed and in your PATH
2. Make sure the Digilent IP repository is installed (contains rgb2dvi IP)
3. Run the build script:
   ```bash
   cd hdmi_video_nexys
   vivado -mode batch -source build.tcl
   ```

## Programming the FPGA

After building, program the device:
```bash
vivado -mode batch -source program.tcl
```

Or use the Vivado GUI to program `build/hdmi_video_nexys.runs/impl_1/top_module.bit`

## How It Works

1. **Clock Generation**: The Clocking Wizard takes the 100 MHz board clock and generates:
   - 148.5 MHz pixel clock (for 1080p@60Hz)
   - 742.5 MHz serial clock (5x pixel clock for TMDS serialization)

2. **Video Timing**: The Video Timing Controller generates all timing signals for 1080p (HSYNC, VSYNC, DE)

3. **Video Content**: The Video Test Pattern Generator creates test patterns (color bars, ramps, etc.)

4. **Video Pipeline**: AXI4-Stream to Video Out converts the test pattern stream to parallel video

5. **HDMI Encoding**: The rgb2dvi IP serializes the parallel RGB data into TMDS-encoded differential pairs

## Test Patterns

The test pattern generator can produce various patterns. To change patterns, you'll need to add AXI4-Lite control or modify the IP configuration in the build script.

Default pattern: Color bars

## Customization

### Change Resolution

To use a different resolution, modify the Video Timing Controller parameters in `build.tcl` and adjust the clock frequencies accordingly.

Common resolutions:
- 720p@60Hz: 74.25 MHz pixel clock
- 1080p@60Hz: 148.5 MHz pixel clock (current)
- 1080p@30Hz: 74.25 MHz pixel clock

### Use Custom Video Source

Replace the Video Test Pattern Generator with your own video source that outputs AXI4-Stream video data.

## Troubleshooting

- **No video output**: Check that the clocks are locked (PLL locked signal)
- **Wrong colors**: Verify the RGB channel ordering in the constraints
- **Timing violations**: May need to adjust clock constraints or use different clock primitives
- **Monitor not detecting signal**: Ensure clock frequencies match the HDMI spec exactly

## Notes

- The Digilent rgb2dvi IP must be installed from the Digilent IP repository
- The project uses block design for easy IP integration
- The test pattern generator is useful for initial testing before adding custom video logic
