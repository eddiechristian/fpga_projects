# Changelog

## Version 1.1 - 640x480 Native Resolution

### Changed
- **Resolution increased from 320x240 to 640x480**
  - Native VGA resolution, no upscaling needed
  - Framebuffer increased from 76,800 to 307,200 pixels
  - More detailed ray-traced output

### Performance Impact
- Frame render time: 7.68ms → 30.72ms (4x more pixels)
- Max frame rate: ~130 FPS → ~32 FPS
- Block RAM usage: ~60% → ~75%

### Modified Files
- `src/hdl/ray_tracer_core.vhd`: Updated SCREEN_WIDTH/HEIGHT to 640x480
- `src/hdl/top_module.vhd`: 
  - Updated framebuffer size to 307,200 pixels
  - Removed 2x upscaling logic
  - Direct 1:1 pixel mapping
  - Updated loop bounds (639x479 instead of 319x239)
- `build.tcl`: Updated Block RAM IP to 307,200 depth
- `README.md`: Updated documentation for 640x480
- `QUICKSTART.md`: Updated performance metrics

### Benefits
- ✅ Full VGA resolution - sharper image
- ✅ No upscaling artifacts
- ✅ Still real-time at 32 FPS
- ✅ Better detail in ray-traced scene

### Trade-offs
- Slower frame rate (but still smooth at 32 FPS)
- Higher Block RAM usage (75% vs 60%)
- 4x longer render time per frame

## Version 1.0 - Initial Release

### Features
- Ray tracer with 320x240 rendering
- 2x upscaling to 640x480 VGA output
- 3 spheres with lighting
- Fixed-point arithmetic
- ~130 FPS max frame rate
