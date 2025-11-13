# OLED Display IP Blocks Documentation

## Overview
This document describes the role of the three Xilinx Block Memory Generator (BRAM) IP blocks used in the OLED display controller for the UG-2832HSWEG04 display with Solomon Systech SSD1306 controller.

## Role of Each IP Block

### 1. **init_sequence_rom** (16 entries, 16-bit data)

**Purpose**: Stores the SSD1306 initialization sequence commands

**Specifications**:
- Address width: 4 bits (16 entries)
- Data width: 16 bits
- Type: Read-only memory (ROM)
- Memory type: Distributed RAM

**Data Format**: Each 16-bit word encodes a command plus control flags:
```
Bit 14:    iop_state_select  (0=delay operation, 1=SPI data command)
Bit 13:    iop_res_set       (assert RES signal)
Bit 12:    iop_res_val       (RES value)
Bit 11:    iop_vdd_set       (assert VDD signal)
Bit 10:    iop_vdd_val       (VDD value)
Bit 9:     iop_vbat_set      (assert VBAT signal)
Bit 8:     iop_vbat_val      (VBAT value)
Bits [7:0]: Data             (SPI command or delay in milliseconds)
```

**Example Initialization Sequence** (from `init_sequence_rom.mif`):
- Address 0: `0001100100000001` → VDD on (active low), delay 1ms
- Address 1: `0101000110101110` → Send 0xAE (DisplayOff command)
- Address 8: `0001001001100100` → VBAT on, delay 100ms
- Address 15: `0101000010101111` → Send 0xAF (DisplayOn command)

**Usage in Code**: `OLED_ctrl.v` lines 215-219, lines 289-298

**Datasheet Reference**: SSD1306 datasheet Section 8 (Command Table) and Section 9 (Initialization Sequence)

---

### 2. **charLib** (1024 entries, 8-bit data)

**Purpose**: Font bitmap library storing 7×8 pixel character glyphs for ASCII characters

**Specifications**:
- Address width: 10 bits (1024 entries)
- Data width: 8 bits
- Type: Read-only memory (ROM)
- Memory type: Block RAM (18K BRAM)
- Initialized from: `charLib.mif`

**Memory Organization**:
```
Total entries: 1024 (1K × 8-bit)
ASCII characters: 128 printable characters (space to ~)
Bytes per character: 8 (rows 0-7)

Address mapping: {ASCII_code[6:0], row[2:0]}
Example: Character 'A' (0x41) at row 3 → Address = 0x21B
```

**Data Content**: Each 8-bit entry represents one horizontal row of a character bitmap
- Bit position = pixel position in row
- Set bit = pixel on, Clear bit = pixel off
- Forms 8×8 character glyphs

**Usage in Code**: `OLED_ctrl.v` lines 174-178, line 160
```verilog
assign char_lib_addr = {temp_write_ascii, write_byte_count};
assign pbuf_write_data = pbuf_write_data;  // charLib output
```

**Datasheet Reference**: SSD1306 datasheet Section 10.1 (GDDRAM Display Data RAM) describes page-based addressing that aligns with 8-pixel character rows

---

### 3. **pixel_buffer** (512 entries, 8-bit data, dual-port RAM)

**Purpose**: Framebuffer storing the entire display content

**Specifications**:
- Address width: 9 bits (512 entries)
- Data width: 8 bits
- Type: Dual-port RAM (one read port, one write port)
- Memory type: Block RAM (18K BRAM)
- Read mode: READ_FIRST

**Memory Organization**:
```
Total entries: 512 bytes
Display dimensions: 128 pixels wide × 32 pixels tall
Page-based organization: 128 pixels × 4 pages (8 pixels per page)

Address mapping: {page[1:0], column[6:0]}
Address range: 0x000 to 0x1FF
```

**Port Configuration**:

**Port A (Write)**:
- Used by: OLED controller when writing characters
- Signal mapping:
  - `addra[8:0]`: Write address = `temp_write_base_addr + write_byte_count`
  - `dina[7:0]`: Write data from `charLib` (character bitmap row)
  - `wea[0]`: Write enable (1 during `ActiveWrite` state)

**Port B (Read)**:
- Used by: OLED controller when updating display
- Signal mapping:
  - `addrb[8:0]`: Read address = `{temp_page[1:0], temp_index[6:0]}`
  - `doutb[7:0]`: Read data sent to OLED via SPI

**Usage in Code**: `OLED_ctrl.v` lines 194-202, lines 159-162

