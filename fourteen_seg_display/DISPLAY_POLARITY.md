# LTP-3786E Display Polarity

## Common Anode Configuration

The LTP-3786E displays use **common anode** configuration with the following electrical characteristics:

### Segment Signals (Active-LOW)
- **Logic HIGH (3.3V)**: Segment OFF
- **Logic LOW (0V)**: Segment ON
- To light a segment, pull the pin to ground through a current-limiting resistor
- The code inverts the segment patterns automatically in `segment_multiplexor.vhd`

### Digit Select Signals (Active-HIGH)
- **Logic HIGH (3.3V)**: Digit enabled (selected)
- **Logic LOW (0V)**: Digit disabled (off)
- Pull the digit's common anode pin HIGH to enable that digit
- Only one digit should be enabled at a time during multiplexing

## Current Path

For a segment to light up:
```
FPGA Pin (LOW) → Current-Limiting Resistor (220Ω) → Segment Pin → LED → Common Anode → Digit Select Pin (HIGH) → FPGA
```

## Example

To display "8" on digit 0:
1. Set `DIG[0]` = HIGH (enable digit 0)
2. Set `DIG[1]`, `DIG[2]`, `DIG[3]` = LOW (disable other digits)
3. Set all segment pins LOW to light all segments
4. The code automatically inverts, so you write "11111100100010" in your character patterns and the hardware sees the inverted version

## Code Implementation

In `segment_multiplexor.vhd`:
```vhdl
-- Invert segments for common-anode display (active-low)
-- LTP-3786E requires pulling segments LOW to turn them ON
segments <= not segments_internal;
```

This means:
- Character patterns in `ascii_to_14seg.vhd` use positive logic (1 = ON)
- The hardware inversion converts to negative logic (0 = ON) automatically
- You don't need to think about the inversion when defining characters

## Digit Select

In `top_module.vhd`, the digit select is already active-high:
```vhdl
-- Convert binary digit selector to one-hot for digit enable
process(digit_selector)
begin
    DIG <= (others => '0');
    DIG(to_integer(unsigned(digit_selector))) <= '1';  -- Active high
end process;
```

## Troubleshooting

| Symptom | Likely Cause |
|---------|--------------|
| All segments always ON | Missing segment inversion (should be `not segments_internal`) |
| All segments always OFF | Double inversion or wrong logic level |
| Dim display | Missing/wrong value current-limiting resistors |
| Multiple digits showing at once | Digit select timing issue or not one-hot |
| Wrong digit shows pattern | Digit select mapping incorrect |
| Segments backward/scrambled | Pin mapping wrong in XDC file |
