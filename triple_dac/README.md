# Triple MCP4725 DAC Controller - Three-Phase Sine Wave Generator

This project implements 3 independent I2C controllers on the Nexys Video FPGA to control 3 MCP4725 12-bit DACs. The design generates **three-phase sine waves** with 120° (π/3 radians) phase shifts between each output.

## Architecture

Since the MCP4725 only supports daisy-chaining 2 devices maximum, this design uses **3 separate bit-banged I2C buses** to control all 3 DACs independently.

### Features

- ✅ Three independent 12-bit DAC outputs
- ✅ Sine wave generation with configurable frequency
- ✅ Three-phase outputs (0°, 120°, 240° phase shifts)
- ✅ 64-sample lookup table for smooth waveforms
- ✅ Testbench for simulation verification

### Modules

**HDL:**
- **i2c_master.vhd**: Bit-banged I2C master controller with state machine
- **mcp4725_driver.vhd**: High-level MCP4725 DAC interface
- **sine_generator.vhd**: Sine wave generator with lookup table
- **triple_dac_top.vhd**: Top-level module with 3 sine generators and DACs

**Simulation:**
- **mcp4725_driver_tb.vhd**: Testbench for MCP4725 driver

## Hardware Connections

### I2C Buses (via Pmod connectors)

| DAC | I2C Address | SCL Pin | SDA Pin | Pmod Location |
|-----|-------------|---------|---------|---------------|
| #1  | 0x60        | AB22    | AB21    | JA1, JA2      |
| #2  | 0x61        | AB20    | AB18    | JA7, JA8      |
| #3  | 0x62        | V9      | V8      | JB1, JB2      |

### Status LEDs

- LED0 (T14): DAC #1 busy
- LED1 (T15): DAC #2 busy  
- LED2 (T16): DAC #3 busy

### Clock & Reset

- Clock: 100 MHz (R4)
- Reset: CPU_RESET button (G4, active-low)

## MCP4725 Wiring

Each MCP4725 needs:
- VDD: 3.3V
- GND: Ground
- SCL: Connect to corresponding SCL pin above
- SDA: Connect to corresponding SDA pin above
- A0: Configure I2C address (see datasheet)

**Address Configuration:**
- DAC #1: A0 = GND → Address 0x60
- DAC #2: A0 = VDD → Address 0x61  
- DAC #3: A0 = VDD (via 10kΩ pullup) → Address 0x62

## Build Instructions

```bash
cd /home/eddie/fpga_projects/triple_dac
vivado -mode batch -source build.tcl
```

The bitstream will be generated at:
```
build/triple_dac_controller/triple_dac_controller.runs/impl_1/triple_dac_top.bit
```

## Usage

The design automatically generates three-phase sine waves on the DAC outputs. No external control is needed.

### Output Characteristics

- **Default Frequency**: 10 Hz (configurable via generic)
- **Phase Relationships**:
  - DAC 1: 0° (reference)
  - DAC 2: 120° leading
  - DAC 3: 240° leading (or 120° lagging)
- **Output Range**: 0-4095 (12-bit), centered at 2048
- **Samples per Cycle**: 64

### Waveform Visualization

```
DAC1: ___/‾‾‾\___ (0°)
DAC2:  /‾‾‾\___/‾ (120°)
DAC3: ‾\___/‾‾‾\_ (240°)
```

## Customization

### Change sine wave frequency
Modify the `SINE_FREQ` generic when instantiating the top module, or edit the default in `triple_dac_top.vhd`:
```vhdl
Generic (
    SINE_FREQ => 10  -- Frequency in Hz
);
```

**Frequency Range:**
- Minimum: ~1 Hz (limited by I2C update rate)
- Maximum: ~1500 Hz (64 samples × ~24 Hz max I2C update rate)
- Recommended: 1-100 Hz for smooth waveforms

### Change I2C speed
Modify the `I2C_FREQ` generic in the DAC instantiations:
```vhdl
I2C_FREQ => 100_000,  -- 100 kHz (standard mode)
I2C_FREQ => 400_000,  -- 400 kHz (fast mode - allows higher sine frequencies)
```

### Modify phase offsets
Edit the `PHASE_OFFSET` generic in `triple_dac_top.vhd`:
```vhdl
PHASE_OFFSET => 0    -- DAC 1: 0°
PHASE_OFFSET => 120  -- DAC 2: 120°
PHASE_OFFSET => 240  -- DAC 3: 240°
```

## Simulation

Run the testbench in Vivado:
```bash
cd /home/eddie/fpga_projects/triple_dac
vivado -mode batch -source build.tcl
# Then in Vivado GUI:
# Flow Navigator → Run Simulation → Run Behavioral Simulation
```

Or use GHDL/ModelSim:
```bash
ghdl -a src/hdl/i2c_master.vhd
ghdl -a src/hdl/mcp4725_driver.vhd
ghdl -a src/sim/mcp4725_driver_tb.vhd
ghdl -e mcp4725_driver_tb
ghdl -r mcp4725_driver_tb --wave=waveform.ghw
```

## Project Structure

```
triple_dac/
├── build.tcl              # Vivado build script
├── build/                 # Build output directory
├── src/
│   ├── hdl/               # VHDL source files
│   │   ├── i2c_master.vhd
│   │   ├── mcp4725_driver.vhd
│   │   ├── sine_generator.vhd
│   │   └── triple_dac_top.vhd
│   ├── sim/               # Simulation files
│   │   └── mcp4725_driver_tb.vhd
│   └── constraints/       # Constraint files
│       └── nexys_video.xdc
└── README.md
```

## Notes

- I2C runs at 100 kHz by default (standard mode)
- Each I2C transaction takes ~1ms to complete
- All 3 DACs can be updated simultaneously (independent buses)
- Pull-up resistors on SCL/SDA lines are recommended (typically 4.7kΩ for 100kHz)
- The sine wave lookup table uses 64 samples for smooth waveforms
- Three-phase systems are commonly used in:
  - AC motor control
  - Power systems
  - Signal processing applications
  - Test and measurement

## Applications

- **Three-phase motor control**: Drive BLDC/stepper motors
- **Power electronics testing**: Simulate three-phase AC systems
- **Audio synthesis**: Complex waveform generation
- **Education**: Demonstrate phase relationships and AC theory
