# FP Resource Sharing Test - FIFO-Based Approach

## Project Overview

This project explores resource sharing for floating-point operations in FPGA ray tracing. The goal is to allow multiple "spheres" (producers) to share a pool of FP32 units (multipliers, FMA, add/sub) instead of each having dedicated units.

**Hardware saved:** Without sharing, each sphere needs ~40-45 FP operations (90-135 DSPs). On a Nexys Video (740 DSPs), this limits us to 5-8 spheres. With sharing, dozens of spheres can share the same FP pool.

## Architecture: FIFO-Based Approach

### Design
- **Input FIFOs**: One FIFO per FP unit type, accepts operations from any producer
- **FP Units**: Xilinx NonBlocking FP32 units (MULT, FMA, AddSub) configured for 2-cycle latency
- **Transaction IDs (TIDs)**: 16-bit IDs encode producer (bits 15:13) + operation index (bits 12:0)
- **Output FIFOs**: One per producer, routes results back based on TID
- **Valid Gating**: Shift registers filter out garbage from NonBlocking FP units during startup

### Key Files
- `src/hdl/pipeline_hw.vhd` - Main hardware with FIFOs, FP units, routing logic
- `src/hdl/sync_fifo.vhd` - Custom synchronous FIFO with TID support
- `src/sim/pipeline_sphere_tb.vhd` - Simple testbench, 3 spheres sequential access ✅ WORKS
- `src/sim/pipeline_concurrent_tb.vhd` - Aggressive testbench, 3 producers concurrent ❌ FAILS
- `src/sim/pipeline_sphere_debug.wcfg` - Waveform config for debugging

## Current Status

### ✅ What Works
- **Sequential access pattern** - `pipeline_sphere_tb` completes all 6 operations (3 MULT + 3 FMA)
- **TID routing** - Correctly routes results back to correct producer (TIDs: 0, 1, 8192, 8193, 16384, 16385)
- **FP computation** - Units compute correctly (e.g., 2.0×3.0=6.0, 1.0×4.0+5.0=9.0)
- **Valid gating** - Filters out garbage with 2-cycle shift register matching FP latency
- **FIFO functionality** - Single-write pattern works correctly

### ❌ What Doesn't Work
- **Concurrent access** - Multiple producers writing to same FP unit simultaneously causes corruption
- **No arbitration** - When Producer A and C both try to write MULT unit 0, double-writes occur
- **Garbage results** - Concurrent testbench gets `5.877472e-39` (all zeros) for most results
- **Producer B/C starvation** - In concurrent test, only Producer A got 4/20 results, B/C got 0/20

## Issues Discovered & Fixed

### 1. Testbench Double-Write Bug
**Problem:** VHDL signal assignments with `wait until rising_edge` caused valid to stay high for 2 clock cycles, resulting in double FIFO writes.

**Solution:** Added `wait for 1ns` delta delay after clock edge before setting signals, or use proper clock-aligned patterns.

### 2. Wrong FMA Latency
**Problem:** Valid gating shift register assumed 9-cycle latency (typical for pipelined FMA), but NonBlocking mode has only 2-cycle latency.

**Solution:** Changed from 9-bit to 2-bit shift register, checking `valid_shift(1)` instead of `valid_shift(8)`.

### 3. FIFO Timing Issues (False Alarm)
**Problem:** Suspected FIFO read-during-write hazards, spent hours debugging with various delays.

**Solution:** FIFO was actually fine - issue was double-writes from testbench, not FIFO corruption.

## Why This Approach Was Abandoned

### Fundamental Limitation: No Write Arbitration
The FIFO-based design has **no mechanism to arbitrate when multiple producers try to write to the same FP unit simultaneously**. This causes:

1. **Signal Contention** - Multiple processes assigning to same `mult_wr_data(63:0)` at same time
2. **Unpredictable Behavior** - VHDL resolution functions choose "winning" value unpredictably  
3. **Data Corruption** - Wrong TIDs, wrong operands, or garbage values
4. **No Backpressure Coordination** - Each producer checks `wr_ready` independently, doesn't see other producers

