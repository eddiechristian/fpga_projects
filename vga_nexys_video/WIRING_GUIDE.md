# VGA Wiring Guide - PMODs JA & JB to VGA

## Quick Reference

**PMOD JA** (all 8 pins used):
```
Top Row:    JA1, JA2, JA3, JA4    -> Red[3:0]
Bottom Row: JA7, JA8, JA9, JA10   -> Green[3:0]
```

**PMOD JB** (6 pins used):
```
Top Row:    JB1, JB2, JB3, JB4    -> Blue[3:0]
Bottom Row: JB7, JB8              -> HSYNC, VSYNC
```

## VGA Connector Pinout

Looking at a **male VGA connector** (DB-15):
```
    \  1  2  3  4  5  /
      \  6  7  8  9  /
        \ 10 11 12 /
          \ 13 14 /
            \ 15 /
```

| Pin | Signal | Description |
|-----|--------|-------------|
| 1   | Red    | Red analog video (0-0.7V) |
| 2   | Green  | Green analog video (0-0.7V) |
| 3   | Blue   | Blue analog video (0-0.7V) |
| 5   | GND    | Ground |
| 6-8 | GND    | RGB ground returns |
| 10  | GND    | Sync ground |
| 13  | HSYNC  | Horizontal sync (digital TTL) |
| 14  | VSYNC  | Vertical sync (digital TTL) |

**Connect all GND pins (5, 6, 7, 8, 10) together to PMOD GND**

## Simple Test Setup (No Resistors)

For **initial testing only**, you can connect directly without resistors to see if timing works:

⚠️ **WARNING**: This outputs 3.3V instead of 0.7V. It won't damage modern monitors but colors will be oversaturated/washed out.

```
JA4  -> VGA Pin 1  (Red MSB)
JA10 -> VGA Pin 2  (Green MSB)
JB4  -> VGA Pin 3  (Blue MSB)
JB7  -> VGA Pin 13 (HSYNC)
JB8  -> VGA Pin 14 (VSYNC)
PMOD GND -> VGA Pins 5,6,7,8,10
```

This gives you **8 colors** (1-bit per channel) to verify sync is working.

## Proper Setup with Resistors

### Why You Need Resistors

VGA expects **0.7V peak-to-peak** analog signals, but the FPGA outputs **3.3V digital**.
You need a **Digital-to-Analog Converter (DAC)** using resistors.

### Option 1: Single Resistor Per Bit (Easy)

Use one resistor per bit with values weighted by bit position:

**For each color channel (build 3 times):**
```
MSB (bit 3) ----[ 270Ω ]----+
    (bit 2) ----[ 560Ω ]----+
    (bit 1) ----[ 1.2kΩ ]---+---> VGA Color Pin (1, 2, or 3)
LSB (bit 0) ----[ 2.4kΩ ]---+

Note: VGA has internal 75Ω termination to ground
```

**Red Channel Example:**
```
JA4  ----[ 270Ω ]----+
JA3  ----[ 560Ω ]----+
JA2  ----[ 1.2kΩ ]---+---> VGA Pin 1 (Red)
JA1  ----[ 2.4kΩ ]---+
```

Repeat for Green (JA10-JA7 -> Pin 2) and Blue (JB4-JB1 -> Pin 3).

### Option 2: R-2R Ladder (Better)

An R-2R ladder gives more linear output. Use R=470Ω, 2R=1kΩ.

**4-bit R-2R ladder schematic:**
```
Bit3 ---[470Ω]---+---[1kΩ]---+
                 |            |
Bit2 ---[470Ω]---+---[1kΩ]---+
                 |            |
Bit1 ---[470Ω]---+---[1kΩ]---+
                 |            |
Bit0 ---[470Ω]---+---[1kΩ]---+---> VGA Color Pin
                              |
                            [1kΩ]
                              |
                             GND
```

Build this circuit **3 times** (once each for R, G, B).

### Option 3: Just Use MSB (Quickest Test)

If you just want to see something working:

```
JA4  ----[ 270Ω ]----> VGA Pin 1 (Red)
JA10 ----[ 270Ω ]----> VGA Pin 2 (Green)
JB4  ----[ 270Ω ]----> VGA Pin 3 (Blue)
JB7  ----------------> VGA Pin 13 (HSYNC - direct connection OK)
JB8  ----------------> VGA Pin 14 (VSYNC - direct connection OK)
All GNDs connected
```

This gives **8 colors** with proper voltage levels.

## Complete Wiring Table

