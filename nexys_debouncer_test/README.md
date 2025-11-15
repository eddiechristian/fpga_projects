# Nexys Video Debouncer Analysis with Analog Discovery 2

Complete guide for analyzing button debouncing behavior using Digilent Waveforms software.

## Table of Contents
1. [Project Overview](#project-overview)
2. [Building the Project](#building-the-project)
3. [Hardware Setup](#hardware-setup)
4. [Waveforms Configuration](#waveforms-configuration)
5. [Creating Counter Bus](#creating-counter-bus)
6. [Capturing Data](#capturing-data)
7. [Advanced Analysis](#advanced-analysis)

## Project Overview

This project exposes internal debouncer signals for complete visibility:

- **Raw button signal** (with bounce)
- **Debounced output** (clean signal)
- **Internal state register** (sig_out_reg)
- **Counter value** (24-bit, counts to 1,000,000)
- **Counter active flag** (HIGH when counting)

**Debounce Time**: 10ms (1,000,000 clock cycles at 100MHz)

## Building the Project

```bash
cd /home/eddie/fpga_projects/nexys_debouncer_test

# Create Vivado project
vivado -mode batch -source scripts/create_project.tcl

# Build bitstream
vivado -mode batch -source scripts/build_project.tcl
```

After build completes, program the Nexys Video using Vivado Hardware Manager.

## Hardware Setup

See **WIRING_GUIDE.md** for complete wiring diagrams.

**Quick Reference**:
- AD2 DIO 0-7 → Pmod JA
- AD2 DIO 8-15 → Pmod JB  
- AD2 GND → JA Pin 5 and JB Pin 5

## Waveforms Configuration

### Step 1: Open Logic Analyzer

1. Launch **Waveforms** software
2. Connect to your Analog Discovery 2
3. Click **Logic** icon (or Welcome → Logic Analyzer)

### Step 2: Initial Setup

1. **Set Voltage Level**:
   - Click **Device Settings** (gear icon in top-right)
   - Under **Digital**, set **IO Voltage** to **3.3V**
   - Click **Apply**

2. **Enable All Channels**:
   - In the Signal panel (left side), you'll see DIO 0 through DIO 15
   - Click the **+** icon next to each channel to enable it
   - OR click **Add** → **Bus** (we'll configure this next)

### Step 3: Label Individual Signals

Before creating buses, label the primary signals:

1. **Right-click on DIO 0** → **Rename** → `Raw_Button`
2. **Right-click on DIO 1** → **Rename** → `Debounced`
3. **Right-click on DIO 2** → **Rename** → `SigOutReg`
4. **Right-click on DIO 3** → **Rename** → `Counter_Active`

## Creating Counter Bus

Now create a bus from the counter bits (DIO 4-15):

### Method 1: Manual Bus Creation

1. **Add a new bus**:
   - Click **Add** button in Signals panel
   - Select **Bus**

2. **Configure the bus**:
   - **Name**: `Counter[23:12]`
   - **Radix**: Choose **Decimal** or **Hexadecimal**
   - Click **OK**

3. **Assign channels to bus**:
   - In the bus configuration, click **Bit 11** (MSB shown at top)
   - Assign it to **DIO 4** (which carries Counter[23])
   - Click **Bit 10** → assign to **DIO 5** (Counter[22])
   - Continue for all bits:
     ```
     Bus Bit 11 → DIO 4  (Counter[23])
     Bus Bit 10 → DIO 5  (Counter[22])
     Bus Bit 9  → DIO 6  (Counter[21])
     Bus Bit 8  → DIO 7  (Counter[20])
     Bus Bit 7  → DIO 8  (Counter[19])
     Bus Bit 6  → DIO 9  (Counter[18])
     Bus Bit 5  → DIO 10 (Counter[17])
     Bus Bit 4  → DIO 11 (Counter[16])
     Bus Bit 3  → DIO 12 (Counter[15])
     Bus Bit 2  → DIO 13 (Counter[14])
     Bus Bit 1  → DIO 14 (Counter[13])
     Bus Bit 0  → DIO 15 (Counter[12])
     ```

### Method 2: Quick Selection

1. **Select multiple channels**:
   - Hold **Ctrl** and click DIO 4 through DIO 15
   
2. **Right-click** → **Group**

3. **Configure**:
   - Name: `Counter[23:12]`
   - Radix: **Decimal**
   - Bit order: **MSB first** (DIO 4 = MSB)

### Step 4: Configure Display

Your signal list should now show:

```
☑ Raw_Button (DIO 0)
☑ Debounced (DIO 1)
☑ SigOutReg (DIO 2)
☑ Counter_Active (DIO 3)
☑ Counter[23:12] (DIO 4-15) - Decimal
```

## Capturing Data

### Step 5: Configure Acquisition

1. **Sample Rate**:
   - Set to **100 MHz** (maximum)
   - This matches the FPGA clock frequency

2. **Buffer Size**:
   - Set to **16384** samples (or higher if available)
   - This gives you ~164μs of capture time

3. **Time Base**:
   - Set horizontal zoom to **20-50 ms/div**
   - This lets you see the full 10ms debounce cycle

### Step 6: Configure Trigger

1. **Click Trigger tab** (at top)

2. **Set trigger**:
   - **Source**: `Raw_Button` (DIO 0)
   - **Type**: **Edge**
   - **Slope**: **Rising** (↑)
   - **Position**: **25%** (captures before the trigger event)

3. This will trigger when you press the button, capturing the bounce

### Step 7: Capture

1. **Arm the capture**:
   - Click **Single** button (captures one trigger event)
   - OR click **Run** for continuous capture

2. **Press BTNC** on Nexys Video (center button)

3. **Observe the waveforms**

## Expected Results

You should see:

```
Time (ms): 0        5        10       15       20
           ├────────┼────────┼────────┼────────┤

Raw_Button:     ┐┌┐┌┐┌──────────────
                └┘└┘└┘                  ← Multiple bounces

Debounced:      ────────────┐─────────
                            └            ← Clean edge after ~10ms

SigOutReg:      ────────────┐─────────  
                            └            ← Matches debounced

Counter_Active: ─┐──────────┐─────────
                 └──────────┘            ← HIGH while counting

Counter[23:12]: 0 →→→→→ 244 →→→→→ 0
                  ↑          ↑           ← Counts up then resets
               Starts    Reaches
                        threshold
```

**Key Points**:
- Counter maxes at **244** (decimal) in the upper 12 bits
- Full counter value is 1,000,000 = 0xF4240 (20 bits)
- Upper 12 bits [23:12] = 0x0F4 = 244 decimal
- Takes exactly 10ms to count (1M cycles at 100MHz)

## Advanced Analysis

### Analysis 1: Measuring Bounce Characteristics

**Goal**: Quantify button bounce - how many bounces occur, their duration, and the total bounce period.

#### Step-by-Step Procedure:

1. **Capture a button press** (as described above)

2. **Zoom into the bounce region**:
   - Use mouse scroll wheel or zoom tools
   - Focus on the first 1-5ms after trigger
   - You should see multiple transitions on Raw_Button

3. **Use Cursors to measure**:
   - Enable **Time Cursors**: Click **Cursors** button (top toolbar)
   - You'll see two vertical lines (usually labeled T1 and T2)
   
4. **Measure each bounce**:
   
   **First bounce duration**:
   - Place **Cursor 1** (T1) at the first rising edge
   - Place **Cursor 2** (T2) at the first falling edge
   - Read **ΔT** (delta time) in the cursor display
   - This is the width of the first bounce pulse
   - Typical: **10-500 μs**

   **Time between bounces**:
   - Place **T1** at the falling edge of first bounce
   - Place **T2** at the rising edge of second bounce
   - Read **ΔT** = time between bounces
   - Typical: **50-200 μs**

5. **Count total bounces**:
   - Use the **Measurements** panel
   - Add **Positive Pulses** measurement on Raw_Button
   - Set time range to first 5ms
   - This counts how many HIGH pulses occur
   - Typical: **3-10 bounces**

6. **Measure total bounce period**:
   - Place **T1** at the first transition (button press)
   - Place **T2** at the last transition (bounce stops)
   - Read **ΔT** = total bounce duration
   - Typical: **1-5 ms**

7. **Compare to debounce threshold**:
   - Note when **Debounced** signal changes (should be at ~10ms)
   - Confirm it only changes AFTER all bouncing has stopped
   - If bounce period is 3ms, debouncer has 7ms margin

#### Measurements to Record:

Create a table like this:

| Metric | Value | Notes |
|--------|-------|-------|
| Number of bounces | ___ | Count transitions on Raw_Button |
| First bounce width | ___ μs | Cursor measurement |
| Shortest bounce | ___ μs | Find minimum pulse width |
| Longest bounce | ___ μs | Find maximum pulse width |
| Time between bounces | ___ μs | Typical gap |
| Total bounce period | ___ ms | First to last transition |
| Debounce delay | ~10 ms | Time to stable output |

#### Using Waveforms Measurements Tool:

1. **Open Measurements Panel**:
   - Click **View** → **Measurements** (if not visible)

2. **Add measurements**:
   - Click **Add** in Measurements panel
   - Select signal: **Raw_Button**
   - Add these measurements:
     - **Positive Pulses** (counts bounces)
     - **Frequency** (if bouncing is periodic)
     - **Period** (time between edges)
     - **Pulse Width Positive** (HIGH time)
     - **Pulse Width Negative** (LOW time)

3. **Set measurement range**:
   - Use cursors to define the range
   - Only measure during the bounce period (first few ms)

4. **View statistics**:
   - Waveforms will show min/max/average for each measurement
   - This gives you bounce characteristics across multiple captures

#### Exporting Data:

1. **Save waveform**:
   - **File** → **Export** → **Image**
   - Save as PNG for documentation

2. **Export raw data**:
   - **File** → **Export** → **Data**
   - Save as CSV for analysis in Excel/Python
   - Columns will be: Time, DIO0, DIO1, DIO2, etc.

3. **Take screenshots**:
   - Capture zoomed views of interesting regions
   - Annotate with measurement cursors visible

#### What to Look For:

**Good button**:
- Few bounces (2-5)
- Short bounce duration (<2ms total)
- Regular spacing

**Worn/bad button**:
- Many bounces (>10)
- Long bounce period (>5ms)
- Irregular, multiple clusters of bounces

**Debouncer effectiveness**:
- Should suppress ALL bounces
- Output changes only once
- Adequate margin (bounce period << debounce time)

### Analysis 2: Counter Behavior

**Goal**: Verify counter operation and timing.

1. **View counter as analog trace**:
   - Right-click on Counter bus
   - Select **Analog** display mode
   - You'll see a ramp from 0 to 244

2. **Measure counting rate**:
   - Place cursors at counter = 0 and counter = 244
   - ΔT should be ~10ms (exactly 1,000,000 cycles)
   - Confirms 100MHz clock

3. **Check counter reset**:
   - Observe counter drops to 0 when:
     - Raw signal matches SigOutReg (no change needed)
     - Counter reaches maximum and output updates

### Analysis 3: Comparing Signals

**Goal**: Verify debouncer logic.

1. **Stack signals vertically**:
   - Arrange signals in this order:
     ```
     Raw_Button
     Counter_Active
     Counter[23:12]
     SigOutReg
     Debounced
     ```

2. **Observations to verify**:
   - **Counter_Active** goes HIGH when Raw ≠ SigOutReg
   - **Counter** only increments when Counter_Active is HIGH
   - **SigOutReg** and **Debounced** always match
   - **Debounced** changes exactly when counter reaches max

3. **Add markers**:
   - Right-click on waveform → **Add Marker**
   - Label key events:
     - "Button Press"
     - "Bounce Ends"  
     - "Counter Reaches Max"
     - "Output Changes"

### Analysis 4: Protocol/Timing Diagram

**Goal**: Create publication-quality timing diagram.

1. **Zoom to show complete cycle** (0-15ms)

2. **Adjust signal heights**:
   - Make important signals taller (drag separator lines)
   - Raw_Button and Debounced should be prominent

3. **Use Persistence Mode**:
   - Click **Mode** → **Screen**
   - Select **Persistence**
   - Capture multiple button presses
   - Shows variation in bounce behavior

4. **Export high-quality image**:
   - **File** → **Export** → **Image**
   - Set resolution: **1920x1080** or higher
   - Use for reports/documentation

## Tips and Tricks

### Improving Capture Quality

1. **Trigger too sensitive**:
   - Add **Hysteresis** in trigger settings
   - Set **Holdoff** time (ignore triggers for X ms after first trigger)

2. **Need longer capture**:
   - Reduce sample rate to 10MHz or 1MHz
   - Captures 10x or 100x longer time period
   - Still sufficient for 10ms debounce analysis

3. **Want to see FPGA clock**:
   - Connect to Pmod JD Pin 7 (clock divider output, ~95Hz)
   - Use as timing reference for slower analysis

### Waveforms Math Functions

1. **Calculate counter rate**:
   - **Math** → **Add Channel**
   - Formula: `diff(Counter[23:12])`
   - Shows rate of change (should be constant ~100MHz)

2. **Detect edges**:
   - **Math** → **Add Channel**  
   - Formula: `edge(Raw_Button)`
   - Shows impulse at each transition

## Troubleshooting

**No signals captured**:
- Check ground connections (JA Pin 5, JB Pin 5)
- Verify FPGA is programmed (Done LED lit)
- Check AD2 voltage setting (must be 3.3V)

**Counter always shows 0**:
- Counter only increments during button press/release
- Press and hold button, then release while capturing
- Check Counter_Active signal (should go HIGH)

**Debounced signal never changes**:
- May need to capture for longer (>20ms)
- Check that Raw_Button signal is reaching FPGA
- Verify button works (check Raw_Button toggles)

**Trigger not firing**:
- Change trigger to **Normal** mode (not Auto)
- Adjust trigger level (default is 50%)
- Try triggering on falling edge instead

## Next Steps

1. **Test different buttons**: Compare bounce characteristics
2. **Adjust debounce time**: Edit RTL and observe effect
3. **Stress test**: Rapid button presses to find worst-case
4. **Long-term capture**: Look for drift or timing issues

## Reference

- **Counter maximum**: 1,000,000 (0xF4240)
- **Counter bits captured**: [23:12] = upper 12 bits
- **Visible counter max**: 244 decimal (0x0F4)
- **Debounce time**: 10ms
- **FPGA clock**: 100MHz
- **All voltages**: 3.3V LVCMOS33 (safe for AD2)

## Additional Resources

- `WIRING_GUIDE.md` - Complete pin-by-pin wiring
- `rtl/debounce_test_top.vhd` - Top-level RTL
- `rtl/debouncer_instrumented.vhd` - Debouncer with debug
- `constraints/nexys_video.xdc` - Pin constraints

---

**Safety**: This project uses 3.3V logic levels - safe for Analog Discovery 2. Never connect AD2 to 5V signals!
