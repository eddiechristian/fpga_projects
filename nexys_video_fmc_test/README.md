# Nexys Video FMC Bidirectional Test

FPGA project demonstrating bidirectional (inout) FMC ports on the Digilent Nexys Video board. Switches drive FMC pins, and LEDs read the same FMC pins.

## Overview

This project uses **inout** ports for the FMC connector, allowing the same pins to be both driven and read:

**Switch → FMC Pin (bidirectional) → LED**

- When **switch is HIGH**: FPGA drives FMC pin to '1', LED reads '1' (LED on)
- When **switch is LOW**: FPGA sets FMC pin to Hi-Z (high impedance), LED reads external signal or defaults to '0' (LED off)

## How It Works

The design uses tri-state buffers:
- **Switch = 1**: FMC pin is driven high ('1')
- **Switch = 0**: FMC pin is in high-impedance state ('Z')
- **LED**: Always reads the current state of the FMC pin

This allows you to:
1. Drive signals out to FMC pins when switches are on
2. Read back what's on those same pins (could be your own signal or external)
3. Test bidirectional communication with FMC peripherals

## Hardware Requirements

- Digilent Nexys Video FPGA board (XC7A200T)
- FMC breakout card or adapter (optional - can test without external connections)
- Multimeter or oscilloscope to verify FMC output (optional)

## Testing

### Basic Test (No External Hardware)
1. Program the FPGA
2. Toggle switches SW0-SW7
3. LEDs should mirror the switch states (switch on → LED on)

### Loopback Test (With FMC Card)
1. Connect jumper wires on FMC card: LA00_P → LA01_P, LA02_P → LA03_P, etc.
2. Toggle switches to see cross-channel effects

### External Drive Test
1. When switch is OFF (low), the FMC pin is Hi-Z
2. You can externally drive the pin high (with FMC card)
3. LED will show the externally driven value

## Pin Mapping

### Board I/O
- **Switches**: SW0-SW7 (E22, F21, G21, G22, H17, J16, K13, M17)
- **LEDs**: LED0-LED7 (T14, T15, T16, U16, V15, W16, W15, Y13)

### FMC Connector (Bidirectional)
| Channel | FMC Pin | FPGA Pin | Signal |
|---------|---------|----------|--------|
| 0 | LA00_P/N | AB14/AC14 | SW0 ↔ LED0 |
| 1 | LA01_P/N | Y15/Y16 | SW1 ↔ LED1 |
| 2 | LA02_P/N | AA15/AB15 | SW2 ↔ LED2 |
| 3 | LA03_P/N | AA14/AB16 | SW3 ↔ LED3 |
| 4 | LA04_P/N | Y17/AA17 | SW4 ↔ LED4 |
| 5 | LA05_P/N | V17/W17 | SW5 ↔ LED5 |
| 6 | LA06_P/N | V18/W18 | SW6 ↔ LED6 |
| 7 | LA07_P/N | AB17/AC17 | SW7 ↔ LED7 |

All FMC pins use **LVCMOS18** I/O standard.

## Building

```bash
cd nexys_video_fmc_test
vivado -mode batch -source build.tcl
```

Or in Vivado GUI:
```tcl
source build.tcl
```

## Programming

```bash
# Open Hardware Manager in Vivado
# Connect board
# Program with: build/nexys_video_fmc_test.runs/impl_1/top_module.bit
```

## Project Structure

```
nexys_video_fmc_test/
├── build.tcl                    # Vivado build script
├── build/                       # Build output (generated)
├── README.md                    # This file
└── src/
    ├── hdl/
    │   └── top_module.vhd      # Bidirectional port design
    ├── sim/                     # Simulation files
    └── constraints/
        └── nexys_video.xdc     # Pin constraints
```

## Key VHDL Concepts

### Tri-State Buffer
```vhdl
fmc_la_p(i) <= '1' when sw(i) = '1' else 'Z';
```
- Drives '1' when condition true
- High-impedance ('Z') otherwise

### Bidirectional Read
```vhdl
led(i) <= fmc_la_p(i);
```
- LED reads current state of FMC pin
- Works whether pin is driven or Hi-Z

## Customization

- **More channels**: Extend vectors to use LA08-LA31
- **Pull-ups/downs**: Add PULLUP or PULLDOWN properties in XDC
- **Different logic**: Modify tri-state conditions (e.g., enable signal)

## Safety Notes

- FMC pins are 1.8V (LVCMOS18) - don't apply higher voltages
- When driving externally, ensure switch is OFF to avoid contention
- Use current-limiting resistors on any external drivers
