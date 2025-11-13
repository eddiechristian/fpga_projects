# Wiring Diagram: Nexys Video to 2x LTP-3786E 14-Segment Displays

## Overview
- **FPGA Board**: Nexys Video (Artix-7 XC7A200T)
- **Displays**: 2x LTP-3786E (2-digit 14-segment displays, common anode)
- **Total Digits**: 4 digits
- **PMOD Ports Used**: JA, JB, JC

## LTP-3786E Pinout (each display has 2 digits)
The LTP-3786E is a 2-digit 14-segment common anode display.

### Pin Configuration (per display):
```
Pin 1:  Segment E
Pin 2:  Segment D2
Pin 3:  Common Anode Digit 1 (leftmost)
Pin 4:  Segment C
Pin 5:  Decimal Point 1
Pin 6:  Segment B
Pin 7:  Segment A2
Pin 8:  Segment A1
Pin 9:  Segment F
Pin 10: Segment G2
Pin 11: Segment G1
Pin 12: Decimal Point 2
Pin 13: Common Anode Digit 2 (rightmost)
Pin 14: Segment D1
Pin 15: Segment I
Pin 16: Segment H
Pin 17: Segment J
Pin 18: Segment K
```

## Connection Table

### PMOD JA - Segment Signals (shared by both displays)
| PMOD Pin | FPGA Pin | Signal | Connect to Display 1 | Connect to Display 2 |
|----------|----------|--------|---------------------|---------------------|
| JA1      | AB22     | SEG[0] (A1) | Pin 8  | Pin 8  |
| JA2      | AB21     | SEG[1] (A2) | Pin 7  | Pin 7  |
| JA3      | AB20     | SEG[2] (B)  | Pin 6  | Pin 6  |
| JA4      | AB18     | SEG[3] (C)  | Pin 4  | Pin 4  |
| JA7      | Y21      | SEG[4] (D1) | Pin 14 | Pin 14 |
| JA8      | AA21     | SEG[5] (D2) | Pin 2  | Pin 2  |
| JA9      | AA20     | SEG[6] (E)  | Pin 1  | Pin 1  |
| JA10     | AA18     | SEG[7] (F)  | Pin 9  | Pin 9  |

### PMOD JB - More Segment Signals (shared by both displays)
| PMOD Pin | FPGA Pin | Signal | Connect to Display 1 | Connect to Display 2 |
|----------|----------|--------|---------------------|---------------------|
| JB1      | V9       | SEG[8] (G1)  | Pin 11 | Pin 11 |
| JB2      | V8       | SEG[9] (G2)  | Pin 10 | Pin 10 |
| JB3      | V7       | SEG[10] (H)  | Pin 16 | Pin 16 |
| JB4      | W7       | SEG[11] (I)  | Pin 15 | Pin 15 |
| JB7      | W9       | SEG[12] (J)  | Pin 17 | Pin 17 |
| JB8      | Y9       | SEG[13] (K)  | Pin 18 | Pin 18 |

### PMOD JC - Digit Select Signals
| PMOD Pin | FPGA Pin | Signal | Connect to |
|----------|----------|--------|------------|
| JC1      | V6       | DIG[0] | Display 1, Pin 13 (Digit 2, rightmost) |
| JC2      | W6       | DIG[1] | Display 1, Pin 3  (Digit 1, leftmost)  |
| JC3      | U8       | DIG[2] | Display 2, Pin 13 (Digit 2, rightmost) |
| JC4      | V8       | DIG[3] | Display 2, Pin 3  (Digit 1, leftmost)  |

## Current Limiting Resistors
**IMPORTANT**: You must add current-limiting resistors for each segment line!

- Use 220Ω - 330Ω resistors in series with each segment signal (SEG[0] through SEG[13])
- Total: 14 resistors needed
- Place resistors between FPGA outputs and display segment pins

## Power Connections
- Connect VCC (+3.3V or +5V depending on display spec) to display power pins
- Connect GND to FPGA ground
- All displays share the same segment signals but have individual digit select lines

## Physical Layout Recommendation
```
Display 1 (Digits 0-1)    Display 2 (Digits 2-3)
    [  0  ][  1  ]           [  2  ][  3  ]
```

## How It Works
1. **Multiplexing**: The FPGA rapidly cycles through digits (every ~1ms)
2. **Digit Select**: Only one digit is enabled at a time (active LOW)
3. **Segments**: All 14 segment signals are shared - the digit select determines which physical digit shows the pattern
4. **Blanking**: Leading zeros are automatically blanked via the blank_mask logic
5. **Counter Display**: The design counts from 0000 to FFFF in hexadecimal

## Testing
1. Program the FPGA
2. You should see a counter incrementing on the 4-digit display
3. Leading zeros will be blanked (e.g., "5" shows as "   5", not "0005")
4. Press RST button to reset counter to 0
5. The 8 LEDs on the board show the lower 8 bits of the counter for debugging
