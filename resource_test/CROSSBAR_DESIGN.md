# Crossbar-Based FP Resource Sharing Architecture

## System Overview

A crossbar switch interconnect allows N producers (spheres) to dynamically access M floating-point units with full parallel capability and proper arbitration.

## Block Diagram

```
┌─────────────┐  req[0]   ┌──────────────┐   ┌──────────────┐
│  Producer 0 │──────────▶│              │   │   MULT Unit  │
│  (Sphere)   │◀──────────│              │──▶│      0       │
└─────────────┘  grant[0] │              │   │  (FP32 Mult) │
                           │              │   └──────────────┘
┌─────────────┐  req[1]   │              │   ┌──────────────┐
│  Producer 1 │──────────▶│   Crossbar   │──▶│   MULT Unit  │
│  (Sphere)   │◀──────────│   Arbiter &  │   │      1       │
└─────────────┘  grant[1] │   Switch     │   └──────────────┘
                           │              │          ...
       ...                 │  (Input Mux, │   ┌──────────────┐
                           │   Output     │──▶│   MULT Unit  │
┌─────────────┐  req[N-1] │   Routing,   │   │      M-1     │
│ Producer N-1│──────────▶│   Result     │   └──────────────┘
│  (Sphere)   │◀──────────│   Collect)   │          │
└─────────────┘  grant    │              │          │ results
                           │              │◀─────────┘
                           └──────────────┘
                                  │
                                  ▼
                           Result routing
                           based on TID
```

## Module Hierarchy

### Top Level: `crossbar_fp_system`
Integrates all components and provides external interface.

**Ports:**
- Clock, reset, clock locked
- Producer interfaces (N producers)
  - Request signals (valid, ready handshake)
  - Operation data (operands + TID)
  - Result outputs (data + TID + valid)

**Submodules:**
- `crossbar_arbiter` - Request arbitration logic
- `crossbar_input_mux` - Data path multiplexing to FP units
- `fp_mult_wrapper` (×M) - FP multiplier units
- `fp_fma_wrapper` (×K) - FP FMA units  
- `fp_addsub_wrapper` (×L) - FP add/sub units
- `crossbar_output_router` - Route results back to producers
- `clk_wiz_0` - Clock management

### Module 1: `crossbar_arbiter`
Decides which producer gets access to which FP unit each cycle.

**Inputs:**
- `req_mult[N-1:0][M-1:0]` - Producer i requests MULT unit j
- `req_fma[N-1:0][K-1:0]` - Producer i requests FMA unit j
- `req_addsub[N-1:0][L-1:0]` - Producer i requests AddSub unit j
- `fp_ready[total_units-1:0]` - Which FP units are available

**Outputs:**
- `grant_mult[N-1:0]` - Which MULT unit (if any) granted to producer i
- `grant_fma[N-1:0]` - Which FMA unit (if any) granted to producer i
- `grant_addsub[N-1:0]` - Which AddSub unit (if any) granted to producer i
- `mux_sel[total_units-1:0]` - Input mux select signals

**Algorithm:** Round-robin arbiter per FP unit
- Each FP unit maintains priority pointer
- Scans requests starting from priority pointer
- Grants to first requesting producer
- Updates priority pointer to next producer
- Single-cycle arbitration latency

**Registers:**
- Priority pointers (one per FP unit)
- Grant holding registers

### Module 2: `crossbar_input_mux`
Multiplexes producer data to FP unit inputs based on arbiter grants.

**Inputs:**
- `prod_data[N-1:0]` - Operand data from all producers
- `prod_tid[N-1:0]` - Transaction IDs from all producers
- `mux_sel[M-1:0]` - Select signals from arbiter

**Outputs:**
- `fp_mult_data[M-1:0]` - Data to each MULT unit
- `fp_mult_tid[M-1:0]` - TID to each MULT unit
- `fp_mult_valid[M-1:0]` - Valid signals to MULT units
- Similar for FMA and AddSub

**Implementation:**
- N:1 multiplexer per FP unit
- Data width: 64 bits (MULT), 96 bits (FMA), 65 bits (AddSub)
- TID width: 16 bits
- Combinational logic (muxes)

