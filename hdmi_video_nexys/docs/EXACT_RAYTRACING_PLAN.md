# Exact Ray-Sphere Intersection with Parallelization

## Problem Statement
Current approximation approach works but isn't mathematically accurate. Sequential FP approach would be too slow (0.22 FPS). Need exact ray-sphere intersection at acceptable frame rates.

## Solution: Parallel Pixel Processing
Instead of computing one pixel at a time sequentially, compute multiple pixels in parallel. Each pixel gets its own ray-sphere intersection pipeline.

## Current State
* Framebuffer architecture already exists (640×480 dual-port RAM)
* Ray tracer runs at 50 MHz, display at 25.175 MHz
* FP IP cores available: mult (8 cyc), add (11 cyc), sqrt (28 cyc), div (28 cyc), compare (2 cyc)
* Current: ~15 cycles/pixel with approximation

## Performance Analysis

### Sequential (Not Feasible)
* ~250 cycles per sphere intersection
* 3 spheres × 250 = 750 cycles/pixel
* 640×480 pixels = 307,200 pixels
* Total: 230M cycles @ 50 MHz = 4.6 seconds/frame (0.22 FPS)

### Parallel - 4 Pixels Simultaneously
* Each pixel takes 250 cycles, but 4 run in parallel
* Effective: 250 cycles per 4 pixels = 62.5 cycles/pixel
* 307,200 pixels ÷ 4 = 76,800 pixel groups
* 76,800 × 250 = 19.2M cycles @ 50 MHz = 0.38 seconds/frame (**2.6 FPS**)
* Need 4× the FP IP cores

### Parallel - 8 Pixels Simultaneously  
* Effective: 250 cycles per 8 pixels = 31.25 cycles/pixel
* 307,200 ÷ 8 = 38,400 pixel groups
* 38,400 × 250 = 9.6M cycles @ 50 MHz = 0.19 seconds/frame (**5.3 FPS**)
* Need 8× the FP IP cores

### Parallel - 16 Pixels Simultaneously
* Effective: 250 cycles per 16 pixels = 15.6 cycles/pixel  
* 307,200 ÷ 16 = 19,200 pixel groups
* 19,200 × 250 = 4.8M cycles @ 50 MHz = 0.096 seconds/frame (**10.4 FPS**)
* Need 16× the FP IP cores

## Proposed Implementation: 8-Way Parallelism

### Architecture
* 8 parallel ray-sphere intersection units
* Each unit has full FP pipeline for one pixel
* Shared sphere data (centers, radii, colors)
* Coordinator distributes pixels round-robin to units
* Results written to framebuffer when complete

### Resource Requirements (per unit)
* 4× fp_mult (dot products, quadratic terms)
* 2× fp_add (vector ops, discriminant)  
* 1× fp_sqrt (discriminant)
* 1× fp_div (final t calculation)
* 1× fp_compare (discriminant check)

### Total FP IP Cores Needed
* 32× fp_mult
* 16× fp_add
* 8× fp_sqrt
* 8× fp_div
* 8× fp_compare

### LUT Estimate
* Each FP unit: ~500-1000 LUTs
* Total FP cores: ~72 units × 750 LUTs avg = **54K LUTs**
* Artix-7 200T has 134K LUTs → **40% utilization** (feasible)

## Optimization: Bounding Box Culling

### Concept
Before doing expensive ray-sphere intersection, do fast bounding box test:
* Project sphere onto screen space
* Compute 2D bounding box (min/max X and Y)
* Only test intersection if pixel is inside bounding box
* **Saves ~60-80% of intersection tests** for typical scenes

### Screen-Space Bounding Box Calculation
For sphere at center C with radius r:
1. Project center to screen space
2. Add/subtract radius in screen space
3. Bounding box: `[center_x - r, center_x + r] × [center_y - r, center_y + r]`

