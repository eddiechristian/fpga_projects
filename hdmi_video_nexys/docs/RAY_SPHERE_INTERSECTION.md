# Ray-Sphere Intersection Algorithm

## Overview
This document explains how we compute ray-sphere intersections using floating point math on FPGA.

## Mathematical Background

### Ray Representation
A ray is defined by:
- **Origin** O = (Ox, Oy, Oz)
- **Direction** D = (Dx, Dy, Dz)
- **Parameter** t ≥ 0

Any point P on the ray can be written as:
```
P(t) = O + t*D
```

### Sphere Representation
A sphere is defined by:
- **Center** C = (Cx, Cy, Cz)
- **Radius** r

Any point P on the sphere surface satisfies:
```
|P - C|² = r²
```

## Intersection Algorithm

### 1. Setup the Equation
We want to find where the ray intersects the sphere. Substitute P(t) into the sphere equation:

```
|O + t*D - C|² = r²
```

Let L = O - C (vector from sphere center to ray origin):

```
|L + t*D|² = r²
```

### 2. Expand to Quadratic Form
Expanding the dot product:

```
(L + t*D)·(L + t*D) = r²
L·L + 2t(L·D) + t²(D·D) = r²
```

Rearranging into standard quadratic form (at² + bt + c = 0):

```
a = D·D       (always ≥ 0, usually ≈ 1 for normalized rays)
b = 2(L·D)
c = L·L - r²

at² + bt + c = 0
```

### 3. Compute Discriminant
The discriminant determines if there's an intersection:

```
discriminant = b² - 4ac
```

**Cases:**
- discriminant < 0: No intersection (ray misses sphere)
- discriminant = 0: One intersection (ray is tangent to sphere)
- discriminant > 0: Two intersections (ray enters and exits sphere)

### 4. Solve for t
If discriminant ≥ 0, use the quadratic formula:

```
t = (-b ± sqrt(discriminant)) / (2a)
```

We typically want the **closer** intersection (smaller t):

```
t = (-b - sqrt(discriminant)) / (2a)
```

**Note**: We only want t ≥ 0 (intersections in front of the ray origin).

### 5. Compute Hit Point
Once we have t:

```
P = O + t*D
```

### 6. Compute Normal
The surface normal at the hit point:

```
N = (P - C) / r
```

This gives us the direction perpendicular to the sphere surface (normalized).

## FPGA Implementation

### Operations Required
For each ray-sphere test, we need:

1. **Vector Subtraction**: L = O - C (3 operations)
2. **Dot Products**: 
   - D·D (3 multiplies + 2 adds)
   - L·D (3 multiplies + 2 adds)
   - L·L (3 multiplies + 2 adds)
3. **Radius Squared**: r² (1 multiply)
4. **Discriminant**: b² - 4ac (2 multiplies + 1 subtract)
5. **Square Root**: sqrt(discriminant) (1 operation)
6. **Division**: t = numerator / denominator (1 operation)
7. **Hit Point**: P = O + t*D (3 multiplies + 3 adds)
8. **Normal**: N = (P - C) / r (3 subtracts + 3 divides, or 1 divide + 3 multiplies)

### Using Vivado FP IP Cores

We use these Xilinx Floating Point IP cores:
- **fp_mult**: Single precision multiply, 8 cycle latency
- **fp_add**: Single precision add/subtract, 11 cycle latency
- **fp_sqrt**: Single precision square root, 28 cycle latency
- **fp_div**: Single precision divide, 28 cycle latency
- **fp_compare**: Single precision comparison, 2 cycle latency

### Sequential Implementation (Simplified)

For our first implementation, we process operations sequentially:

```
State 1: Compute L = O - C
  ↓ (wait 11 cycles)
  
State 2: Compute dot products a, b, c (can parallelize some)
  ↓ (wait 8-11 cycles)
  
State 3: Compute discriminant
  ↓ (wait 8-11 cycles)
  
State 4: Check if discriminant ≥ 0
  ↓ (wait 2 cycles)
  
State 5: Compute sqrt(discriminant)
  ↓ (wait 28 cycles)
  
State 6: Compute t = (-b - sqrt) / (2a)
  ↓ (wait 28-39 cycles)
  
State 7: Compute hit point and normal
  ↓ (wait 11-39 cycles)
  
Done! (Total: ~100-150 cycles per sphere test)
```