### Module 3: `fp_mult_wrapper`
Wrappers around Xilinx FP multiplier IP with consistent interface.

**Ports:**
- `aclk` - Clock
- `s_axis_valid` - Input valid
- `s_axis_data` - Operands (64 bits: two 32-bit FP32 values)
- `s_axis_tid` - Transaction ID (16 bits)
- `m_axis_valid` - Output valid
- `m_axis_data` - Result (32 bits FP32)
- `m_axis_tid` - Transaction ID passthrough

**Configuration:**
- NonBlocking mode
- 2-cycle latency
- No backpressure (always ready)

**Contains:**
- Xilinx `floating_point_mult` IP
- TID delay pipeline (2 stages to match latency)

### Module 4: `fp_fma_wrapper`
Wrapper around Xilinx FP FMA (fused multiply-add) IP.

**Ports:**
- Same structure as `fp_mult_wrapper`
- Input data: 96 bits (three 32-bit FP32: a, b, c for a×b+c)
- Operation: FMA (fixed)

**Configuration:**
- NonBlocking mode
- 2-cycle latency
- TID passthrough pipeline

### Module 5: `fp_addsub_wrapper`
Wrapper around Xilinx FP Add/Subtract IP.

**Ports:**
- Same structure as above
- Input data: 65 bits (two 32-bit FP32 + 1 bit operation selector)
- Operation bit: 0=add, 1=subtract

**Configuration:**
- NonBlocking mode
- 2-cycle latency
- TID passthrough pipeline

### Module 6: `crossbar_output_router`
Routes FP results back to correct producer based on TID.

**Inputs:**
- `fp_result_valid[total_units-1:0]` - Valid from all FP units
- `fp_result_data[total_units-1:0]` - Result data from all FP units
- `fp_result_tid[total_units-1:0]` - TIDs from all FP units

**Outputs:**
- `prod_result_valid[N-1:0]` - Valid to each producer
- `prod_result_data[N-1:0]` - Result data to each producer
- `prod_result_tid[N-1:0]` - TID to each producer

**Logic:**
- Decode producer ID from TID[15:13]
- Route result to producer's output FIFO
- Handle multiple results for same producer (small output FIFO per producer)
- Priority encoder if multiple FP units output to same producer same cycle

**Components:**
- TID decoder (combinational)
- M:N routing matrix (M FP results → N producer outputs)
- Small output FIFOs (depth 4-8) per producer to absorb bursts

## Data Flow

**Request Phase (Cycle N):**
1. Producer asserts request with unit preference and data
2. Arbiter evaluates all requests
3. Arbiter grants one producer per available FP unit
4. Grant signals and mux selects generated

**Execute Phase (Cycle N+1):**
5. Input mux routes granted producer's data to FP unit
6. FP unit accepts data with TID
7. FP unit begins computation

**Result Phase (Cycle N+1+latency):**
8. FP unit outputs result + TID after 2 cycles
9. Output router decodes TID producer ID
10. Result routed to producer's output FIFO
11. Producer reads result from FIFO

## Interface Specifications

### Producer Request Interface
```vhdl
type producer_request_t is record
    valid       : std_logic;
    unit_type   : unit_type_t;  -- MULT, FMA, or ADDSUB
    unit_index  : integer;      -- Which unit of that type (0 to M-1)
    data        : std_logic_vector(95 downto 0);  -- Max size (FMA)
    tid         : std_logic_vector(15 downto 0);
end record;

type producer_grant_t is record
    granted     : std_logic;
    unit_type   : unit_type_t;
    unit_index  : integer;
end record;

type producer_result_t is record
    valid       : std_logic;
    data        : std_logic_vector(31 downto 0);
    tid         : std_logic_vector(15 downto 0);
    ready       : std_logic;  -- Backpressure from producer
end record;
```

### Internal Crossbar Signals
```vhdl
-- Request matrix: request(producer)(fp_unit)
type request_matrix_t is array (0 to NUM_PRODUCERS-1, 0 to TOTAL_FP_UNITS-1) of std_logic;

-- Grant vector: which producer (if any) granted to each FP unit
type grant_vector_t is array (0 to TOTAL_FP_UNITS-1) of integer range -1 to NUM_PRODUCERS-1;
  -- -1 = no grant (unit idle)
  -- 0 to N-1 = producer index
```

