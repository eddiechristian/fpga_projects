# Multi-Operation FP32 Pipeline with OpCode Routing

## Problem Statement
Current design only supports FP32 multiply operations. Ray tracing requires diverse FP32 operations:
- Fused Multiply-Add (FMA): a×b + c (also used for dot products)
- Add: a + b
- Subtract: a - b
- Compare operations (for intersection tests)

Need to add multiple operation types while reusing existing FIFO infrastructure and maintaining TID tracking through all paths.

## Current Architecture Overview
**Existing Pipeline:**
```
Input FIFO (64-bit: a|b, TDEST, TID)
    ↓
Interconnect (routes by TDEST)
    ↓
20× Multipliers (8-cycle latency, Blocking mode)
    ↓
Result Collector (round-robin from 20 multipliers)
    ↓
Output Demux (routes by TID[15:13])
    ↓
5× Output FIFOs (per-producer)
```

**Key Constraints:**
- Input: 64-bit data path (operand_a | operand_b)
- TID: 16 bits (upper 3 bits = producer ID)
- All FP32 IPs configured: 8-cycle latency, Blocking flow control, 200 MHz target
- FIFO depths: 64 entries (input + 5 outputs)

## Proposed Architecture
**New Multi-Operation Pipeline:**
```
Input FIFO (128-bit: d|c|b|a, OpCode in TUSER[7:4], TID)
    ↓
[OpCode Demux] ← routes by OpCode
    ├──────────┬──────────┬──────────┐
    ↓          ↓          ↓          ↓
N×Mult    M×FMA      K×Add     L×Sub
(8-cycle) (2-cycle)  (2-cycle) (2-cycle)
    ├──────────┴──────────┴──────────┘
    ↓
Unified Result Collector (round-robin from all units)
    ↓
Output Demux (by TID[15:13])
    ↓
5× Output FIFOs
```

## Implementation Plan

### Phase 1: Add Xilinx FP32 IP Cores
**File:** `build.tcl`

**1.1 Add FMA (Fused Multiply-Add) IP**
```tcl
create_ip -name floating_point -vendor xilinx.com -library ip -version 7.1 -module_name floating_point_fma -dir $ip_dir
set_property -dict [list \
    CONFIG.Operation_Type {Fused_Multiply_Add} \
    CONFIG.A_Precision_Type {Single} \
    CONFIG.B_Precision_Type {Single} \
    CONFIG.C_Precision_Type {Single} \
    CONFIG.Result_Precision_Type {Single} \
    CONFIG.C_Latency {8} \
    CONFIG.C_Mult_Usage {Full_Usage} \
    CONFIG.C_Rate {1} \
    CONFIG.Flow_Control {Blocking} \
    CONFIG.Maximum_Latency {false} \
    CONFIG.Has_RESULT_TREADY {true} \
] [get_ips floating_point_fma]
```
- Resource: ~4 DSP48E1 per unit (vs 2 for multiply)
- Ports: s_axis_a (32), s_axis_b (32), s_axis_c (32), m_axis_result (32)

**1.2 Add Adder IP**
```tcl
create_ip -name floating_point -vendor xilinx.com -library ip -version 7.1 -module_name floating_point_add -dir $ip_dir
set_property -dict [list \
    CONFIG.Operation_Type {Add} \
    CONFIG.A_Precision_Type {Single} \
    CONFIG.Result_Precision_Type {Single} \
    CONFIG.C_Latency {8} \
    CONFIG.C_Rate {1} \
    CONFIG.Flow_Control {Blocking} \
    CONFIG.Maximum_Latency {false} \
    CONFIG.Has_RESULT_TREADY {true} \
] [get_ips floating_point_add]
```
- Resource: ~0 DSP48E1 (uses LUTs only)
- Ports: s_axis_a (32), s_axis_b (32), m_axis_result (32)

**1.3 Update Build Script Configuration**
```tcl
# Define operation unit counts (configurable)
set NUM_FMA_UNITS 5
set NUM_ADD_UNITS 3
set NUM_MULT_UNITS 8  # Reduce from 20 to make room

set TOTAL_OP_UNITS [expr {$NUM_FMA_UNITS + $NUM_ADD_UNITS + $NUM_MULT_UNITS}]
# Total: 16 units
# Note: Add/Subtract operations share same IP (floating_point_addsub with add_sub control)
```

### Phase 2: Widen Input Data Path
**Files:** `build.tcl`, `top_module.vhd`

**2.1 Update Input FIFO Width**
- Current: 64 bits (2× 32-bit operands)
- New: 128 bits (4× 32-bit operands - all data, no metadata in data path)
- Update `axis_input_fifo` configuration:
```tcl
CONFIG.TDATA_NUM_BYTES {16} \  # Was 8, now 16 (128 bits)
```
- **Key Change:** OpCode moved to TUSER, freeing all 128 bits for operand data

