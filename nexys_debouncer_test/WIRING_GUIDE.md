# Complete Wiring Guide: Nexys Video to Analog Discovery 2

## Nexys Video Board Layout - Pmod Locations

```
                    Nexys Video Board (Top View)
     ╔═══════════════════════════════════════════════════════╗
     ║                                                       ║
     ║   [JTAG]              [USB]                [Power]   ║
     ║                                                       ║
     ║                                                       ║
     ║    PMOD JD                          PMOD JA          ║
     ║    ┌─────┐                          ┌─────┐          ║
     ║    │1   6│                          │1   6│          ║
     ║    │7  12│                          │7  12│          ║
     ║    └─────┘                          └─────┘          ║
     ║                                                       ║
     ║                                                       ║
     ║                 [FPGA Chip]                          ║
     ║                                                       ║
     ║                                                       ║
     ║    PMOD JC                          PMOD JB          ║
     ║    ┌─────┐                          ┌─────┐          ║
     ║    │1   6│                          │1   6│          ║
     ║    │7  12│                          │7  12│          ║
     ║    └─────┘                          └─────┘          ║
     ║                                                       ║
     ║  [BTN]  BTNC                                         ║
     ║  [BTN]  [BTN]                                        ║
     ║                                                       ║
     ╚═══════════════════════════════════════════════════════╝

Note: JA and JB are on the RIGHT side of the board
      JC and JD are on the LEFT side of the board
```

## Pmod Connector Pinout (Each Pmod)

```
Looking at Pmod connector from FRONT:

    Top Row:     1    2    3    4    5    6
                 •    •    •    •   GND  VCC

    Bottom Row:  7    8    9   10   11   12
                 •    •    •    •   GND  VCC

Pin 5 & 11: GND (Ground)
Pin 6 & 12: VCC (3.3V - DO NOT CONNECT)
```

## Analog Discovery 2 Digital Pins

```
Analog Discovery 2 - Digital I/O Connector (looking at connector)

    Top Row:    DIO 0-7     (pins 1-8)
    Bottom Row: DIO 8-15    (pins 9-16)
    
    Ground pins: Multiple GND pins available
    
    [DIO 0 ] [DIO 1 ] [DIO 2 ] [DIO 3 ] [DIO 4 ] [DIO 5 ] [DIO 6 ] [DIO 7 ]
    [  ⚫  ] [  ⚫  ] [  ⚫  ] [  ⚫  ] [  ⚫  ] [  ⚫  ] [  ⚫  ] [  ⚫  ]
    
    [DIO 8 ] [DIO 9 ] [DIO 10] [DIO 11] [DIO 12] [DIO 13] [DIO 14] [DIO 15]
    [  ⚫  ] [  ⚫  ] [  ⚫  ] [  ⚫  ] [  ⚫  ] [  ⚫  ] [  ⚫  ] [  ⚫  ]
    
    [ GND  ] [ GND  ] [ GND  ] [ GND  ] [ GND  ] [ GND  ] [ GND  ] [ GND  ]
    [  ⚫  ] [  ⚫  ] [  ⚫  ] [  ⚫  ] [  ⚫  ] [  ⚫  ] [  ⚫  ] [  ⚫  ]
```

## Complete Wiring Table - FULL ANALYSIS

### PMOD JA Connections (Primary Signals)

| AD2 Pin | Signal Name | → | Nexys Video | Description |
|---------|-------------|---|-------------|-------------|
| DIO 0   | Raw Button  | → | JA Pin 1    | Button input (with bounce) |
| DIO 1   | Debounced   | → | JA Pin 2    | Clean debounced output |
| DIO 2   | SigOutReg   | → | JA Pin 3    | Internal output register |
| DIO 3   | CntrActive  | → | JA Pin 4    | Counter active flag |
| GND     | Ground      | → | JA Pin 5    | **GROUND REFERENCE** |
| DIO 4   | Counter[23] | → | JA Pin 7    | Counter MSB |
| DIO 5   | Counter[22] | → | JA Pin 8    | Counter bit 22 |
| DIO 6   | Counter[21] | → | JA Pin 9    | Counter bit 21 |
| DIO 7   | Counter[20] | → | JA Pin 10   | Counter bit 20 |

### PMOD JB Connections (Counter bits 19-12)

