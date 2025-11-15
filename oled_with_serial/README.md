# OLED Display with Serial Input (VHDL)

This project implements an OLED display controller with UART serial input for the **Nexys Video FPGA board**. Type into a serial terminal and see your text appear on the onboard OLED display with automatic scrolling.

## Features

- **Pure VHDL Implementation**: All modules in VHDL
- **UART Serial Input**: 9600 baud receiver for terminal communication  
- **Text Buffer**: 256-character scrolling buffer (16 lines × 16 chars)
- **Block RAM Integration**: Uses Vivado Block Memory Generator IP
- **Automated Setup**: TCL scripts for complete project creation
- **Character Display**: 128x32 OLED (4 rows × 16 characters)
- **Demo Sequence**: Alphabet → Splash screen → Serial mode
- **Debug LEDs**: Monitor UART activity and mode status

## Hardware

- **Target Board**: Digilent Nexys Video (XC7A200T)
- **Display**: Onboard 128x32 OLED (SSD1306 compatible)
- **Serial**: USB-UART at 9600 baud (8N1)
- **Clock**: 100 MHz system clock

## Quick Start

### Build and Program

```bash
vivado -mode tcl -source build_and_program.tcl
```

### Connect Serial Terminal

```bash
screen /dev/ttyUSB0 9600
```

Type and your text appears on the OLED with automatic scrolling!

**To exit screen:** Press `Ctrl-A` then `K`, then `Y`

## Expected Behavior

After programming:
1. Display alphabet for 4 seconds
2. Show splash screen: "Connect serial to computer and type..." (3 seconds)
3. Enter serial mode (blank screen, ready for input)
4. Display refreshes every 50ms
5. Auto-scroll every 1 second

## Pin Assignments

| Signal | Pin | Description |
|--------|-----|-------------|
| clk | R4 | 100 MHz system clock |
| rstn | G4 | Reset button (active low) |
| uart_rxd | V18 | USB-UART receive (9600 baud) |
| led[0] | T14 | Debug: UART data received (blinks) |
| led[1] | T15 | Debug: Serial mode active |
| led[2] | T16 | Debug: Buffer has data |
| led[3] | U16 | Debug: UART RX line state |
| oled_* | Various | OLED SPI interface |

## Module Descriptions

### uart_rx.vhd
UART receiver operating at 9600 baud (8N1). Synchronizes input and provides `rx_valid` pulse when character received.

### text_buffer.vhd
256-character circular buffer with scrolling. Handles special characters (Enter, Backspace) and provides windowed view for display.

### oled_master.vhd
Top-level module managing state machine for demo sequence and serial mode. Coordinates between UART, text buffer, and OLED controller.

### oled_ctrl.vhd
Main OLED controller handling initialization, character-to-pixel conversion, and display updates via SPI.

## Troubleshooting

### No serial input appearing
- Check LED0 - should blink when typing
- Verify baud rate: 9600
- Correct port: `/dev/ttyUSB0`
- UART pin V18 (not AA19)

### OLED doesn't turn on
- Press reset button (BTN0)
- Reprogram: `vivado -mode tcl -source program.tcl`

### Design lost after power off
- Currently programmed to SRAM (volatile)
- Reprogram after each power cycle
- For persistent: need flash programming (more complex)

## License

Based on Digilent's OLED example, converted to VHDL with serial input added.
