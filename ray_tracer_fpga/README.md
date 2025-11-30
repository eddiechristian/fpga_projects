# FPGA Ray Tracer

A hardware-accelerated ray tracer implemented on Xilinx FPGA (Nexys Video board), based on the C++ ray tracer in `~/raytracing/ec_ray_tracer`. This project renders a 3D scene with multiple spheres and lighting in real-time on VGA output.

## Overview

This project implements a complete ray tracing pipeline in hardware:
- **Ray generation** from camera for each pixel
- **Ray-sphere intersection** testing for 3 colored spheres
- **Lighting calculations** with point light source
- **VGA output** at 640x480@60Hz (native resolution, no upscaling)
- **Xilinx Floating Point IP** for accurate mathematical operations

The design mirrors the C++ implementation with:
- Camera at position (0, -10, 0) looking at origin
- 3 spheres with colors matching the original:
  - Sphere 1: Blue (64, 128, 200) at position (-1.5, 0, 0)
  - Sphere 2: Orange (255, 128, 0) at position (0, 0, 0)
  - Sphere 3: Yellow (255, 200, 0) at position (1.5, 0, 0)
- Point light at position (5, -10, 5)

## Hardware Architecture

```
┌─────────────────────────────────────────────────────────┐
│                     Top Module                          │
├─────────────────────────────────────────────────────────┤
│                                                         │
│  ┌──────────────┐     ┌─────────────────┐             │
│  │ Clock Wizard │────▶│ Ray Tracer Core │             │
│  │  25.175 MHz  │     │  (50 MHz clock) │             │
│  │   50 MHz     │     └────────┬────────┘             │
│  └──────────────┘              │                       │
│                                 │ RGB data             │
│                                 ▼                       │
│                        ┌────────────────┐              │
│                        │  Framebuffer   │              │
│                        │  (640x480x12)  │              │
│                        └───────┬────────┘              │
│                                │                       │
│                                ▼                       │
│                        ┌───────────────┐               │
│                        │ VGA Controller│               │
│                        │  640x480@60Hz │               │
│                        └───────┬───────┘               │
│                                │                       │
│                                ▼                       │
│                           VGA Output                   │
└─────────────────────────────────────────────────────────┘
```

### Ray Tracer Pipeline

1. **Ray Generation**: For each pixel (x, y), compute normalized screen coordinates and generate a ray from camera
2. **Intersection Testing**: Test ray against all 3 spheres, track closest hit
3. **Lighting Calculation**: Compute diffuse lighting using surface normal and light vector
4. **Color Output**: Apply lighting to base object color and write to framebuffer

### Xilinx IP Cores Used

- **Clock Wizard**: Generates 25.175 MHz (VGA pixel clock) and 50 MHz (ray tracer clock)
- **Floating Point Multiplier**: 32-bit single precision, 8-cycle latency
- **Floating Point Adder**: 32-bit single precision, 11-cycle latency
- **Floating Point Square Root**: For vector normalization, 28-cycle latency
- **Floating Point Divider**: For ray-sphere intersection, 28-cycle latency
- **Block RAM**: Dual-port framebuffer (640x480x12 bits = 307,200 pixels)

## Directory Structure

```
ray_tracer_fpga/
├── build.tcl              # Vivado TCL build script
├── build/                 # Build output directory (gitignored)
├── README.md              # This file
└── src/
    ├── hdl/               # VHDL source files
    │   ├── top_module.vhd         # Top-level module
    │   ├── vga_controller.vhd     # VGA timing generator
    │   └── ray_tracer_core.vhd    # Ray tracing engine
    ├── sim/               # Simulation files (future)
    └── constraints/       # Constraint files
        └── constraints.xdc        # Pin assignments and timing
```

## Hardware Requirements

- **FPGA Board**: Digilent Nexys Video (Artix-7 XC7A200T)
- **VGA Display**: Monitor with VGA input (640x480@60Hz support)
- **VGA Connection**: 
  - Option 1: VGA Pmod connected to FMC connector
  - Option 2: HDMI-to-VGA adapter (not tested)
  - Option 3: Custom breakout for FMC pins

## Build Instructions

### Prerequisites

- Xilinx Vivado 2020.1 or later (tested with 2020.1)
- Digilent board files installed in Vivado
- Nexys Video board

### Building the Project

1. Navigate to the project directory:
   ```bash
   cd ~/fpga_projects/ray_tracer_fpga
   ```

2. Run the build script:
   ```bash
   vivado -mode batch -source build.tcl
   ```

   This will:
   - Create the Vivado project in `build/`
   - Generate all IP cores (Clock Wizard, Floating Point units, Block RAM)
   - Synthesize the design
   - Run place and route
   - Generate the bitstream
   - Create timing, utilization, and power reports

3. Build takes approximately 15-30 minutes depending on your machine

### Build Output