**2.2 Encode OpCode in TUSER**
- TUSER already used for TDEST (multiplier routing)
- Need to expand TUSER width:
  - Bits [TDEST_WIDTH-1:0]: Destination unit within operation type
  - Bits [TDEST_WIDTH+3:TDEST_WIDTH]: OpCode (4 bits)
```tcl
set TUSER_WIDTH [expr {$TDEST_WIDTH + 4}]
```

**2.3 OpCode Encoding**
```
0x0: Multiply (a × b)           → Route to mult units
0x1: Add (a + b)                → Route to add units  
0x2: Subtract (a - b)           → Route to sub units
0x3: FMA (a×b + c)              → Route to FMA units
0x4: Accumulator (accum += a)   → Route to accum units
0x5-0xF: Reserved (compare, divide, sqrt, etc.)
```

### Phase 3: Create OpCode Demux Component
**File:** `src/hdl/opcode_demux.vhd` (new)

**Component Interface:**
```vhdl
entity opcode_demux is
    generic (
        NUM_MULT_UNITS  : integer := 8;
        NUM_FMA_UNITS   : integer := 5;
        NUM_ADD_UNITS   : integer := 3;
        TDATA_WIDTH     : integer := 128;
        TID_WIDTH       : integer := 16
    );
    port (
        aclk          : in  std_logic;
        aresetn       : in  std_logic;
        -- Input from FIFO
        s_axis_tdata  : in  std_logic_vector(TDATA_WIDTH-1 downto 0);
        s_axis_tuser  : in  std_logic_vector(7 downto 0);  -- [7:4]=opcode, [3:0]=unit_dest
        s_axis_tid    : in  std_logic_vector(TID_WIDTH-1 downto 0);
        s_axis_tvalid : in  std_logic;
        s_axis_tready : out std_logic;
        -- Outputs to operation units (separate buses per type)
        mult_tdata    : out std_logic_vector(NUM_MULT_UNITS*128-1 downto 0);
        mult_tvalid   : out std_logic_vector(NUM_MULT_UNITS-1 downto 0);
        mult_tready   : in  std_logic_vector(NUM_MULT_UNITS-1 downto 0);
        mult_tid      : out std_logic_vector(NUM_MULT_UNITS*TID_WIDTH-1 downto 0);
        -- (Similar for FMA, Add)
        -- Note: Add/Subtract share same units, use s_axis_operation_tdata bit to select
    );
end opcode_demux;
```

**Functionality:**
- Pipelined 1-cycle latency (like interconnect wrapper)
- Extracts opcode from TUSER[7:4]
- Extracts unit destination from TUSER[3:0]
- Routes transaction to appropriate operation type bus
- Preserves TID through pipeline
- Handles backpressure per operation type

### Phase 4: Update Interconnect Logic
**File:** `src/hdl/axis_interconnect_wrapper.vhd` (modify) or new component

**Option A: Reuse existing interconnect_wrapper**
- Currently routes by TDEST to multipliers
- Generalize to route by TUSER[3:0] to any operation unit within a type
- OpCode demux sits before it, segregates by operation type

**Option B: Merge into OpCode demux**
- Single component handles both opcode routing AND unit selection
- Cleaner but more complex

**Recommendation:** Use Option A (separate concerns)

### Phase 5: Update Result Collector
**File:** `src/hdl/result_collector.vhd` (modify)

**Changes:**
- Increase `NUM_INPUTS` generic to `TOTAL_OP_UNITS` (16)
- No other changes needed - already handles variable inputs
- Round-robin arbitration works across all operation types

### Phase 6: Update Top Module
**File:** `src/hdl/top_module.vhd`

**6.1 Add New Generics**
```vhdl
NUM_FMA_UNITS    : integer := 5;
NUM_ADD_UNITS    : integer := 3;
NUM_MULT_UNITS   : integer := 8;  -- Reduce from 20
```

**6.2 Update Input Port Width**
```vhdl
input_tdata  : in  std_logic_vector(127 downto 0);  -- Was 63:0
-- Operand layout: [127:96]=d, [95:64]=c, [63:32]=b, [31:0]=a
-- OpCode in TUSER, not in data path
```

**Benefits for Vec3/Vec4 Dot Products:**
- Vec3 dot: Uses [95:0] for 2× Vec3 (96 bits each would need 192 bits, but we can pack efficiently)
- Vec4 dot: Can pack 1 Vec4 per 128-bit word → 2-cycle burst instead of 4-cycle
- Reduces burst overhead significantly

**6.3 Add Component Declarations**
- floating_point_fma
- floating_point_addsub (handles both add and subtract)
- opcode_demux

