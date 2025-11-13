# Current Limiting Resistor Selection Guide

## Quick Answer
**Yes, 220Ω resistors are perfect for this project!**

## Why 220Ω Works Well

### Current Calculation
```
FPGA output voltage:    3.3V
LED forward voltage:    ~2.0V (typical for red LEDs)
Voltage across resistor: 3.3V - 2.0V = 1.3V
Current per segment:     1.3V / 220Ω ≈ 6mA
```

### Safety Check
✅ **Safe for FPGA pins**: Nexys Video I/O pins can typically source 8-12mA  
✅ **Safe for LED segments**: Typical maximum is 20-30mA  
✅ **Bright enough**: 6mA provides good visibility  
✅ **Efficient**: Not wasting power with excessive brightness  

### Multiplexing Advantage
Since only **one digit is active at a time**, you'll never have all segments drawing current simultaneously. This makes the design even safer for the FPGA.

**Maximum current at any moment:**
- 14 segments × 6mA = 84mA total (worst case, all segments ON on one digit)
- This is well within safe operating limits

## Alternative Resistor Values

| Resistor | Current | Brightness | Notes |
|----------|---------|------------|-------|
| 150Ω     | ~8.7mA  | Brighter   | Still safe, use if 220Ω is too dim |
| 220Ω     | ~6mA    | Good       | **Recommended starting point** |
| 330Ω     | ~4mA    | Dimmer     | More efficient, use if 220Ω is too bright |
| 470Ω     | ~2.8mA  | Dim        | May be too dim for bright environments |

## How to Adjust

### If Display is Too Dim:
- Try 150Ω resistors
- Check that your wiring is correct
- Verify digit select signals are working (use multimeter)

### If Display is Too Bright:
- Try 330Ω resistors
- This also reduces power consumption

### If Some Segments Don't Light:
- Check for cold solder joints
- Verify correct pin connections
- Test with a multimeter in diode mode

## LED Color Considerations

Different LED colors have different forward voltages:

| LED Color | Typical Vf | Current with 220Ω |
|-----------|------------|-------------------|
| Red       | 1.8-2.2V   | 5-7mA            |
| Yellow    | 2.0-2.2V   | 5-6mA            |
| Green     | 2.0-3.0V   | 2-6mA            |
| Blue/White| 3.0-3.5V   | 0-2mA (too dim)  |

**Note**: The LTP-3786E typically uses red LEDs, so 220Ω is ideal.

## Power Consumption Estimate

**Per Digit (all 14 segments ON):**
```
Current: 14 segments × 6mA = 84mA
Power:   3.3V × 84mA = 277mW
```

**Actual usage** (typical character like "8" or "A"):
- Average: ~60-70mA per active digit
- Since only 1 of 4 digits is active at a time (multiplexing), average draw is much lower

**Total System:**
- FPGA core: ~500mA
- Display (time-averaged): ~70mA / 4 = ~18mA
- Total: ~520mA typical

This is well within the power budget of the Nexys Video board.

## Shopping List

**For this project (2 displays, 4 digits, 14 segments shared):**
- Quantity needed: **14 resistors** (one per segment signal)
- Value: 220Ω
- Power rating: 1/4W (standard) is plenty
- Tolerance: 5% is fine

**Recommended:**
Buy a 220Ω resistor pack (100pcs) for future projects and spares.

## Installation Tips

1. **Place resistors on the segment lines** (SEG[0] through SEG[13])
2. **One resistor per segment signal** - not per display, since segments are shared
3. **Placement**: Between FPGA output and display segment pins
4. **No resistors needed** on digit select lines (DIG[0-3])

## Circuit Diagram

```
FPGA Pin (3.3V)
     │
     └──[220Ω]───→ Display Segment Pin
                      │
                      └→ LED Segment (in display)
                           │
                           └→ Common Anode (when digit is selected)
```

## Testing Individual Segments

To test if a segment works before full assembly:

1. Connect FPGA GND to display common anode pin (3 or 13)
2. Connect FPGA 3.3V → 220Ω resistor → segment pin
3. Segment should light up

This verifies your resistor value and display segment are working.

## Summary

- ✅ Use **220Ω resistors**
- ✅ You need **14 resistors total** (one per segment line)
- ✅ 1/4W power rating is sufficient
- ✅ This will give you bright, clear digits
- ✅ Safe for both FPGA and display
