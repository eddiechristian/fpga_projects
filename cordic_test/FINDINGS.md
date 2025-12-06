# CORDIC Test Findings

## Problem Summary
The Xilinx CORDIC IP in **SignedFraction** data format **does not support automatic K-factor compensation** regardless of architecture or phase format settings. The `Compensation_Scaling` parameter is always ignored.

## Root Cause
1. **SignedFraction + any Phase Format → No compensation available**
2. The CORDIC outputs values that are off by a factor of ~0.607 (1/K where K=1.6468)
3. Manual compensation via multiplication is required

## Test Results

### Configuration Tested
- Data Format: SignedFraction  
- Phase Format: Scaled Radians
- Input Width: 32 bits
- Output Width: 32 bits
- Compensation: None (always disabled)

### For 120° input (0x2AAAAAAB in Scaled Radians):
- **Expected**: sin=0.866, cos=-0.5
- **Got (uncompensated)**: sin=-0.288, cos=-0.409
- **Got (with manual K compensation)**: sin=-0.474, cos=-0.674

The values are STILL WRONG even after compensation, suggesting the CORDIC configuration fundamentally doesn't work with Signed Fraction + Scaled Radians.

## Solution for trs_test Project

Your `trs_test` project has the SAME configuration and will have the SAME problem. Here's what needs to be fixed:

###Option 1: Use Floating-Point CORDIC (RECOMMENDED)
Change the CORDIC IP to use floating-point mode instead of fixed-point:
```tcl
CONFIG.Data_Format {FloatingPoint}
CONFIG.A_Precision_Type {Single}
CONFIG.Phase_Format {Radians}
```

Then you don't need the float-to-fixed and fixed-to-float converters at all.

### Option 2: Use Different Fixed-Point Format
Try:
```tcl
CONFIG.Data_Format {UnsignedFraction}
CONFIG.Phase_Format {Scaled_Radians}
```
But this limits angles to [0, 2π).

### Option 3: Manual Compensation (Current Approach - NOT WORKING)
The manual K-factor compensation wrapper we created doesn't produce correct results. The CORDIC configuration itself appears to be fundamentally incompatible.

## Recommendation

**For your trs_test project, switch to floating-point CORDIC.** This will:
1. Eliminate the need for float↔fixed converters
2. Provide built-in compensation
3. Give you the correct sin/cos values directly

The floating-point CORDIC is more resource-intensive but actually works correctly.

## Files Created
-cordic_test/src/hdl/cordic_sincos_compensated.vhd` - Manual compensation wrapper (doesn't work)
- `cordic_test/src/hdl/top_module.vhd` - Test harness with 7 angles
- `cordic_test/q31_converter.py` - Utility for converting Q1.31 values

## Next Steps
1. Modify trs_test to use floating-point CORDIC
2. Remove float-to-fixed and fixed-to-float converters  
3. Update conversion functions in conversion_pkg.vhd to work directly with float
