# CORDIC Sin/Cos Test Project

This project tests the Xilinx CORDIC IP core to verify sine and cosine computations are working correctly. It was created to help debug issues with CORDIC results in the `trs_test` project.

## Purpose

The CORDIC IP is used for computing sine and cosine values needed for 3D rotation matrices. This test project validates:
- Proper CORDIC IP configuration
- Correct Q1.31 fixed-point format conversion
- Accurate sin/cos outputs for known angles

## Project Structure

```
cordic_test/
├── build.tcl              # Build script
├── build/                 # Build output (generated)
├── README.md              # This file
└── src/
    ├── hdl/
    │   └── top_module.vhd      # Test hardware that cycles through angles
    └── sim/
        └── top_module_tb.vhd   # Testbench for simulation
```

## CORDIC Configuration

The CORDIC IP is configured with:
- **Function**: Sin and Cos (both outputs)
- **Architecture**: Word Serial (resource efficient)
- **Data Format**: Signed Fraction (Q1.31)
- **Phase Format**: Radians
- **Input Width**: 32 bits
- **Output Width**: 32 bits
- **Compensation**: Divide by K (applies gain correction)

## Q1.31 Fixed-Point Format

The CORDIC uses Q1.31 signed fraction format where:
- The value represents a number in the range [-1.0, +1.0]
- Bit 31 is the sign bit
- Bits 30:0 are the fractional part
- Formula: `value = integer_value / 2^31`

### Input (Phase/Angle)
The CORDIC expects the input angle **divided by π**:
- Input = (angle in radians) / π
- Examples:
  - 0 rad → 0/π = 0.0 → `0x00000000`
  - π/4 rad → (π/4)/π = 0.25 → `0x20000000`
  - π/2 rad → (π/2)/π = 0.5 → `0x40000000`
  - π rad → π/π = 1.0 → `0x80000000` (wraps to -1.0 in signed)

### Output (Sin/Cos)
The outputs are in standard Q1.31 format:
- Values range from -1.0 to +1.0
- Examples:
  - 0.0 → `0x00000000`
  - 0.5 → `0x40000000`
  - 0.707 → `0x5A827999`
  - 0.866 → `0x6ED9EBA1`
  - 1.0 → `0x7FFFFFFF`
  - -0.5 → `0xC0000000`
  - -1.0 → `0x80000000`

## Test Cases

The design tests these common angles:

| Angle | Degrees | Input (Q1.31) | Expected Sin | Expected Cos |
|-------|---------|---------------|--------------|--------------|
| 0 | 0° | `0x00000000` | 0.000 | 1.000 |
| π/6 | 30° | `0x15555555` | 0.500 | 0.866 |
| π/4 | 45° | `0x20000000` | 0.707 | 0.707 |
| π/3 | 60° | `0x2AAAAAAB` | 0.866 | 0.500 |
| π/2 | 90° | `0x40000000` | 1.000 | 0.000 |
| 2π/3 | 120° | `0x55555555` | 0.866 | -0.500 |
| π | 180° | `0x80000000` | 0.000 | -1.000 |

## Building the Project

```bash
cd cordic_test
vivado -mode batch -source build.tcl
```

## Running Simulation

1. Open the project in Vivado:
   ```bash
   vivado build/cordic_test.xpr &
   ```

2. Run behavioral simulation from the GUI
3. Add these signals to the waveform viewer:
   - `angle_index` - Which test case (0-6)
   - `cordic_phase` - Input angle
   - `cordic_phase_valid` - Input valid strobe
   - `cordic_result_valid` - Output valid strobe
   - `sin_out` - Sine result
   - `cos_out` - Cosine result
   - `test_complete` - All tests finished

4. Verify results match expected values in the table above

## Key Signals

- **angle_index**: Counter from 0-6 indicating which test angle
- **cordic_phase**: Input angle in Q1.31 format (angle/π)
- **cordic_phase_valid**: Strobe indicating valid input
- **cordic_result_valid**: Strobe indicating valid output
- **sin_out**: Sine output in Q1.31 format
- **cos_out**: Cosine output in Q1.31 format
- **test_complete**: High when all 7 tests have been sent

## Common Issues

### Issue: Wrong sin/cos values

**Possible causes:**
1. **Input format incorrect**: Remember to divide angle by π
2. **Output interpretation wrong**: Values are in Q1.31 (-1.0 to +1.0)
3. **Bit ordering**: CORDIC outputs cos in [63:32], sin in [31:0]

### Issue: No output (result_valid never goes high)

**Possible causes:**
1. Clock not running
2. Phase valid signal not asserted
3. CORDIC IP not properly configured

## Relationship to trs_test Project

The `trs_test` project uses floating-point to fixed-point converters before/after CORDIC:
1. Float angle (radians) → **float_to_fixed** → Q1.31 (angle/π) → CORDIC
2. CORDIC → Q1.31 sin/cos → **fixed_to_float** → Float sin/cos

If this test works but `trs_test` doesn't, the issue is likely in the conversion functions or how the float/fixed converters are configured.

## Target Hardware

- **FPGA**: Xilinx Artix-7 (xc7a200tsbg484-1)
- **Clock**: 200 MHz internal (from 100 MHz input via clock wizard)

## Next Steps

If this test passes:
1. Compare CORDIC configuration with `trs_test`
2. Check float-to-fixed conversion functions
3. Verify the radians-to-Q31 conversion formula
4. Check if angle normalization is needed

If this test fails:
1. Review CORDIC IP configuration
2. Check Xilinx CORDIC documentation
3. Verify Q1.31 format understanding
4. Try different CORDIC settings (rounding, pipelining)