| AD2 Pin | Signal Name | → | Nexys Video | Description |
|---------|-------------|---|-------------|-------------|
| DIO 8   | Counter[19] | → | JB Pin 1    | Counter bit 19 |
| DIO 9   | Counter[18] | → | JB Pin 2    | Counter bit 18 |
| DIO 10  | Counter[17] | → | JB Pin 3    | Counter bit 17 |
| DIO 11  | Counter[16] | → | JB Pin 4    | Counter bit 16 |
| GND     | Ground      | → | JB Pin 5    | Ground reference |
| DIO 12  | Counter[15] | → | JB Pin 7    | Counter bit 15 |
| DIO 13  | Counter[14] | → | JB Pin 8    | Counter bit 14 |
| DIO 14  | Counter[13] | → | JB Pin 9    | Counter bit 13 |
| DIO 15  | Counter[12] | → | JB Pin 10   | Counter bit 12 |

**Note**: Analog Discovery 2 only has 16 digital channels (DIO 0-15), so we can capture:
- All primary signals (JA)
- Counter MSBs [23:12] (JA + JB)

You cannot capture JC and JD simultaneously with a single AD2. For complete analysis, you'll need to capture in multiple sessions or use two AD2 units.

## Physical Wiring Instructions

### Step-by-Step Wiring

**You will need:**
- Male-to-female jumper wires (at least 17 wires)
- Analog Discovery 2 with digital I/O cable

**Wiring Process:**

1. **Power OFF both devices before connecting**

2. **Start with Ground connections** (MOST IMPORTANT):
   ```
   AD2 GND (any ground pin) → Nexys JA Pin 5
   AD2 GND (any ground pin) → Nexys JB Pin 5
   ```

3. **Connect PMOD JA signals**:
   ```
   AD2 DIO 0  → Nexys JA Pin 1  (Raw button)
   AD2 DIO 1  → Nexys JA Pin 2  (Debounced)
   AD2 DIO 2  → Nexys JA Pin 3  (sig_out_reg)
   AD2 DIO 3  → Nexys JA Pin 4  (Counter active)
   AD2 DIO 4  → Nexys JA Pin 7  (Counter[23])
   AD2 DIO 5  → Nexys JA Pin 8  (Counter[22])
   AD2 DIO 6  → Nexys JA Pin 9  (Counter[21])
   AD2 DIO 7  → Nexys JA Pin 10 (Counter[20])
   ```

4. **Connect PMOD JB signals**:
   ```
   AD2 DIO 8  → Nexys JB Pin 1  (Counter[19])
   AD2 DIO 9  → Nexys JB Pin 2  (Counter[18])
   AD2 DIO 10 → Nexys JB Pin 3  (Counter[17])
   AD2 DIO 11 → Nexys JB Pin 4  (Counter[16])
   AD2 DIO 12 → Nexys JB Pin 7  (Counter[15])
   AD2 DIO 13 → Nexys JB Pin 8  (Counter[14])
   AD2 DIO 14 → Nexys JB Pin 9  (Counter[13])
   AD2 DIO 15 → Nexys JB Pin 10 (Counter[12])
   ```

5. **Double-check**:
   - ✅ Ground wires connected
   - ✅ No wires on Pin 6 or Pin 12 (VCC pins)
   - ✅ All signal wires firmly seated

6. **Power ON**:
   - Connect Nexys Video to USB and power
   - Connect Analog Discovery 2 to USB

## Visual Wiring Diagram - JA Connector Detail

```
Nexys Video Pmod JA        Analog Discovery 2
┌─────────────────┐        ┌──────────────────┐
│ Pin 1  ⚫────────┼───────→│ DIO 0 (Raw Btn)  │
│ Pin 2  ⚫────────┼───────→│ DIO 1 (Debounced)│
│ Pin 3  ⚫────────┼───────→│ DIO 2 (SigOutReg)│
│ Pin 4  ⚫────────┼───────→│ DIO 3 (CntrActiv)│
│ Pin 5 ⚫─────────┼───────→│ GND              │
│ Pin 6  (VCC) ✗  │ DO NOT CONNECT            │
│ Pin 7  ⚫────────┼───────→│ DIO 4 (Cntr[23]) │
│ Pin 8  ⚫────────┼───────→│ DIO 5 (Cntr[22]) │
│ Pin 9  ⚫────────┼───────→│ DIO 6 (Cntr[21]) │
│ Pin 10 ⚫────────┼───────→│ DIO 7 (Cntr[20]) │
│ Pin 11 (GND)    │                           │
│ Pin 12 (VCC) ✗  │ DO NOT CONNECT            │
└─────────────────┘        └──────────────────┘
```

