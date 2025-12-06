#!/usr/bin/env python3
"""
Q1.31 Fixed-Point Converter Utility

Helps interpret CORDIC test results by converting between:
- Q1.31 hex values
- Decimal floating-point values
- Angle representations

Usage:
    python3 q31_converter.py 0x5A827999    # Convert hex to decimal
    python3 q31_converter.py 0.707         # Convert decimal to hex
    python3 q31_converter.py angle 45      # Convert angle (degrees) to Q1.31 for CORDIC input
"""

import sys

def q31_to_float(q31_hex):
    """Convert Q1.31 hex to floating point value."""
    if isinstance(q31_hex, str):
        value = int(q31_hex, 16)
    else:
        value = q31_hex
    
    # Convert to signed 32-bit
    if value >= 2**31:
        value -= 2**32
    
    # Q1.31 format: value / 2^31
    return value / (2**31)

def float_to_q31(f):
    """Convert floating point to Q1.31 hex."""
    # Clamp to [-1, 1]
    f = max(-1.0, min(1.0, f))
    
    # Q1.31: multiply by 2^31
    value = int(f * (2**31))
    
    # Handle two's complement for negative numbers
    if value < 0:
        value = (1 << 32) + value
    
    return f"0x{value:08X}"

def angle_to_q31_cordic_input(angle_deg):
    """
    Convert angle in degrees to Q1.31 format for CORDIC input.
    CORDIC expects angle/π in Q1.31 format.
    """
    import math
    angle_rad = math.radians(angle_deg)
    # CORDIC input format: angle / π
    normalized = angle_rad / math.pi
    return float_to_q31(normalized)

def main():
    if len(sys.argv) < 2:
        print(__doc__)
        print("\nCommon test values:")
        print("  Angle   | CORDIC Input | sin (Q1.31)  | cos (Q1.31)")
        print("  --------|--------------|--------------|-------------")
        print("  0°      | 0x00000000   | 0x00000000   | 0x7FFFFFFF")
        print("  30°     | 0x15555555   | 0x40000000   | 0x6ED9EBA1")
        print("  45°     | 0x20000000   | 0x5A827999   | 0x5A827999")
        print("  60°     | 0x2AAAAAAB   | 0x6ED9EBA1   | 0x40000000")
        print("  90°     | 0x40000000   | 0x7FFFFFFF   | 0x00000000")
        print("  180°    | 0x80000000   | 0x00000000   | 0x80000000")
        return
    
    arg = sys.argv[1].lower()
    
    if arg == "angle":
        if len(sys.argv) < 3:
            print("Usage: q31_converter.py angle <degrees>")
            return
        angle = float(sys.argv[2])
        q31_hex = angle_to_q31_cordic_input(angle)
        print(f"Angle: {angle}° → CORDIC input (Q1.31): {q31_hex}")
        print(f"  (This is angle/{angle:.1f}π = {angle/180.0:.4f} in Q1.31 format)")
    elif arg.startswith("0x"):
        # Hex to decimal
        f = q31_to_float(arg)
        print(f"Q1.31 {arg} = {f:.10f}")
    else:
        # Decimal to hex
        try:
            f = float(arg)
            q31_hex = float_to_q31(f)
            print(f"{f} → Q1.31: {q31_hex}")
        except ValueError:
            print(f"Error: '{arg}' is not a valid number or hex value")

if __name__ == "__main__":
    main()