### Implementation
* Pre-compute bounding boxes at start (spheres don't move)
* Store 3 bounding boxes (min_x, max_x, min_y, max_y) per sphere
* Fast integer comparison: **1-2 cycles per sphere**
* If pixel outside bbox: skip expensive FP intersection

### Performance Impact
**With bounding boxes**:
* Bbox check: 2 cycles per sphere × 3 = 6 cycles
* Only ~20-40% pixels actually hit spheres → do full intersection
* Average: 6 + (0.3 × 250) = **~80 cycles/pixel** (down from 750!)
* **9× speedup over no culling**

**8-way parallel with bbox culling**:
* 80 cycles/pixel effective
* 307,200 ÷ 8 = 38,400 groups
* 38,400 × 80 = 3M cycles @ 50 MHz = 0.06 sec/frame
* **~17 FPS!** (vs 5.3 FPS without bbox)

## Implementation Steps

### Step 1: Create Bounding Box Module
* Compute screen-space bbox for each sphere
* Fast integer comparison against pixel coordinates
* Output: which spheres to test (3-bit mask)
* File: `bbox_culling.vhd`

### Step 2: Create Pipelined Ray-Sphere Intersection Unit
* Implement complete quadratic formula with FP ops
* State machine with proper pipelining
* 3-stage design: compute L, compute discriminant, compute t
* Handle all 3 spheres for one pixel
* Only runs for spheres that pass bbox test
* File: `ray_sphere_intersect_pipelined.vhd`

### Step 3: Create Parallel Coordinator  
* Manages 8 intersection units
* Distributes pixels round-robin
* Tracks which units are busy/free
* Collects results and writes to framebuffer
* File: `parallel_ray_coordinator.vhd`

### Step 4: Update Top Module
* Instantiate 8 intersection units
* Connect to parallel coordinator
* Keep existing framebuffer architecture
* Update ray generation for proper perspective
* File: update `top_module_raytracer.vhd`

### Step 5: Create FP IP Cores
* Generate 32 fp_mult instances
* Generate 16 fp_add instances
* Generate 8 fp_sqrt, fp_div, fp_compare instances
* Update create_fp_ips.tcl script

### Step 6: Improve Ray Generation
* Convert pixel X/Y coordinates to proper FP values
* Compute actual ray directions with perspective
* Use FP operations or lookup tables
* File: `ray_generator.vhd`

### Step 7: Build and Test
* Update build scripts
* Synthesize and check resource utilization
* Test on hardware
* Verify actual frame rate

## Expected Results

### Visual Quality
* **Exact circular spheres** (not approximations)
* Smooth edges
* Proper mathematical intersections
* Correct depth/occlusion

### Performance  
* Target: **15-20 FPS** with 8-way parallelism + bbox culling
* Without bbox: **5-10 FPS**
* Actual will depend on pipeline efficiency
* May need tuning/optimization

### Resource Usage
* ~50-60K LUTs (40-45% of Artix-7 200T)
* BRAM for framebuffer (already used)
* DSPs for FP operations (~100-150 DSPs)

## Alternative: Start with 4-Way Parallelism

If resource usage is concern, start with 4 parallel units:
* Half the IP cores (36 total FP units)
* ~27K LUTs (20% utilization)  
* **~9 FPS** with bbox culling (vs 2.6 FPS without)
* Easier to debug
* Can scale to 8-way later

## Risk Mitigation

### Timing Closure
* 50 MHz should be achievable with FP IPs
* May need pipeline registers between stages
* FP IPs already designed for high-speed operation

### Resource Constraints
* Monitor synthesis utilization reports
* Can reduce parallelism if needed (4-way fallback)
* DSP usage might be limiting factor

### Debugging
* Start with 1 unit working correctly
* Add parallelism incrementally (1→2→4→8)
* Use ILA (Integrated Logic Analyzer) to debug

## Implementation Strategy

### Phase 1: Single Unit with Exact Math
1. Create bbox culling module
2. Create single pipelined intersection unit
3. Integrate with existing framebuffer
4. Test: should see perfect circular spheres (slow, ~0.22 FPS)

### Phase 2: 4-Way Parallelism
5. Replicate intersection unit 4×
6. Create coordinator for 4 units
7. Generate additional FP IP cores
8. Test: should see ~9 FPS with perfect spheres

### Phase 3: 8-Way Parallelism (if resources allow)
9. Scale to 8 units
10. Update coordinator
11. Generate more FP IP cores
12. Test: should see ~17 FPS

## Summary

**Key Innovation**: Bounding box culling + parallel processing

**Performance Gains**:
* Bbox culling: **9× faster** (eliminates most FP calculations)
* 8-way parallel: **8× faster** (simultaneous pixel processing)
* Combined: **~70× faster** than naive sequential approach
* Final: **0.22 FPS → 17 FPS** (77× improvement!)

**Trade-offs**:
* Higher resource usage (50-60K LUTs vs current ~5K)
* More complex design
* More FP IP cores needed
* Worth it for exact, real-time ray tracing!
