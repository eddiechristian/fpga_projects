# G1 Segment Test Wiring Guide

## Overview
This guide shows how to wire up just the **G1 segment** of the LTP-3786E 14-segment display for testing on a breadboard.

## Components Needed
- 1x LTP-3786E 14-segment display
- 1x 330Ω resistor (or 220Ω-470Ω range)
- Power supply (3.3V or 5V)
- Breadboard
- Jumper wires

## What is G1?
The G1 segment is the **left half of the middle horizontal bar** in the 14-segment display:

```
           A1    A2
          ───    ───
         │    │ │    │
        F│  J │ │ K  │B
         │    │ │    │
          ─G1─   ─G2─    ← G1 is the left middle bar
         │    │ │    │
        E│  H │ │    │C
         │    │ │    │
          ───    ───
           D1    D2
```

## Pin Identification
- **Pin 11**: G1 segment (bottom row, 2nd from left)
- **Pin 3**: CA1 - Common Anode Digit 1 (top row, 7th from right)
- **Pin 13**: CA2 - Common Anode Digit 2 (bottom row, 6th from right)

## Wiring Diagram

### Schematic
```
Power Supply (+3.3V or +5V)
         │
         ├──────────────────────► Pin 3 (CA1 - Common Anode Digit 1)
         │
         └──────────────────────► Pin 13 (CA2 - Common Anode Digit 2)


Ground (GND)
         │
         └───[330Ω Resistor]────► Pin 11 (G1 segment)
```

### Breadboard Layout (Bottom View)
When inserting the display into a breadboard, you're looking at the bottom view:

```
           Row 1: 9  8  7  6  5  4  3  2  1
                  ↓  ↓  ↓  ↓  ↓  ↓  ↓  ↓  ↓
                 ┌──────────────────────────┐
                 │    LTP-3786E             │
                 │  [Digit1] [Digit2]       │← Display face (other side)
                 └──────────────────────────┘
                  ↑  ↑  ↑  ↑  ↑  ↑  ↑  ↑  ↑
           Row 2: 10 11 12 13 14 15 16 17 18
                      ↑       ↑
                      │       └─── Connect to +3.3V/+5V
                      └─── Connect to GND via 330Ω resistor
```

## Step-by-Step Instructions

1. **Insert the display** into the breadboard, straddling the center gap
   - The display face should be visible on top
   - Pins 1-9 will be in one row, pins 10-18 in the other row

2. **Connect Pin 3 (CA1)** to power
   - Top row, 7th position from the right
   - Connect to **+3.3V or +5V** rail

3. **Connect Pin 13 (CA2)** to power
   - Bottom row, 6th position from the right
   - Connect to **+3.3V or +5V** rail

4. **Connect Pin 11 (G1)** through resistor to ground
   - Bottom row, 2nd position from the left
   - Connect a **330Ω resistor** from Pin 11 to **GND** rail

## Expected Result
When powered, both digits will show the **G1 segment** (left middle horizontal bar) lit up:

```
Display View:
  ─   ─      ← Both digits showing G1 segment
```

## Notes
- **Common Anode**: The display requires the anode (pins 3 and 13) to be HIGH (+V) and cathodes (segment pins) to be LOW (GND) to light up
- **Current Limiting**: The 330Ω resistor protects the LED segment from excessive current
- **Both Digits**: Since both common anodes are connected to power, both digits will show the same segment
- **Voltage**: Use 3.3V for FPGA compatibility, or 5V for brighter output (check display specs)

## Troubleshooting
- **No light**: Check power connections and resistor value
- **Dim light**: Try a smaller resistor value (220Ω) or higher voltage (5V)
- **Wrong segment**: Double-check you're connecting to Pin 11 (G1)
- **Pin identification**: Pin 1 has a dot/notch marking on the package