**Datasheet Reference**: SSD1306 datasheet Section 10.1.3 (Page Addressing Mode) describes the page-based GDDRAM organization that `pixel_buffer` implements

---

## Font Character Examples

The `charLib` ROM stores font bitmaps. Each character occupies 8 bytes (one per row), with each byte representing the 8-pixel width of that row.

### Character '4' (ASCII 0x34)
**charLib.mif lines 418-424** (address 416-423):
```
00011000  = ...██...
00010100  = ...█.█..
00010010  = ...█..█.
01111111  = .███████
00010000  = ...█....
00000000  = ........
00000000  = ........
```

Visualized on display:
```
   ██
   █ █
   █  █
███████
   █
```

### Character 'T' (ASCII 0x54)
**charLib.mif lines 673-680** (address 672-679):
```
00000011  = ......██
00000001  = .......█
01000001  = .█.....█
01111111  = .███████
01000001  = .█.....█
00000001  = .......█
00000011  = ......██
00000000  = ........
```

Visualized on display:
```
      ██
       █
 █     █
 ███████
 █     █
       █
      ██
```

### Character 'W' (ASCII 0x57)
**charLib.mif lines 697-704** (address 696-703):
```
00000001  = .......█
00011111  = ...█████
01100001  = .██....█
00010100  = ...█.█..
01100001  = .██....█
00011111  = ...█████
00000001  = .......█
00000000  = ........
```

Visualized on display:
```
       █
   █████
 ██    █
   █ █
 ██    █
   █████
       █
```

---

## Data Flow Architecture

```
┌──────────────┐
│   charLib    │  Font bitmap lookup
│  (1K × 8)    │  {ASCII_code, row}
└──────┬───────┘
       │ 8-bit character row data
       ▼
┌──────────────┐
│pixel_buffer  │  Frame buffer
│  (512 × 8)   │  Dual-port RAM
│ dual-port    │
└──────┬───────┘
       │ Display data
       ▼
┌──────────────┐
│  SPI CTRL    │  Serial transmission to OLED
│   & OLED     │  via SPI protocol
└──────────────┘
```

**Pipeline Stages**:
1. **Character Write Phase**: `charLib` lookup → `pixel_buffer` write port
2. **Display Update Phase**: `pixel_buffer` read port → SPI transmit
3. **Initialization Phase**: `init_sequence_rom` → SPI transmit

This staged approach decouples character rendering from display updates, eliminating latency blocking during display refresh.

---

## Initialization Sequence Details

The `init_sequence_rom` contains 16 operations executed during startup (`StartupFetch` and `Startup` states in `OLED_ctrl.v`):

1. Turn VDD on (active low), delay 1ms
2. Send DisplayOff command (0xAE)
3. Assert RES (active low), delay 1ms
4. Deassert RES, delay 1ms
5. Send ChargePump1 command (0x8D)
6. Send ChargePump2 command (0x14)
7. Send PreCharge1 command (0xD9)
8. Send PreCharge2 command (0xF1)
9. Turn VBAT on (active low), delay 100ms
10. Send DispContrast1 command (0x81)
11. Send DispContrast2 command (0x0F)
12. Send SetSegRemap command (0xA0)
13. Send SetScanDirection command (0xC0)
14. Send Multiplex Ratio command (0xDA)
15. Send Multiplex Ratio value (0x00)
16. Send DisplayOn command (0xAF)

---

## SSD1306 Datasheet References

When working with these IP blocks, refer to the SSD1306 datasheet sections:

- **Section 8**: Command Table - initialize sequence commands sent via `init_sequence_rom`
- **Section 9**: Initialization Sequence - recommended setup procedure
- **Section 10.1**: Display Data RAM (GDDRAM) - page-based addressing scheme used by `pixel_buffer`
- **Section 10.1.3**: Page Addressing Mode - explains the 4-page × 128-column organization
- **Section 11**: Character ROM (if applicable) - reference for custom font design

---

## File Locations

- **Controller**: `hw.srcs/sources_1/imports/src/hdl/OLED_ctrl.v`
- **Master**: `hw.srcs/sources_1/imports/src/hdl/OLED_master.v`
- **IP Definitions**:
  - `hw.gen/init_sequence_rom/`
  - `hw.gen/charLib/`
  - `hw.gen/pixel_buffer/`
- **Initialization Data**: `hw.gen/init_sequence_rom/ip/init_sequence_rom/init_sequence_rom.mif`
- **Font Data**: `hw.gen/charLib/ip/charLib/charLib.mif`
