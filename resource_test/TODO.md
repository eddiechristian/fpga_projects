# TODO - Resource Test Project

## Completed Features

### ✅ Transaction ID (TID) Tracking
**Status:** Completed  
**Description:** Implemented end-to-end transaction tracking with 16-bit TID flowing through entire pipeline.

**Implementation:**
- Added `input_tid[15:0]` and `output_tid[15:0]` ports
- Created `tid_pipeline.vhd` with 8-cycle shift register per multiplier
- Updated `result_collector.vhd` to handle TID alongside data
- TID flows through: input → tdest_generator → input_fifo → interconnect → tid_pipeline → result_collector → output_fifo → output
- 16-bit TID width supports 65,536 unique transactions

### ✅ Configurable Number of Multipliers
**Status:** Completed  
**Description:** Made NUM_MULTIPLIERS fully parameterizable using VHDL-2008.

**Implementation:**
- Refactored to VHDL-2008 for unconstrained arrays
- Created custom `axis_interconnect_wrapper.vhd` (replaced Xilinx IP)
- Dynamic signal sizing based on NUM_MULTIPLIERS generic
- Successfully tested with 20 multipliers
- TDEST_WIDTH automatically calculated: ceil(log2(NUM_MULTIPLIERS))

### ✅ Pipeline Optimization
**Status:** Completed  
**Description:** Added pipeline stage to interconnect wrapper for timing closure.

**Implementation:**
- Added registered pipeline stage in `axis_interconnect_wrapper.vhd`
- Breaks critical path through TDEST routing logic
- Adds 1 cycle latency (9 total: 8 multiplier + 1 interconnect)
- Achieved timing closure at 200 MHz with WNS=0.264 ns
- Throughput: 20 multipliers × 200 MHz = 4,000 MOPS

## Active Development

### Multi-Producer Output Routing (Option 1: Per-Object Producers)
**Priority:** High  
**Status:** In Progress  
**Target Application:** Hardware ray tracer (640×480, 4-5 objects, 174 fps target)

**Architecture:**
```
Object 0 logic ──> Producer 0 input ──┐
Object 1 logic ──> Producer 1 input ──┤
Object 2 logic ──> Producer 2 input ──├──> 20 Multipliers
Object 3 logic ──> Producer 3 input ──┤
Object 4 logic ──> Producer 4 input ──┘
         ↓                ↓                ↓                ↓                ↓
     FIFO 0          FIFO 1          FIFO 2          FIFO 3          FIFO 4
         ↓                ↓                ↓                ↓                ↓
  Object 0 logic  Object 1 logic  Object 2 logic  Object 3 logic  Object 4 logic
```

**TID Structure (16 bits):**
- Bits [15:13]: Producer/Object ID (0-4) → 5 producers
- Bits [12:0]: Per-producer transaction ID (8,192 unique IDs per producer)

**Implementation Plan:**
1. Create `output_demux.vhd` - Routes results based on upper TID bits
   - 1-to-N demultiplexer
   - Extracts producer ID from TID[15:13]
   - Pipelined for timing (similar to interconnect wrapper)
2. Update `top_module.vhd` - Multi-producer interface
   - Add `NUM_PRODUCERS` generic (default 5)
   - Replace single output with arrays:
     - `output_tdata: array of std_logic_vector(31 downto 0)`
     - `output_tid: array of std_logic_vector(15 downto 0)`
     - `output_tvalid: std_logic_vector(NUM_PRODUCERS-1 downto 0)`
     - `output_tready: std_logic_vector(NUM_PRODUCERS-1 downto 0)`
   - Connect: result_collector → output_demux → per-producer FIFOs → outputs
3. Update `build.tcl` - Generate multiple output FIFOs
   - Create NUM_PRODUCERS output FIFO IP instances
   - Each: 32-bit TDATA, 16-bit TID, 1024 depth
   - Total BRAM cost: ~15 BRAMs (3 per FIFO × 5 producers)
4. Update `multiply_fifo_tb.vhd` - Test multi-producer outputs
   - Verify routing based on TID upper bits
   - Test all producers simultaneously

**Benefits for Hardware Ray Tracing:**
- Parallel object processing - Each object's intersection logic independent
- No arbitration overhead - Results naturally separated
- Backpressure isolation - One stalled object doesn't block others
- Simple integration - Each object module has dedicated input/output pair
- Resource efficient - Only 15 BRAMs for 5 producers (<5% of XC7A200T)

**Alternative Considered:**
Single shared output FIFO with software demux - rejected because entire design is in hardware

---

### Multi-Operation FP32 Pipeline with OpCode Routing
**Priority:** High  
**Status:** Not Started  
**Target Application:** Ray tracing requires diverse FP32 operations beyond multiply

**Current Limitation:**
Design only supports FP32 multiply. Ray tracing needs:
- Fused Multiply-Add (FMA): a×b + c
- accumulator
- Add: a + b
- Subtract: a - b
- Compare operations (for intersection tests)