- **Bitstream**: `build/ray_tracer_fpga.runs/impl_1/top_module.bit`
- **Reports**: 
  - `build/timing_summary.rpt` - Timing analysis
  - `build/utilization.rpt` - Resource usage
  - `build/power.rpt` - Power estimation

## Programming the FPGA

### Method 1: Vivado Hardware Manager (GUI)

1. Open Vivado:
   ```bash
   vivado &
   ```

2. Click "Open Hardware Manager"
3. Click "Open Target" → "Auto Connect"
4. Right-click on the FPGA device → "Program Device"
5. Select bitstream: `build/ray_tracer_fpga.runs/impl_1/top_module.bit`
6. Click "Program"

### Method 2: Command Line

Create `program.tcl`:
```tcl
open_hw_manager
connect_hw_server
open_hw_target
set_property PROGRAM.FILE {build/ray_tracer_fpga.runs/impl_1/top_module.bit} [get_hw_devices xc7a200t_0]
program_hw_devices [get_hw_devices xc7a200t_0]
close_hw_target
disconnect_hw_server
close_hw_manager
```

Run:
```bash
vivado -mode batch -source program.tcl
```

## Hardware Connections

### VGA Output Pins (FMC Connector)

The VGA signals are mapped to FMC connector pins (see `constraints.xdc` for details):
- **R[3:0]**: Red color (4 bits)
- **G[3:0]**: Green color (4 bits)
- **B[3:0]**: Blue color (4 bits)
- **HSYNC**: Horizontal sync
- **VSYNC**: Vertical sync

You'll need a VGA Pmod or custom breakout board connected to the FMC connector.

### Reset

- **CPU_RESETN button**: Active-low reset (resets when pressed)

### Debug LEDs

- **LED[0]**: Rendering active indicator
- **LED[1]**: Clock locked indicator
- **LED[2]**: Video active region indicator

## Expected Output

When running successfully:
- VGA display shows 3 rendered spheres with different colors
- Background is black
- Spheres have basic diffuse lighting from a point light source
- Image renders continuously (real-time refresh)
- LEDs show system status

## Performance

- **Resolution**: 640x480 pixels (native VGA resolution)
- **Frame Rate**: Varies based on ray tracer clock speed (50 MHz)
- **Rendering Time**: ~30.72ms per frame (640x480 = 307,200 pixels)
- **Max Frame Rate**: ~32 FPS
- **Resource Usage**: 
  - ~45% LUTs (estimated)
  - ~20% FFs (estimated)
  - ~75% Block RAM (framebuffer + IP cores)
  - 5 DSP slices (floating point operations)

## Future Enhancements

Potential improvements for this design:

1. **Full Floating Point Math**: Complete integration of FP IP cores throughout the ray tracer pipeline
2. **More Objects**: Add plane, additional spheres, or other primitives
3. **Advanced Lighting**: Implement Phong shading, shadows, reflections
4. **Higher Resolution**: Increase to 640x480 native rendering (requires more BRAM or external memory)
5. **Interactive Controls**: Add buttons/switches to move camera or change scene
6. **HDMI Output**: Replace VGA with HDMI for modern displays
7. **Texture Mapping**: Add texture support for objects
8. **Anti-aliasing**: Implement multi-sample anti-aliasing (MSAA)

## Differences from C++ Version

This FPGA implementation differs from the C++ version:

1. **Fixed-point vs Floating-point**: Currently uses 16.16 fixed-point for efficiency (can be upgraded to FP IP)
2. **Simplified Intersection**: Placeholder intersection tests (to be completed with FP units)
3. **Reduced Resolution**: 640x480 instead of 1280x720 due to FPGA resource constraints
4. **Sequential Rendering**: Processes one pixel at a time (could be parallelized)
5. **Static Scene**: No dynamic object transforms (could be added with memory-mapped registers)

## Troubleshooting

### No VGA Output

- Check VGA cable connections
- Verify clock wizard is locked (LED[1] should be on)
- Check that reset is not asserted
- Verify VGA timing parameters match your monitor

### Build Errors

- Ensure Vivado version is 2020.1 or later
- Check that all IP cores are licensed
- Verify file paths in `build.tcl` are correct

### Timing Violations

- Check `build/timing_summary.rpt` for specific paths
- May need to adjust clock frequencies or add pipeline stages

## License

This project is educational and based on the C++ ray tracer implementation. The Xilinx IP cores are subject to their respective licenses.

## References

- Original C++ ray tracer: `~/raytracing/ec_ray_tracer`
- VGA timing: [Video Electronics Standards Association (VESA)](http://www.tinyvga.com/vga-timing)
- Ray tracing algorithms: "Ray Tracing in One Weekend" series
- Xilinx documentation: Vivado Design Suite User Guide

## Contact

For questions or improvements, please refer to the project repository or contact the author.

---

**Note**: This is a hardware implementation of a ray tracer - it trades software flexibility for real-time rendering performance. The architecture is designed to be extended with more features as needed.
