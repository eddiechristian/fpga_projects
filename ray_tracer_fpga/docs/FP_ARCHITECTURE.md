# Floating Point Architecture Trade-offs

## Sequential vs. Parallel FP Units

### Sequential Approach (Time-Multiplexed)
**Concept**: Reuse the same FP units for multiple operations by scheduling them over time.

```
Example: Computing dot product (a·b = a.x*b.x + a.y*b.y + a.z*b.z)

With 1 Multiplier, 1 Adder:
Cycle 1-8:    mult_result = a.x * b.x
Cycle 9-19:   add_result = 0 + mult_result  
Cycle 20-27:  mult_result = a.y * b.y
Cycle 28-38:  add_result = add_result + mult_result
Cycle 39-46:  mult_result = a.z * b.z
Cycle 47-57:  add_result = add_result + mult_result
Total: 57 cycles
```

**Resources**: 1 mult + 1 add = ~750 LUTs, ~1,200 FFs, 5 DSPs

### Parallel Approach (Spatial Parallelism)
**Concept**: Dedicate separate FP units for independent operations that can run simultaneously.

```
Same dot product with 3 Multipliers, 2 Adders (pipelined):

Cycle 1-8:    mult0 = a.x * b.x  |  mult1 = a.y * b.y  |  mult2 = a.z * b.z
Cycle 9-19:   add0 = mult0 + mult1  |  (mult2 ready)
Cycle 20-30:  add1 = add0 + mult2
Total: 30 cycles
```

**Resources**: 3 mult + 2 add = ~2,250 LUTs, ~3,600 FFs, 15 DSPs

**Speedup**: 1.9x faster, but uses 3x more resources

---

## How Many Parallel Units Do You Need?

The answer depends on **critical path analysis** - what operations must happen sequentially vs. what can overlap.

### Ray-Sphere Intersection (Analytical Method)

```
Given: Ray (origin O, direction D), Sphere (center C, radius r)

Solve: |O + t*D - C|² = r²

Steps:
1. L = O - C                           [3 subtracts]
2. a = D · D                           [3 mults, 2 adds] - dot product
3. b = 2 * (L · D)                     [3 mults, 2 adds, 1 mult] - dot product + scale
4. c = (L · L) - r²                    [3 mults, 2 adds, 1 mult, 1 sub] - dot product
5. discriminant = b² - 4*a*c           [1 mult, 2 mults, 1 sub]
6. if (discriminant < 0) no hit
7. t = (-b - sqrt(discriminant))/(2*a) [1 sqrt, 1 neg, 1 sub, 1 mult, 1 div]
8. hit_point = O + t*D                 [3 mults, 3 adds]
9. normal = (hit_point - C) / r        [3 subs, 3 divs or 1 div + 3 mults]
```

### Critical Path Analysis

**Dependencies** (must be sequential):
- Step 2,3,4 depend on Step 1
- Step 5 depends on Steps 2,3,4
- Step 7 depends on Step 5
- Step 8 depends on Step 7
- Step 9 depends on Step 8

**Parallelism Opportunities**:
- Steps 2, 3, 4 are INDEPENDENT - can compute in parallel
- Within each dot product, 3 multiplies are INDEPENDENT
- Final adds in dot products must be sequential (tree reduction)

### Optimal Configuration for Ray-Sphere

```
Option A: Sequential (2 mult, 2 add, 1 sqrt, 1 div)
- Compute one operation at a time
- ~120-150 cycles per sphere intersection
- 3 spheres × 150 cycles = 450 cycles/pixel
- Resources: ~3,500 LUTs, ~5,500 FFs, 8 DSPs

Option B: Moderate Parallel (4 mult, 3 add, 1 sqrt, 1 div)
- Compute multiple dot products simultaneously
- ~50-60 cycles per sphere intersection  
- 3 spheres × 60 cycles = 180 cycles/pixel
- Resources: ~5,000 LUTs, ~7,500 FFs, 18 DSPs

Option C: Highly Parallel (8 mult, 4 add, 1 sqrt, 1 div)
- Maximum parallelism for ray tracing math
- ~40-50 cycles per sphere intersection
- 3 spheres × 50 cycles = 150 cycles/pixel
- Resources: ~7,000 LUTs, ~10,000 FFs, 30 DSPs
```

**Recommendation**: **Option B** - Sweet spot of performance vs. resources

---

## Scalability: Adding Features

### Adding More Objects

**Sequential**: No extra FP units needed
- Just loop through more objects
- N spheres = N × cycles_per_sphere
- 10 spheres: 600 cycles/pixel vs. 180 cycles/pixel

**Parallel**: No extra FP units needed
- Same FP units, more iterations
- Linear increase in render time
- Still faster than sequential

**Takeaway**: Number of objects doesn't change FP unit count, just increases computation time.

### Adding Textures