**Proposed Architecture:**
```
Shared Input FIFO
       ↓
   [OpCode Demux] ← opcode field in input
       ├────────┬────────┬────────┐
       ↓        ↓        ↓        ↓
   FMA Units  Add Units  Sub Units  Mult Units
   (N cores)  (M cores)  (K cores)  (20 cores)
       ├────────┴────────┴────────┘
       ↓
  Result Collector
       ↓
  Output Demux (by producer ID)
```

**Implementation Plan:**
1. **Expand input data width** to include opcode:
   - Current: 64 bits (32-bit operand_a + 32-bit operand_b)
   - New: 128 bits (3× 32-bit operands for FMA + 32-bit opcode/metadata)
   - Or: Keep 64-bit data, encode opcode in unused TID bits or TUSER

2. **Add OpCode Demux** (after input FIFO, before multipliers):
   - Extracts opcode from input
   - Routes to appropriate operation type
   - Similar to interconnect wrapper but routes by opcode instead of TDEST

3. **Generate multiple Xilinx FP32 IP cores**:
   - Floating Point FMA (CONFIG.Operation_Type {FMA})
   - Floating Point Adder (CONFIG.Operation_Type {Add})
   - Floating Point Subtractor (CONFIG.Operation_Type {Subtract})
   - Keep existing Multiplier cores
   - Each with 8-cycle latency for timing consistency

4. **Update Result Collector**:
   - Accept inputs from all operation types
   - Preserve TID through all paths
   - Round-robin arbitration across all units

**OpCode Encoding (4 bits suggested):**
- 0x0: Multiply (a × b)
- 0x1: Add (a + b)
- 0x2: Subtract (a - b)
- 0x3: FMA (a×b + c)
- 0x4-0xF: Reserved for compare, divide, sqrt, etc.

**Resource Implications:**
- FMA: ~4 DSP48E1 per unit (vs 2 for multiply)
- Add/Sub: ~0 DSP48E1 (uses LUTs)
- Can mix operation types based on workload
- Example: 10 FMA + 5 Add + 5 Mult = ~50 DSPs

**Benefits:**
- Reuse existing FIFO infrastructure
- Single unified pipeline for all operations
- Producer interface unchanged (just add opcode field)
- Flexible resource allocation per operation type

---

### Hardware Vector Operations (Vec3/Vec4 Dot Product)
**Priority:** Medium  
**Status:** Not Started  
**Depends On:** Multi-Operation FP32 Pipeline

**Ray Tracing Use Cases:**
- Dot products: Ray direction · surface normal (vec3)
- Dot products: Homogeneous coords (vec4)
- Cross products: Surface normal calculations
- Vector transforms: Matrix × vector operations

**Proposed Implementation:**

**Selected: Option A - Dedicated Dot Product Units**
- Dedicated hardware dot product using FMA tree
- Vec3: (a.x×b.x) + (a.y×b.y) + (a.z×b.z)
- Vec4: (a.x×b.x) + (a.y×b.y) + (a.z×b.z) + (a.w×b.w)
- Uses record types from `lin_alg_pkg.vhd` (Vec3, Vec4, fp32)
- Xilinx FP IP configured for pipelined accumulation
- Resource: ~8-12 DSPs per vec3 dot unit, ~16 DSPs per vec4 dot unit

**Input Data Format:**
- **Reuses existing 64-bit data path** - No bus widening required
- **4-cycle burst for both Vec3 and Vec4 dot products**
- Burst sequence encoding:

**Vec3 Dot (4 cycles, last 64 bits unused):**
```
Cycle 0: [a.y (32 bits) | a.x (32 bits)]
Cycle 1: [b.x (32 bits) | a.z (32 bits)]
Cycle 2: [b.z (32 bits) | b.y (32 bits)]
Cycle 3: [unused (32 bits) | unused (32 bits)]  // Padding to match Vec4 timing
```

**Vec4 Dot (4 cycles, fully utilized):**
```
Cycle 0: [a.y (32 bits) | a.x (32 bits)]
Cycle 1: [a.w (32 bits) | a.z (32 bits)]
Cycle 2: [b.y (32 bits) | b.x (32 bits)]
Cycle 3: [b.w (32 bits) | b.z (32 bits)]
```

**Implementation Notes:**
- Input sequencer accumulates 4 cycles before submitting to dot product unit
- Units internally reconstruct Vec3/Vec4 records from flattened input
- Same 4-cycle latency for both Vec3 and Vec4 simplifies control logic
- Total operation latency: 4 input cycles + 8-10 compute cycles = 12-14 cycles
- Throughput: Can start new dot product every 4 cycles (50 MHz effective rate at 200 MHz clock)

**Producer-Side Adapter Component:**
To simplify producer logic, a vector flattening adapter converts native Vec3/Vec4 records to 4-cycle 64-bit bursts:

```vhdl
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use work.lin_alg_pkg.all;

-- Vector Flattening Adapter: Converts Vec3/Vec4 to 64-bit burst
entity vector_flatten_adapter is
    generic (
        VECTOR_TYPE : string := "VEC3"  -- "VEC3" or "VEC4"
    );
    port (
        clk         : in  std_logic;
        reset       : in  std_logic;
        
        -- Producer-side interface (native Vec3/Vec4)
        vec_a       : in  Vec3;  -- or Vec4 based on VECTOR_TYPE
        vec_b       : in  Vec3;  -- or Vec4 based on VECTOR_TYPE
        vec_valid   : in  std_logic;
        vec_ready   : out std_logic;
        
        -- Pipeline-side interface (64-bit burst, 4 cycles)
        m_tdata     : out std_logic_vector(63 downto 0);
        m_tvalid    : out std_logic;
        m_tready    : in  std_logic;
        m_tlast     : out std_logic  -- Assert on cycle 3
    );
end vector_flatten_adapter;
```

**Adapter Functionality:**
- Accepts Vec3 or Vec4 record pairs from producer in **1 cycle**
- Internally generates 4-cycle burst on 64-bit output bus
- Handles backpressure (producer waits if pipeline busy)
- Provides clean abstraction: producers don't need to know about burst protocol

**Usage Example (Producer Side):**
```vhdl
-- Producer just provides Vec3 records
signal ray_dir, surface_normal : Vec3;
signal dot_valid : std_logic;

adapter : vector_flatten_adapter
    generic map (VECTOR_TYPE => "VEC3")
    port map (
        clk       => clk,
        reset     => reset,
        vec_a     => ray_dir,
        vec_b     => surface_normal,
        vec_valid => dot_valid,
        vec_ready => open,  -- Can monitor for backpressure
        m_tdata   => dot_input_bus,
        m_tvalid  => dot_input_valid,
        m_tready  => dot_input_ready,
        m_tlast   => dot_input_last
    );
```

**Dot Product Core Interface (Internal to Pipeline):**
```vhdl
-- Core receives flattened 64-bit bursts from adapter
entity vec3_dot_product_core is
    port (
        clk         : in  std_logic;
        reset       : in  std_logic;
        -- 64-bit burst input (4 cycles)
        s_tdata     : in  std_logic_vector(63 downto 0);
        s_tvalid    : in  std_logic;
        s_tready    : out std_logic;
        s_tlast     : in  std_logic;  -- Assert on cycle 3
        -- Result output
        m_tdata     : out fp32;          -- Dot product result
        m_tvalid    : out std_logic;
        m_tready    : in  std_logic
    );
end vec3_dot_product_core;
```

**Alternative: Option B - Use FMA Pipeline (Not Selected)**
- Issue 3 FMA operations for vec3 dot:
  1. FMA(a₀, b₀, 0) → t₀
  2. FMA(a₁, b₁, t₀) → t₁  
  3. FMA(a₂, b₂, t₁) → result
- Requires dependency tracking (wait for previous result)
- Reuses existing FMA units (no extra DSPs)
- Higher latency: 3× FMA latency (~24 cycles) vs dedicated (~8-10 cycles)

**Option C: SIMD-style Parallel FMA**
- Allocate 3 or 4 FMA units to one producer
- Execute all multiplies in parallel: a₀×b₀, a₁×b₁, a₂×b₂
- Final tree reduction with adds
- Balance between latency and resource usage

**Recommendation:**
- Start with **Option B** (sequential FMA) - reuses hardware
- Profile ray tracer to measure dot product bottleneck
- If dot products dominate, upgrade to **Option A** (dedicated units)

**OpCode Extensions:**
- 0x8: Vec3 Dot Product (3× 32-bit vectors in, 32-bit scalar out)
- 0x9: Vec4 Dot Product (4× 32-bit vectors in, 32-bit scalar out)
- 0xA: Vec3 Cross Product (3× 32-bit vectors in, 3× 32-bit vector out)

**Input Data Format for Vec3 Dot:**
- Uses `Vec3` record type from `lin_alg_pkg.vhd` (3× fp32 = 96 bits per vector)
- Requires 2 Vec3 values (192 bits total): vector a, vector b
- Options for input interface:
  - **Option 1:** Widen input bus to 192 bits (2× Vec3 in one cycle)
  - **Option 2:** Burst 2 cycles at 96 bits (1 Vec3 per cycle)
  - **Option 3:** Flatten Vec3 records to `std_logic_vector(95 downto 0)` for AXI compatibility

**Input Data Format for Vec4 Dot:**
- Uses `Vec4` record type from `lin_alg_pkg.vhd` (4× fp32 = 128 bits per vector)
- Requires 2 Vec4 values (256 bits total): vector a, vector b
- Options for input interface:
  - **Option 1:** Widen input bus to 256 bits (2× Vec4 in one cycle)
  - **Option 2:** Burst 2 cycles at 128 bits (1 Vec4 per cycle)
  - **Option 3:** Burst 4 cycles at 64 bits (matches existing FIFO width)
  - **Option 4:** Flatten Vec4 records to `std_logic_vector(127 downto 0)` for AXI compatibility

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
