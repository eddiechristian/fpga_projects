# TODO - Resource Test Project

## Future Enhancements

### Transaction ID (TID) Tracking
**Priority:** Medium  
**Status:** Not Started  
**Description:** Implement end-to-end transaction tracking to match multiply operations with their results.

**Problem:**
Currently, operations are sent through a parallel pipeline with 10 multipliers using round-robin distribution. Results come back out-of-order, making it impossible to match which result corresponds to which input operation. This is problematic when multiple producers are sending operations.

**Proposed Solution:**
Add a 16-bit Transaction ID (TID) that flows through the entire pipeline alongside the data:

1. **Input Stage:** Add `input_tid[15:0]` port to top_module
2. **TID Pipeline per Multiplier:** Create tid_pipeline.vhd module with 8-cycle shift register (matching FP multiplier latency)
3. **Result Collector:** Update result_collector.vhd to handle TID alongside data
4. **Output Stage:** Add `output_tid[15:0]` port to top_module
5. **Testbench:** Update multiply_fifo_tb.vhd to generate sequential TIDs and verify matching

**Implementation Details:**
- TID width: 16 bits (65536 unique transactions)
- TID must flow through: input → tdest_generator → input_fifo → interconnect → multipliers → tid_pipeline → result_collector → output_fifo → output
- Challenge: Current design uses TUSER[3:0] for TDEST routing. TID needs parallel path (either expand TUSER width or add dedicated TID signals)
- Each of the 10 multipliers needs its own tid_pipeline instance

**Benefits:**
- Enable multiple concurrent producers
- Verify correctness by matching input/output operations
- Support future DMA or AXI master interfaces
- Enable proper operation ordering in testbench

**Alternative:** Use testbench-only scoreboard for testing (quick fix, but doesn't help with multiple producers in real use)

---

### Performance Monitoring
**Priority:** Low  
**Status:** Not Started  
**Description:** Add performance counters to track pipeline utilization and throughput.

**Metrics to Track:**
- Operations per second through each multiplier
- FIFO depth utilization (current fill level)
- Backpressure events (input stalled, output stalled)
- Multiplier idle time

**Implementation:**
- Add counter registers in top_module
- Create AXI-Lite slave interface for register access
- Add monitoring logic to key pipeline stages

---

### Error Detection
**Priority:** Low  
**Status:** Not Started  
**Description:** Add error detection for invalid FP32 operations.

**Features:**
- Detect NaN, Inf, denormal inputs
- Flag overflow/underflow conditions
- Optional error status output per operation

---

### Configurable Number of Multipliers
**Priority:** Low  
**Status:** Not Started  
**Description:** Make NUM_MULTIPLIERS fully parameterizable.

**Current State:**
NUM_MULTIPLIERS generic exists but some components (axis_interconnect_0) are hardcoded for 10 outputs.

**Required Changes:**
- Use TCL loops in build.tcl to generate interconnect with variable master count
- Update generate statements in top_module
- Test with different multiplier counts (4, 8, 16, etc.)

---

### AXI4 DMA Interface
**Priority:** Low  
**Status:** Not Started  
**Description:** Add AXI4 memory-mapped interface for high-throughput operation.

**Features:**
- Replace simple AXIS input with AXI4 DMA slave
- Burst reads from memory
- Burst writes of results back to memory
- Descriptor-based operation queuing

**Benefits:**
- Much higher throughput from PS/CPU
- Reduce CPU overhead
- Enable batch processing