### Red Channel (PMOD JA pins 1-4)
| FPGA Pin | PMOD | Bit | Resistor | VGA Pin |
|----------|------|-----|----------|---------|
| AB22 | JA1 | R[0] LSB | 2.4kΩ | Pin 1 |
| AB21 | JA2 | R[1] | 1.2kΩ | Pin 1 |
| AB20 | JA3 | R[2] | 560Ω | Pin 1 |
| AB18 | JA4 | R[3] MSB | 270Ω | Pin 1 |

### Green Channel (PMOD JA pins 7-10)
| FPGA Pin | PMOD | Bit | Resistor | VGA Pin |
|----------|------|-----|----------|---------|
| Y21 | JA7 | G[0] LSB | 2.4kΩ | Pin 2 |
| AA21 | JA8 | G[1] | 1.2kΩ | Pin 2 |
| AA20 | JA9 | G[2] | 560Ω | Pin 2 |
| AA18 | JA10 | G[3] MSB | 270Ω | Pin 2 |

### Blue Channel (PMOD JB pins 1-4)
| FPGA Pin | PMOD | Bit | Resistor | VGA Pin |
|----------|------|-----|----------|---------|
| V9 | JB1 | B[0] LSB | 2.4kΩ | Pin 3 |
| V8 | JB2 | B[1] | 1.2kΩ | Pin 3 |
| V7 | JB3 | B[2] | 560Ω | Pin 3 |
| W7 | JB4 | B[3] MSB | 270Ω | Pin 3 |

### Sync Signals (PMOD JB pins 7-8)
| FPGA Pin | PMOD | Signal | Connection | VGA Pin |
|----------|------|--------|------------|---------|
| W9 | JB7 | HSYNC | Direct (or 100Ω for safety) | Pin 13 |
| Y9 | JB8 | VSYNC | Direct (or 100Ω for safety) | Pin 14 |

### Ground Connections
Connect **all PMOD GND pins** to **VGA pins 5, 6, 7, 8, 10** (all tied together).

## Breadboard Layout Example

```
PMOD JA Breakout          VGA Cable
┌──────────┐              ┌─────┐
│ 1  ●  ●  │              │     │
│ 2  ●  ●  │  [Resistor   │  1  │ Red
│ 3  ●  ●  │   Ladder]────│  2  │ Green
│ 4  ●  ●  │              │  3  │ Blue
│ 7  ●  ●  │              │  13 │ HSYNC
│ 8  ●  ●  │              │  14 │ VSYNC
│ 9  ●  ●  │              │ GND │
│10  ●  ●  │              └─────┘
│GND ●  ●  │
└──────────┘
```

## Testing Steps

1. **Build circuit on breadboard**
   - Start with MSB-only version (simplest)
   - Add full resistor ladder later if needed

2. **Check connections with multimeter**
   - Verify no shorts between color channels
   - Check continuity of GND

3. **Connect to old VGA monitor first**
   - Use a monitor you don't care about for initial testing
   - Modern monitors are usually safe, but be cautious

4. **Power on board and program bitstream**

5. **Expected output: 8 vertical color bars**
   - White, Yellow, Cyan, Green, Magenta, Red, Blue, Black

## Troubleshooting

| Problem | Likely Cause | Solution |
|---------|--------------|----------|
| Monitor says "No Signal" | Sync signals not connected | Check JB7->Pin13, JB8->Pin14 |
| Black screen with sync | No RGB signals | Check resistor ladder connections |
| Wrong colors | Swapped color channels | Verify JA->Red(1), JA->Green(2), JB->Blue(3) |
| Washed out colors | No resistors / wrong values | Add or fix resistor values |
| Shifted/distorted image | Ground issue | Ensure all GND pins connected |
| Flickering | Loose connection | Check all solder joints / breadboard |

## Alternative: Buy a PMOD VGA Adapter

**Digilent Pmod VGA** (Part #410-097): ~$15
- Has built-in resistor DACs
- 12-pin PMOD interface  
- VGA connector included
- **Note**: Uses different pinout, you'd need to modify the XDC file

## Safety

- ✅ Sync signals can connect directly (TTL compatible)
- ⚠️ RGB signals MUST use resistors (expect 0.7V, FPGA outputs 3.3V)
- ❌ Don't hot-plug VGA cables (power off monitor first)
- ✅ FPGA outputs are current-limited, won't damage if shorted briefly
- ⚠️ Test with old/cheap monitor first

## Color Depth

With 4-bit per channel:
- **Total colors**: 4096 (2^12)
- **Per channel**: 16 levels (2^4)
- **Comparable to**: Early PC VGA (256 colors) is less, but this is better!

For comparison:
- 24-bit color (modern): 16.7 million colors
- 12-bit color (this): 4096 colors (still pretty good!)
- 8-bit color (MSB only): 8 colors (testing)
