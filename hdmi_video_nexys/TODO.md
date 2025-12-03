# TODO: HDMI Ray Tracer Project

## Current Status
- ✅ HDMI output working at 640x480@60Hz using Digilent rgb2dvi IP
- ✅ Color channel mapping figured out (RBG order for vid_data)
- ✅ Ray tracer core integrated and running
- ✅ Framebuffer (640x480x12) working correctly
- ✅ Sphere detection working (shows as vertical bars)
- ⚠️ Sphere intersection math simplified - needs proper implementation

## Issues to Fix

### 1. Sphere Ray Tracing Math
**Problem**: Spheres render as vertical bars instead of circles
**Root Cause**: Simplified intersection calculation without proper square root
**Location**: `src/hdl/ray_tracer_core.vhd` lines 158-256 (TEST_SPHERE1/2/3 states)

**Current approach**:
```vhdl
t := -b(31 downto 0);  -- Approximation, no sqrt
```

**Need to implement**:
```
t = (-b - sqrt(discriminant)) / (2*a)
```

**Solution**: Use Xilinx Floating Point IP cores
- More accurate than fixed-point approximations
- Easier to write and maintain code
- Uses DSP slices and BRAM but we have resources available
- Need to add: FP Multiplier, FP Adder, FP Divider, FP Square Root IPs

### 2. Ray Direction Calculation
**Location**: `src/hdl/ray_tracer_core.vhd` lines 130-154 (GENERATE_RAY state)

Current ray direction only varies significantly in X:
```vhdl
ray_dir_x <= norm_x(31 downto 2) & "00";  -- * 0.25
ray_dir_y <= ONE_FP;  -- Always forward
ray_dir_z <= norm_y(31 downto 2) & "00";  -- * 0.25
```

This causes spheres to appear as vertical slices. Need proper 3D ray direction that varies in both X and Y.

### 3. Camera/View Setup
**Current setup**:
- Camera at (0, -10, 0)
- Looking in +Y direction
- Simplified field of view

**To improve**:
- Add proper aspect ratio correction
- Implement proper FOV angle
- Add camera rotation/orientation matrix

## Features to Add

### 4. Lighting
Currently using placeholder lighting:
```vhdl
light_intensity <= x"80";  -- Fixed 50%
```

**Need**:
- Calculate surface normal at hit point
- Compute light vector from hit point to light source
- Implement dot product for diffuse lighting
- Add ambient + diffuse components

### 5. Multiple Spheres Rendering
Currently has 3 spheres defined but intersection logic needs refinement for proper occlusion and depth testing.

### 6. Performance Optimization
**Current**: ~32 FPS (renders 640x480 = 307,200 pixels sequentially)
**Improvements**:
- Pipeline the ray tracer states
- Add multiple ray tracer cores in parallel
- Optimize fixed-point operations
- Reduce clock cycles per pixel

### 7. Additional Features (Future)
- [ ] Add more sphere primitives
- [ ] Implement plane intersection (ground plane)
- [ ] Add shadows (secondary rays)
- [ ] Add reflections
- [ ] Implement anti-aliasing (multi-sampling)
- [ ] Add interactive controls (buttons/switches to move camera/objects)
- [ ] Texture mapping
- [ ] Higher resolution (requires external memory or reduced color depth)

## Build System

### 8. Current Build Scripts
- `build_raytracer.tcl` - Full rebuild (regenerates all IP)
- `build_quick.tcl` - Fast rebuild (reuses IP cores) ✅

### 9. Programming
Bitstream location: `build/hdmi_video_nexys.runs/impl_1/top_module_raytracer.bit`

## Documentation Needs

### 10. Add README sections
- [ ] Document color channel mapping discovery process
- [ ] Explain framebuffer architecture
- [ ] Document clock domains (25.175 MHz pixel, 50 MHz ray tracer)
- [ ] Add timing diagrams
- [ ] Document resource utilization

### 11. Code Comments
- [ ] Add more detailed comments to ray_tracer_core.vhd
- [ ] Document fixed-point format and conversions
- [ ] Explain state machine flow

## Testing

### 12. Test Patterns Implemented
- ✅ Solid color bars (RGB)
- ✅ Coordinate-based gradient
- ✅ Simple sphere detection

### 13. Tests to Add
- [ ] Verify all 307,200 pixels render correctly
- [ ] Test framebuffer with known patterns
- [ ] Validate clock domain crossing
- [ ] Test reset behavior
- [ ] Measure actual frame rate

## Known Issues
1. Timing violations on pulse width (WPWS = -0.808ns) - not critical but should investigate
2. Some synthesis warnings about unused signals - clean up
3. Ray tracer only uses lower 4-6 bits of pixel coordinates - need full 10-bit precision

## References
- Digilent rgb2dvi IP: Uses RBG color order (bits [23:16]=R, [15:8]=B, [7:0]=G)
- VGA timing: 640x480@60Hz = 25.175 MHz pixel clock
- Original ray_tracer_fpga project: `../ray_tracer_fpga/`
- Working color bar test: `src/hdl/top_module_simple.vhd`