### Optimizations (Future Work)

1. **Parallel FP Units**: Use multiple multipliers/adders simultaneously
2. **Pipelined Design**: Start next pixel while previous is computing
3. **Early Rejection**: Check bounding box before full intersection
4. **Normalized Rays**: If D·D = 1, save computation (a = 1)
5. **Multiple Ray Tracers**: Instantiate multiple cores in parallel

## Example with Numbers

Let's trace through an example:

**Given:**
- Ray origin: O = (0, -10, 0)
- Ray direction: D = (0, 1, 0) [pointing forward]
- Sphere center: C = (0, 0, 0)
- Sphere radius: r = 1

**Step 1:** L = O - C = (0, -10, 0) - (0, 0, 0) = (0, -10, 0)

**Step 2:** Compute coefficients:
- a = D·D = 0² + 1² + 0² = 1
- b = 2(L·D) = 2(0*0 + (-10)*1 + 0*0) = -20
- c = L·L - r² = (0² + (-10)² + 0²) - 1² = 100 - 1 = 99

**Step 3:** discriminant = b² - 4ac = (-20)² - 4(1)(99) = 400 - 396 = 4

**Step 4:** discriminant > 0, so we have an intersection!

**Step 5:** sqrt(discriminant) = sqrt(4) = 2

**Step 6:** t = (-b - sqrt) / (2a) = (-(-20) - 2) / (2*1) = 18/2 = 9

**Step 7:** Hit point = O + t*D = (0, -10, 0) + 9*(0, 1, 0) = (0, -1, 0)

**Verification:** |P - C| = |(0, -1, 0) - (0, 0, 0)| = 1 = r ✓

The ray hits the sphere at (0, -1, 0), which is indeed on the surface!

## IEEE 754 Single Precision Format

Our FP operations use 32-bit single precision:

```
Sign (1 bit) | Exponent (8 bits) | Mantissa (23 bits)
```

**Examples:**
- 0.0:  `0x00000000`
- 1.0:  `0x3F800000`
- -1.5: `0xBFC00000`
- 10.0: `0x41200000`

**Range:**
- Smallest positive: ~1.4 × 10⁻⁴⁵
- Largest: ~3.4 × 10³⁸
- Precision: ~7 decimal digits

This is more than sufficient for ray tracing at 640x480 resolution!

## Performance Analysis

### Cycle Counts (Sequential)
- Per pixel: ~100-150 cycles (depends on number of spheres hit)
- 3 spheres: ~300-450 cycles/pixel
- Full frame (640×480): ~138M - 207M cycles
- At 50 MHz: 2.8 - 4.1 seconds per frame
- Frame rate: ~0.24 - 0.36 FPS

### Optimizations Needed for Real-Time
To achieve 30 FPS, we need ~1M cycles per frame (at 50 MHz).

Options:
1. **Higher clock**: Run ray tracer at 100 MHz (2× speedup)
2. **Parallel cores**: 10× ray tracers = 10× speedup
3. **Pipelining**: Start new pixel every 10-20 cycles instead of 300
4. **Reduced resolution**: 320×240 = 4× fewer pixels

Combining these: 100 MHz + 4× parallel + pipelining could achieve 30+ FPS!

## Current Implementation Status

### Working:
- ✅ FP IP cores created (mult, add, sqrt, div, compare)
- ✅ FP math package with IEEE 754 types
- ✅ Ray tracer infrastructure with framebuffer
- ✅ Color mapping and HDMI output

### In Progress:
- 🔄 Sequential ray-sphere intersection module
- 🔄 Proper ray direction calculation from pixel coordinates

### Future:
- ⏳ Lighting calculations (diffuse, specular)
- ⏳ Multiple parallel ray tracers
- ⏳ Pipelined architecture
- ⏳ Additional primitives (planes, triangles)

## References

- [Ray Tracing in One Weekend](https://raytracing.github.io/)
- [Scratchapixel - Ray-Sphere Intersection](https://www.scratchapixel.com/lessons/3d-basic-rendering/minimal-ray-tracer-rendering-simple-shapes/ray-sphere-intersection)
- [IEEE 754 Floating Point Standard](https://en.wikipedia.org/wiki/IEEE_754)
- [Xilinx Floating-Point IP Core Documentation](https://www.xilinx.com/products/intellectual-property/floating-point.html)