## Timing and Performance

**Arbitration Latency:** 1 cycle
- Combinational arbitration with registered outputs
- Can be pipelined if timing is tight

**FP Unit Latency:** 2 cycles (NonBlocking mode)
- Cycle 0: Accept input
- Cycle 1: Compute
- Cycle 2: Output result

**Total Request-to-Result:** 3 cycles minimum
- Cycle 0: Request + arbitration
- Cycle 1: FP input
- Cycle 2: FP compute  
- Cycle 3: Result available

**Throughput:** One operation per FP unit per cycle (when granted)
- 10 MULT units = 10 operations/cycle = 1 GFLOP @ 100MHz
- 5 FMA units = 10 operations/cycle = 1 GFLOP @ 100MHz (FMA counts as 2 ops)
- 3 AddSub units = 3 operations/cycle = 300 MFLOP @ 100MHz
- **Total: ~2.3 GFLOPS @ 100MHz**

## Configuration Parameters

```vhdl
constant NUM_PRODUCERS : integer := 10;
constant NUM_MULT_UNITS : integer := 10;
constant NUM_FMA_UNITS : integer := 5;
constant NUM_ADDSUB_UNITS : integer := 3;
constant TOTAL_FP_UNITS : integer := 18;
constant TID_WIDTH : integer := 16;
constant PRODUCER_ID_BITS : integer := 3;  -- bits 15:13 of TID
constant OP_INDEX_BITS : integer := 13;    -- bits 12:0 of TID
constant OUTPUT_FIFO_DEPTH : integer := 8;
```

## Resource Estimates (10 Producers × 10 MULT)

**LUTs:** ~20,000 (15% of XC7A200T)  
**FFs:** ~600 (<1%)  
**DSPs:** ~30 (4%)  
**BRAM:** 0 (unless large output FIFOs needed)

## Advantages Over FIFO Approach

- ✅ No signal contention (clean arbitration)
- ✅ True concurrent access (multiple producers simultaneously)
- ✅ Deterministic behavior (clear grant/deny)
- ✅ Better throughput (no FIFO bottlenecks)
- ✅ Fair scheduling (round-robin arbitration)

## Design Decisions

**Why round-robin arbitration?**
- Simple to implement
- Fair (no producer starvation)
- Low latency (single-cycle decision)
- Alternative: priority-based (if some spheres more important)

**Why small output FIFOs?**
- Absorb result bursts when producer busy
- Decouple FP pipeline from producer ready
- Depth 8 is enough for typical workloads

**Why NonBlocking FP units?**
- Higher throughput (no stalls)
- Simpler interface (no backpressure to FP units)
- Matches crossbar paradigm (always ready to accept)

**Why TID passthrough in FP units?**
- Avoids separate TID tracking infrastructure
- Xilinx FP IP supports TUSER for exactly this purpose
- Zero resource overhead

## Implementation Phases

### Phase 1: Core Infrastructure (Start Here)
1. Define package with types and constants
2. Implement `crossbar_arbiter` (simplest - just round-robin logic)
3. Create basic testbench for arbiter

### Phase 2: Data Path
4. Implement `crossbar_input_mux` (combinational muxes)
5. Implement `fp_mult_wrapper` (reuse existing FP IP)
6. Create testbench for mux + FP unit

### Phase 3: Result Routing
7. Implement `crossbar_output_router` with TID decoding
8. Add output FIFOs
9. Create end-to-end testbench

### Phase 4: Integration
10. Create `crossbar_fp_system` top level
11. Add FMA and AddSub wrappers (copy MULT pattern)
12. Full system testbench

### Phase 5: Validation
13. Port `pipeline_sphere_tb` to use crossbar interface
14. Verify all 6 operations complete
15. Add concurrent producer test
16. Measure throughput and resource usage

## Next Steps

Ready to start implementation with Phase 1: the arbiter module and package definitions.