Texture mapping requires:
```
1. UV coordinate calculation:
   - Convert hit point to spherical coordinates
   - 2 atan2 operations OR lookup table
   - ~50-100 cycles with FP

2. Texture fetch:
   - Block RAM lookup (1-2 cycles)
   - Bilinear interpolation (4 reads, 4 mults, 3 adds)
   - ~20 cycles with existing FP units

3. Color modulation:
   - Multiply texture color × object color
   - 3 multiplies (~8 cycles, reuse existing units)
```

**Impact**: 
- Adds ~70-120 cycles per hit
- No new FP units needed
- Requires texture Block RAM (~50-100 BRAM blocks for 512×512 texture)

**Resource Budget**:
- Current BRAM: 274/365 (75%)
- With one 512×512×12-bit texture: ~350/365 (96%)
- Room for 1-2 textures before BRAM limit

### Adding Reflections

```
For each reflection level:
1. Compute reflection ray: R = D - 2(D·N)N  [6 mults, 6 adds, 1 mult]
2. Trace new ray (same as primary ray)
3. Blend colors with Fresnel term [3-4 mults]

Recursion levels:
- Level 1: Primary ray only
- Level 2: +1 reflection (2× ray traces)
- Level 3: +reflection of reflection (4× ray traces)
```

**Impact**:
- 2× ray traces with reflection = 2× computation time
- No new FP units needed (reuse pipeline)
- Recursive calls handled by state machine

### Adding Shadows

```
For each light:
1. Compute shadow ray: origin=hit_point, direction=to_light
2. Test intersection with ALL objects
3. If any hit before light, in shadow

With 3 spheres, 1 light:
- Primary ray: 3 sphere tests
- Shadow ray: 3 sphere tests  
Total: 6 sphere tests per visible pixel
```

**Impact**:
- 2× sphere intersection tests
- No new FP units needed
- ~360 cycles/pixel vs. 180 cycles/pixel

---

## Resource Scaling Table

| Feature | Sequential FP | Moderate Parallel | Highly Parallel | BRAM Impact |
|---------|---------------|-------------------|-----------------|-------------|
| **Base (3 spheres)** | 450 cyc/px | 180 cyc/px | 150 cyc/px | 75% |
| **+7 more spheres (10 total)** | 1,500 cyc/px | 600 cyc/px | 500 cyc/px | 75% |
| **+1 texture** | +120 cyc/px | +70 cyc/px | +70 cyc/px | 96% |
| **+1 reflection level** | ×2 time | ×2 time | ×2 time | 75% |
| **+shadows (1 light)** | ×2 time | ×2 time | ×2 time | 75% |
| **All features** | ~6,000 cyc/px | ~2,400 cyc/px | ~2,000 cyc/px | 96% |

### Frame Rate Impact (640×480 @ 50MHz)

| Configuration | Cycles/Frame | FPS |
|---------------|--------------|-----|
| Base (Moderate Parallel) | 55M | 0.9 FPS |
| +10 spheres | 184M | 0.27 FPS |
| +10 spheres +texture | 205M | 0.24 FPS |
| +10 spheres +texture +reflections | 410M | 0.12 FPS |

**Note**: These are still-image frame rates. For interactive rendering, you'd need:
- Lower resolution (320×240)
- Faster clock (100 MHz)
- Tile-based rendering
- Or multiple parallel ray tracers

---

## Recommended Architecture

### **Moderate Parallel with Sequencing FSM**

```
FP Units (Shared Pipeline):
- 4× Multiplier (can do 4 parallel mults)
- 3× Adder (tree reduction)
- 1× Divider (reused as needed)
- 1× Sqrt (reused as needed)
- 1× Compare (cheap, for discriminant test)

Resources: ~5,000 LUTs, 18 DSPs (still only 3.7% of LUTs, 2.4% of DSPs)
```

**Why This Works**:
1. **Dot products parallelized** - fastest operation in ray tracing
2. **Sqrt/Div reused** - infrequent operations, don't need multiple copies
3. **Scales with features** - adding spheres/textures/shadows just adds time, not hardware
4. **Future-proof** - Can add reflections, shadows, textures without redesign

### Clock Speed Alternative

Instead of more parallel units, consider **increasing clock speed**:
- Current: 50 MHz → 100 MHz = 2× faster (no extra resources!)
- Artix-7 easily runs at 100-150 MHz for this design
- Simplest performance boost

---

## Summary

**Number of parallel FP units depends on**:
1. ✅ **Pipeline efficiency** - Can operations overlap?
2. ✅ **Critical path** - What must be sequential?
3. ❌ **NOT** number of objects (just adds iterations)
4. ❌ **NOT** textures (uses BRAM, reuses FP units)
5. ❌ **NOT** reflections (reuses ray tracer pipeline)

**Best approach**: 
- Start with **moderate parallel (4 mult, 3 add)**
- Increase **clock speed** if you need more performance
- Add features without changing FP architecture
- Save resources for BRAM (textures, framebuffer)

**Your Artix-7 can handle**:
- ✅ Full floating point math
- ✅ 10-20 spheres
- ✅ 1-2 textures  
- ✅ Reflections
- ✅ Shadows
- ✅ All at native 640×480 resolution

The limit is **computation time**, not hardware resources!