### What Would Be Needed
To make this work, you'd need:
- **Arbiter per FP unit** - Grant write access to one producer at a time
- **Request/Grant protocol** - Producers request access, wait for grant
- **Round-robin or priority** - Fair scheduling algorithm
- **Or: Dedicated FP unit assignment** - Each producer uses different units (defeats sharing purpose)

### Performance Concerns
- **Arbitration overhead** - Additional cycles to grant/switch between producers
- **Serialization** - Concurrent requests become sequential, limiting throughput
- **Complexity** - Adds significant control logic and state machines

## Alternative Approaches to Consider

### 1. Crossbar Switch
- Full connectivity matrix between producers and FP units
- Each producer has dedicated request/grant per unit
- Higher routing resources but true parallel access

### 2. Shared Bus with Arbitration
- Time-division multiplexing of FP units
- Single arbiter grants bus access per cycle
- Simpler control but potential bottleneck

### 3. Hybrid: Pools + Routing
- Divide FP units into pools (e.g., 2 MULTs per pool)
- Route each sphere to specific pool at compile time
- Share within pools, isolate between pools

### 4. AXI Stream Infrastructure
- Use Xilinx AXI Stream interconnect with built-in arbitration
- Leverage proven IP for routing/arbitration
- Easier integration but less control

## Lessons Learned

1. **NonBlocking FP units need valid gating** - They output continuously, need shift register to track when valid data emerges
2. **FIFO latency matters** - Read-first pattern has specific timing, need 2-cycle delay for writes to propagate  
3. **Testbench timing is critical** - Delta cycles and signal assignment order cause subtle bugs
4. **VHDL signal contention is hard to debug** - Multiple writers = undefined behavior, shows as garbage values
5. **Resource sharing needs explicit arbitration** - Can't rely on FIFOs alone for multi-producer access

## Current Hardware Configuration

- **FPGA:** Nexys Video (Artix-7 XC7A200T, 740 DSPs)
- **FP Units:** 8 MULT, 5 FMA, 3 AddSub (all NonBlocking, 2-cycle latency)
- **Clock:** 100 MHz input → clock wizard
- **FIFO Depth:** 32 entries per FIFO
- **Producers:** 5 supported (bits 15:13 of TID)
- **TID Width:** 16 bits (3 for producer, 13 for operation index)

## Next Steps

1. **Evaluate alternatives** - Decide on crossbar, arbiter, or hybrid approach
2. **Prototype arbitration** - Add simple round-robin arbiter for one FP unit type
3. **Measure performance** - Compare throughput vs. dedicated units
4. **Consider AXI** - Investigate if AXI Stream infrastructure simplifies design
5. **Real workload** - Test with actual sphere intersection calculations, not synthetic

## Repository Structure

```
resource_test/
├── src/
│   ├── hdl/
│   │   ├── pipeline_hw.vhd          # Main hardware (FIFO + FP + routing)
│   │   ├── sync_fifo.vhd            # Custom FIFO with TID
│   │   └── clk_wiz_0.vhd            # Clock wizard (generated)
│   ├── sim/
│   │   ├── pipeline_sphere_tb.vhd   # Simple testbench (WORKS)
│   │   ├── pipeline_concurrent_tb.vhd  # Concurrent testbench (FAILS)
│   │   ├── pipeline_sphere_debug.wcfg  # Waveform config
│   │   └── run_*.tcl                # Simulation scripts
│   └── constraints/
│       └── nexys_video.xdc          # Pin assignments
├── build/                           # Build outputs (gitignored)
└── README.md                        # This file
```

## References

- Xilinx Floating-Point Operator v7.1 (PG060)
- "Resource Sharing in High-Level Synthesis" - helps frame the problem
- Previous work: `fp_ip_test/` contains single-sphere FP unit tests

---

**Status:** Architecture validated for sequential access. Concurrent access requires arbitration redesign.  
**Date:** 2024-12-15  
**Next Project:** Crossbar or arbiter-based resource sharing