**6.4 Instantiate New IP Cores**
```vhdl
gen_fma_units : for i in 0 to NUM_FMA_UNITS-1 generate
    fma_inst : floating_point_fma
        port map (
            aclk                 => clk_200,
            s_axis_a_tvalid      => fma_tvalid(i),
            s_axis_a_tready      => fma_tready(i),
            s_axis_a_tdata       => fma_tdata(i*128+31 downto i*128),
            s_axis_b_tvalid      => fma_tvalid(i),
            s_axis_b_tready      => open,
            s_axis_b_tdata       => fma_tdata(i*128+63 downto i*128+32),
            s_axis_c_tvalid      => fma_tvalid(i),
            s_axis_c_tready      => open,
            s_axis_c_tdata       => fma_tdata(i*128+95 downto i*128+64),
            m_axis_result_tvalid => fma_result_tvalid(i),
            m_axis_result_tready => fma_result_tready(i),
            m_axis_result_tdata  => fma_result_tdata((i+1)*32-1 downto i*32)
        );
end generate;
-- Similar for Add/Sub (same IP, different s_axis_operation_tdata), updated Mult
```

**6.5 Update Result Collector Input**
- Concatenate results from all operation types
- Concatenate TIDs from all TID pipelines
- Update input count to TOTAL_OP_UNITS

### Phase 7: Update Testbench
**File:** `src/sim/multiply_fifo_tb.vhd`

**7.1 Update Stimulus Generation**
- Generate 128-bit input data (a, b, c, d operands)
- Encode opcode in TUSER
- Test all operation types
- Verify results for each operation

**7.2 Test Cases**
```vhdl
-- Test multiply: 2.5 × 3.0 = 7.5
-- Test FMA: 2.0 × 3.0 + 1.5 = 7.5 (also used for dot products)
-- Test add: 4.5 + 2.5 = 7.0
-- Test sub: 10.0 - 3.5 = 6.5
```

## Resource Budget
**XC7A200T Available:** 740 DSP48E1 slices

**Proposed Allocation:**
- 8× Multiply: 16 DSP (2 per unit)
- 5× FMA: 20 DSP (4 per unit)
- 3× Add/Sub: 0 DSP (LUT-based, shared IP)
- **Total: 36 DSP (4.9% of available)** ✅

**Remaining:** 704 DSP available for Vec3/Vec4 dot products, future expansion

## Implementation Order
1. Add IP cores to `build.tcl` (Phase 1)
2. Test IP generation (run `build.tcl`, check no errors)
3. Create `opcode_demux.vhd` component (Phase 3)
4. Update `top_module.vhd` ports and generics (Phase 6.1-6.2)
5. Widen input FIFO (Phase 2)
6. Instantiate IP cores in top_module (Phase 6.3-6.4)
7. Update result collector (Phase 5)
8. Update testbench (Phase 7)
9. Run synthesis, verify resource usage
10. Run simulation, verify functionality

## Testing Strategy
- **Unit Test:** Each operation type independently
- **Integration Test:** Mixed operations through pipeline
- **Stress Test:** All units saturated simultaneously
- **Backpressure Test:** Verify blocking flow control works across all types
- **TID Verification:** Ensure TID preserved through all paths

## Notes
- FMA units will be reused for dedicated dot product units (Vec3/Vec4)
- Consider adding status outputs (overflow, underflow, invalid)
- OpCode demux could include operation count statistics
- Future: Add compare operations (equal, less than, etc.) for ray intersection tests

## Benefits of OpCode in TUSER (Not TDATA)

**Advantages:**
1. **Full 128-bit data path** available for operands (4× 32-bit FP values)
2. **Vec3 Dot Product Optimization:**
   - 2× Vec3 (3× fp32 each = 96 bits per vector) = 192 bits needed
   - Can pack partial vectors: First word [127:0] = Vec3_a + 1 component of Vec3_b
   - Second word completes Vec3_b → **2-cycle burst** instead of 4-cycle
3. **Vec4 Dot Product Optimization:**
   - 1× Vec4 = 128 bits → fits perfectly in one word
   - 2× Vec4 = 256 bits → **2-cycle burst** instead of 4-cycle
   - 50% reduction in burst cycles vs original plan
4. **Flexible operand usage:**
   - FMA: uses 3 operands (a, b, c) from [95:0], [127:96] available for future use
   - Multiply/Add/Sub: uses 2 operands (a, b) from [63:0], [127:64] available
   - Dot products: uses full 128 bits efficiently
5. **Clean separation:** OpCode routing logic separate from data path

**TUSER Encoding (8 bits suggested):**
```
TUSER[7:4] = OpCode (4 bits):
  0x0: Multiply (uses a, b)
  0x1: Add (uses a, b)
  0x2: Subtract (uses a, b)
  0x3: FMA (uses a, b, c)
  0x5: Vec3 Dot (2-cycle burst, uses all 128 bits both cycles, uses FMA)
  0x6: Vec4 Dot (2-cycle burst, uses all 128 bits both cycles, uses FMA)
  0x7-0xF: Reserved

TUSER[3:0] = Unit destination (4 bits)
  Selects which unit of the operation type (0-15)
```