## Visual Wiring Diagram - JB Connector Detail

```
Nexys Video Pmod JB        Analog Discovery 2
┌─────────────────┐        ┌──────────────────┐
│ Pin 1  ⚫────────┼───────→│ DIO 8  (Cntr[19])│
│ Pin 2  ⚫────────┼───────→│ DIO 9  (Cntr[18])│
│ Pin 3  ⚫────────┼───────→│ DIO 10 (Cntr[17])│
│ Pin 4  ⚫────────┼───────→│ DIO 11 (Cntr[16])│
│ Pin 5 ⚫─────────┼───────→│ GND              │
│ Pin 6  (VCC) ✗  │ DO NOT CONNECT            │
│ Pin 7  ⚫────────┼───────→│ DIO 12 (Cntr[15])│
│ Pin 8  ⚫────────┼───────→│ DIO 13 (Cntr[14])│
│ Pin 9  ⚫────────┼───────→│ DIO 14 (Cntr[13])│
│ Pin 10 ⚫────────┼───────→│ DIO 15 (Cntr[12])│
│ Pin 11 (GND)    │                           │
│ Pin 12 (VCC) ✗  │ DO NOT CONNECT            │
└─────────────────┘        └──────────────────┘
```

## Waveforms Configuration

After wiring, configure Waveforms:

1. **Open Waveforms → Logic Analyzer**

2. **Enable all 16 channels** (DIO 0-15)

3. **Set signal labels**:
   ```
   DIO 0:  "Raw_Button"
   DIO 1:  "Debounced"
   DIO 2:  "SigOutReg"
   DIO 3:  "Counter_Active"
   DIO 4-15: "Counter[23:12]" (as a bus)
   ```

4. **Group counter bits as a bus**:
   - Select DIO 4-15
   - Right-click → "Group"
   - Name: "Counter[23:12]"
   - Display: Decimal or Hex

5. **Set voltage level**: 3.3V (in Device Settings)

6. **Set sample rate**: 100 MHz (max)

7. **Set time base**: 20-50 ms/div

8. **Configure trigger**:
   - Source: DIO 0 (Raw_Button)
   - Type: Rising Edge
   - Position: 25% (capture before trigger)

9. **Run capture and press BTNC** (center button on Nexys Video)

## What You'll See

**Expected capture**:

```
Time →
  
DIO 0 (Raw):      ┐┌┐┌┐┌──────────────    (Multiple bounces)
                  └┘└┘└┘                    

DIO 1 (Debounced): ────────────┐─────────   (Clean, delayed ~10ms)
                                └           

DIO 3 (CntActive): ─┐──────────┐─────────   (High while counting)
                    └──────────┘            

Counter[23:12]:   0→→→→→→3D09→→→→→→→0        (Counts to ~1M, top bits)
                   ▲              ▲
                   Start          Reaches threshold
```

**Key observations**:
1. Raw button shows multiple transitions (bounce)
2. Counter Active goes HIGH when raw ≠ debounced
3. Counter increments from 0 to ~1,000,000 (0xF4240)
4. After 10ms, debounced output changes
5. Counter resets to 0

## Counter Value Reference

The counter counts to **1,000,000** (decimal) = **0xF4240** (hex) = **20 bits**

With DIO 4-15 capturing bits [23:12], you'll see the counter reach:
- **Decimal**: ~3D09 (when looking at top 12 bits only)
- **Binary**: 1111_0100_0010_0100_0000 (full 20-bit value)
  - Bits [23:12] = 0000_1111_0100 = 0x0F4 = 244 decimal

So when the counter maxes out, you should see **244** in the upper 12 bits.

## Safety Checklist

Before powering on:
- [ ] Ground wires connected to Pin 5 on both Pmods
- [ ] No connections to Pin 6 or 12 (VCC)
- [ ] All signal wires properly seated
- [ ] Analog Discovery 2 set to 3.3V logic levels
- [ ] No shorts between adjacent pins

**NEVER connect AD2 digital inputs to 5V signals - damage will occur!**
**All signals in this project are safe 3.3V LVCMOS33**

## Optional: Capturing Lower Counter Bits

If you want to capture JC/JD (lower counter bits and clock), you'll need to:

1. **Run a second capture session** with AD2 connected to JC and JD
2. **Use a second Analog Discovery 2** simultaneously
3. **Focus on JA/JB** which has the most important signals

For most analysis, **JA + JB captures everything you need** to understand debouncing behavior.
