# Crossbar FP Resource Sharing System

A crossbar switch interconnect that allows N producers (e.g., sphere computation units) to dynamically access M floating-point units with full parallel capability and proper arbitration.

## Architecture Overview

The system implements a non-blocking crossbar switch with:
- **10 Producers**: Can issue FP operations concurrently
- **10 MULT Units**: FP32 multipliers (2-cycle latency)
- **5 FMA Units**: FP32 fused multiply-add (2-cycle latency)
- **3 AddSub Units**: FP32 add/subtract (2-cycle latency)
- **Total**: 18 FP execution units

### Key Features

- **Round-robin arbitration**: Fair scheduling, prevents producer starvation
- **Non-blocking FP units**: Maximum throughput, no backpressure
- **TID-based result routing**: Transaction IDs track operations through pipeline
- **Output FIFOs**: Per-producer buffering (depth 8) for burst absorption
- **Single-cycle arbitration**: Minimal latency from request to grant

### Performance

- **Arbitration Latency**: 1 cycle
- **FP Unit Latency**: 2 cycles
- **Total Request-to-Result**: 3 cycles minimum
- **Throughput**: 
  - 10 MULT units × 1 op/cycle = 1 GFLOP @ 100MHz
  - 5 FMA units × 2 ops/cycle = 1 GFLOP @ 100MHz
  - 3 AddSub units × 1 op/cycle = 300 MFLOP @ 100MHz
  - **Total: ~2.3 GFLOPS @ 100MHz**

### Resource Estimates (Artix-7 XC7A200T)

- **LUTs**: ~20,000 (15%)
- **FFs**: ~600 (<1%)
- **DSPs**: ~30 (4%)
- **BRAM**: Minimal (output FIFOs use distributed RAM)

## Module Hierarchy

```
crossbar_fp_system (top)
├── crossbar_arbiter          # Round-robin arbiter for all FP units
├── crossbar_input_mux        # N:1 muxes route data to FP units
├── fp_mult_wrapper (×10)     # FP32 multiplier wrappers
├── fp_fma_wrapper (×5)       # FP32 FMA wrappers
├── fp_addsub_wrapper (×3)    # FP32 AddSub wrappers
└── crossbar_output_router    # TID-based routing with output FIFOs
    └── simple_fifo (×10)     # One per producer
```

### Core Components

#### crossbar_pkg.vhd
Package with types, constants, and utility functions:
- `producer_request_t`, `producer_grant_t`, `producer_result_t`
- `unit_type_t` enum (MULT, FMA, ADDSUB)
- TID encoding/decoding functions
- Array types for all interfaces

#### crossbar_arbiter.vhd
Arbitrates access to FP units using round-robin scheduling:
- One priority pointer per FP unit
- Processes all requests in parallel
- Generates grant signals and mux selects
- Updates priority pointers each cycle

#### crossbar_input_mux.vhd
Combinational multiplexers route producer data to FP units:
- N:1 mux per FP unit
- Handles variable data widths (64/96/65 bits)
- Passes through TID for result routing

#### fp_*_wrapper.vhd
Wrappers around Xilinx FP IP cores:
- Consistent AXI-Stream-like interface
- TID delay pipeline matches FP latency
- NonBlocking mode for maximum throughput

#### crossbar_output_router.vhd
Routes FP results back to producers based on TID:
- Decodes producer ID from TID[15:13]
- Priority encoder handles collisions
- Per-producer output FIFOs (depth 8)

#### simple_fifo.vhd
Synchronous FIFO for output buffering:
- Configurable width and depth
- Handles simultaneous read/write
- Empty/full status flags

## Data Flow

### Request Phase (Cycle N)
1. Producer asserts request with unit type, unit index, data, and TID
2. Arbiter evaluates all requests in parallel
3. Arbiter grants one producer per available FP unit
4. Grant signals and mux selects generated

### Execute Phase (Cycle N+1)
5. Input mux routes granted producer's data to FP unit
6. FP unit accepts data with TID
7. FP unit begins computation (2 cycles)

### Result Phase (Cycle N+3)
8. FP unit outputs result + TID
9. Output router decodes TID producer ID
10. Result routed to producer's output FIFO
11. Producer reads result when ready

## TID Format

