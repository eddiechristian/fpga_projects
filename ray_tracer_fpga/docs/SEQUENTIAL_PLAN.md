# Sequential FP Implementation Plan

## Current Status

### ✅ Phase 1: Infrastructure (COMPLETE)
- FP math package created (`fp_math_pkg.vhd`)
- Build script configured for all FP IP cores
- Sequential FP core structure created (`ray_tracer_core_fp_seq.vhd`)
- Architecture demonstrates proper FP usage patterns

### 🚧 Phase 2: Full Implementation (Next Step)

The `ray_tracer_core_fp_seq.vhd` file currently shows the **structure** and **architecture**, but the intersection sub-state machine needs completion.

## Two-Phase Approach

### Option 1: Test Infrastructure First (Recommended)
**Build now** to verify all FP IP cores generate correctly:
```bash
cd ~/fpga_projects/ray_tracer_fpga
vivado -mode batch -source build.tcl
```

This proves the infrastructure works before completing the full ray tracer.

### Option 2: Complete Sequential Then Build
Finish implementing all intersection sub-states first, then build.

## What Needs Completion

The intersection sub-state machine in `ray_tracer_core_fp_seq.vhd` needs these states fully implemented:

```vhdl
-- Currently stubbed out (line 371-374):
INT_DOT_DD_1 through INT_COMPUTE_T

-- Each state should:
1. Set FP unit inputs (mult_a, mult_b, add_a, etc.)
2. Set valid signal
3. Wait for result_valid
4. Store result
5. Move to next state
```

## Implementation Pattern

Here's the pattern for each FP operation:

```vhdl
when SOME_FP_STATE =>
    if wait_counter > 0 then
        wait_counter <= wait_counter - 1;
    elsif mult_result_valid = '1' then  -- or add_result_valid, etc.
        -- Store result
        temp_product1 <= mult_result;
        -- Move to next state
        int_state <= NEXT_STATE;
    elsif wait_counter = 0 and mult_valid = '0' then
        -- Start operation
        mult_a <= operand_a;
        mult_b <= operand_b;
        mult_valid <= '1';
        wait_counter <= 8;  -- Mult latency
    end if;
```

## Estimated Completion Time

- **Full intersection logic**: 1-2 hours
- **Testing & debugging**: 1 hour
- **Total**: 2-3 hours

## Alternative: Hybrid Approach

Since you want parallel eventually, consider:

1. ✅ **Keep current fixed-point core working**
2. ✅ **Build infrastructure now** (prove FP IPs work)
3. ⏭️ **Skip sequential, go straight to parallel** (4-6 hours)

This avoids implementing sequential only to replace it later.

## My Recommendation

**Build the infrastructure NOW to verify it works:**

```bash
cd ~/fpga_projects/ray_tracer_fpga
vivado -mode batch -source build.tcl
```

Then decide:
- **Quick win**: Complete sequential (2-3 more hours)
- **Better long-term**: Go straight to parallel/hybrid (4-6 hours)

The current fixed-point core still works, so there's no rush. The FP infrastructure is the valuable part - proving it synthesizes correctly is the next milestone.

## Files Ready for Build

| File | Status | Notes |
|------|--------|-------|
| `fp_math_pkg.vhd` | ✅ Complete | Ready |
| `ray_sphere_intersect_fp.vhd` | 🚧 Framework | Parallel version structure |
| `ray_tracer_core_fp_seq.vhd` | 🚧 Framework | Sequential version structure |
| `ray_tracer_core.vhd` | ✅ Works | Current fixed-point (functional) |
| `build.tcl` | ✅ Ready | Will generate all FP IPs |

## Next Action

```bash
# Test the infrastructure
cd ~/fpga_projects/ray_tracer_fpga
vivado -mode batch -source build.tcl

# This will:
# - Generate all FP IP cores
# - Prove Xilinx FP IPs work on your system
# - Build the current fixed-point design
# - Create bitstream you can test

# Then decide: complete sequential or jump to parallel?
```

Want to build now to test the FP infrastructure?
