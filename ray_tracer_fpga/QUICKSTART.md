# Quick Start Guide - FPGA Ray Tracer

## Prerequisites Checklist

- [ ] Nexys Video board connected via USB
- [ ] VGA monitor connected (via VGA Pmod on FMC connector)
- [ ] Xilinx Vivado installed (2020.1 or later)
- [ ] Digilent board files installed

## Build and Run (5 Steps)

### 1. Navigate to Project
```bash
cd ~/fpga_projects/ray_tracer_fpga
```

### 2. Build the Project
```bash
vivado -mode batch -source build.tcl
```
⏱️ This takes 15-30 minutes. Get coffee! ☕

### 3. Check Build Success
Look for this message:
```
Build complete! Bitstream location: build/ray_tracer_fpga.runs/impl_1/top_module.bit
```

### 4. Program the FPGA
```bash
vivado -mode batch -source program.tcl
```

### 5. Watch the Magic! ✨
Your VGA monitor should show:
- 3 colored spheres (blue, orange, yellow)
- Black background
- Real-time rendering

## Expected LED Indicators

After programming:
- **LED[0]**: Blinking/On - Rendering active
- **LED[1]**: On - Clocks locked
- **LED[2]**: Blinking - Video active region

## Troubleshooting

### Build Fails
```bash
# Check Vivado installation
vivado -version

# Review build log
tail -n 100 vivado.log
```

### No VGA Output
1. Verify LED[1] is ON (clocks locked)
2. Check VGA cable connections
3. Try pressing CPU_RESETN button
4. Verify monitor supports 640x480@60Hz

### "Device not found" when programming
1. Check USB cable to Nexys Video
2. Turn board power ON
3. Try: `dmesg | tail` to see if USB device detected

## Performance Metrics

| Metric | Value |
|--------|-------|
| Resolution | 640x480 (native VGA) |
| Pixel Clock | 25.175 MHz |
| Ray Tracer Clock | 50 MHz |
| Frame Render Time | ~30.72ms |
| Max Frame Rate | ~32 FPS |

## Next Steps

Want to customize the scene? Edit these files:

1. **Sphere positions/colors**: `src/hdl/ray_tracer_core.vhd` (lines 43-68)
2. **Camera position**: `src/hdl/ray_tracer_core.vhd` (lines 36-38)
3. **Light position**: `src/hdl/ray_tracer_core.vhd` (lines 70-73)
4. **Resolution**: Already at max 640x480 (native VGA)

After changes, rebuild with:
```bash
vivado -mode batch -source build.tcl
vivado -mode batch -source program.tcl
```

## Files You Care About

```
ray_tracer_fpga/
├── build.tcl                    # ← Build everything
├── program.tcl                  # ← Program FPGA
├── README.md                    # ← Full documentation
├── QUICKSTART.md               # ← This file
└── src/
    ├── hdl/
    │   ├── top_module.vhd       # ← Main system
    │   ├── ray_tracer_core.vhd # ← Ray tracing engine
    │   └── vga_controller.vhd   # ← VGA timing
    └── constraints/
        └── constraints.xdc      # ← Pin mappings
```

## Common Commands

```bash
# Full rebuild
cd ~/fpga_projects/ray_tracer_fpga
vivado -mode batch -source build.tcl
vivado -mode batch -source program.tcl

# Just reprogram (no rebuild)
vivado -mode batch -source program.tcl

# Open in GUI (for debugging)
vivado build/ray_tracer_fpga.xpr &

# Clean build
rm -rf build/ .Xil/ *.log *.jou
```

## Getting Help

1. Check `README.md` for detailed documentation
2. Review `build/timing_summary.rpt` for timing issues
3. Review `build/utilization.rpt` for resource usage
4. Check Vivado log files: `vivado.log`

## Architecture at a Glance

```
100 MHz → Clock Wizard → 25.175 MHz (VGA) + 50 MHz (Ray Tracer)
                                ↓                    ↓
                          VGA Controller ← Framebuffer ← Ray Tracer
                                ↓
                          Your Monitor!
```

The ray tracer:
1. Generates rays for each pixel
2. Tests intersection with 3 spheres
3. Computes lighting
4. Writes RGB to framebuffer
5. VGA displays framebuffer continuously

---

**Note**: This is a simplified fixed-point implementation. The full floating-point math pipeline using Xilinx IP cores is set up but not fully integrated yet. This allows the design to synthesize quickly for initial testing. See README.md for enhancement roadmap.

🚀 **Happy Ray Tracing!** 🚀