Transaction IDs are 16 bits:
```
[15:13] Producer ID (3 bits, supports 8 producers)
[12:0]  Operation Index (13 bits, 8192 operations per producer)
```

Use `make_tid(producer_id, op_index)` to create TIDs.
Use `get_producer_id(tid)` to extract producer ID.

## Building the Project

### Prerequisites
- Vivado 2021.2 or later
- Target FPGA: Xilinx Artix-7 XC7A200T (Nexys Video)

### Build Steps

1. **Run syntax check and build**:
   ```bash
   ./run_build.sh
   ```
   This will:
   - Check VHDL syntax
   - Generate Xilinx FP IP cores (mult, fma, addsub)
   - Create clock wizard IP
   - Add all source files
   - Run synthesis

2. **Open in Vivado GUI** (optional):
   ```bash
   ./run_gui.sh
   ```

3. **Refresh files** (after editing source):
   ```bash
   ./run_refresh.sh
   ```

### Build Configuration

Edit `build.tcl` to change:
- `NUM_MULT_UNITS`: Number of multiplier units (default: 10)
- `NUM_FMA_UNITS`: Number of FMA units (default: 5)
- `NUM_ADD_UNITS`: Number of AddSub units (default: 3)
- `NUM_PRODUCERS`: Number of producer interfaces (default: 10)

**Note**: Must also update constants in `crossbar_pkg.vhd` to match.

## Testing

### Arbiter Testbench
Tests round-robin arbitration logic:
```bash
# Set top testbench in build.tcl:
# set_property top crossbar_arbiter_tb [get_filesets sim_1]
```

### System Testbench
Full system validation (TODO):
- Multiple producers issuing concurrent requests
- All FP unit types (MULT, FMA, ADDSUB)
- TID routing verification
- FIFO behavior under load

## Design Decisions

### Why Round-Robin Arbitration?
- Simple to implement
- Fair scheduling (no starvation)
- Low latency (single-cycle)
- Alternatives: priority-based, weighted round-robin

### Why Output FIFOs?
- Absorb result bursts when producer busy
- Decouple FP pipeline from producer ready
- Depth 8 sufficient for most workloads
- Minimal resource overhead

### Why NonBlocking FP Units?
- Higher throughput (no stalls)
- Simpler interface (no backpressure)
- Matches crossbar paradigm (always ready)
- Xilinx FP IP well-optimized for this mode

### Why TID Passthrough?
- Avoids separate TID tracking infrastructure
- Zero resource overhead
- Results self-identify their destination

## Advantages Over FIFO-Based Approach

- ✅ No signal contention (clean arbitration)
- ✅ True concurrent access (multiple producers simultaneously)
- ✅ Deterministic behavior (clear grant/deny)
- ✅ Better throughput (no FIFO bottlenecks)
- ✅ Fair scheduling (round-robin arbitration)
- ✅ Scalable (add more FP units without changing interface)

## Future Enhancements

1. **Priority-based arbitration**: Some producers more important than others
2. **Dynamic FP unit allocation**: Producers request any available unit of type
3. **Backpressure support**: Producers can signal "not ready"
4. **Performance counters**: Track utilization, contention, latency
5. **Clock domain crossing**: Producers in different clock domain
6. **AXI4-Stream interfaces**: Standard interface for IP integration

## File Structure

```
crossbar/
├── build.tcl              # Vivado build script
├── build/                 # Build output (gitignored)
├── README.md              # This file
├── CROSSBAR_DESIGN.md     # Detailed design document
└── src/
    ├── hdl/               # VHDL source files
    │   ├── crossbar_pkg.vhd
    │   ├── crossbar_arbiter.vhd
    │   ├── crossbar_input_mux.vhd
    │   ├── crossbar_output_router.vhd
    │   ├── crossbar_fp_system.vhd
    │   ├── fp_mult_wrapper.vhd
    │   ├── fp_fma_wrapper.vhd
    │   ├── fp_addsub_wrapper.vhd
    │   ├── simple_fifo.vhd
    │   └── lin_alg_pkg.vhd
    ├── sim/               # Testbenches
    └── constraints/       # Constraint files
        └── Nexys-Video-Master.xdc
```

## References

- Design document: `CROSSBAR_DESIGN.md`
- Xilinx Floating Point IP: PG060
- AXI4-Stream Protocol: PG085
