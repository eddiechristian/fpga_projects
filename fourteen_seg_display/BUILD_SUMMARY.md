# Build Directory Structure Summary

## What Changed

All Vivado-generated files are now contained in a `build/` subdirectory, keeping your project root clean.

## New Directory Structure

```
fourteen_seg_display/
├── src/                        # ← Tracked in Git
│   ├── hdl/                    # All VHDL design files
│   ├── sim/                    # Testbench files
│   └── constraints/            # XDC constraint files
├── build/                      # ← NOT tracked (in .gitignore)
│   ├── fourteen_seg_display.xpr
│   ├── fourteen_seg_display.cache/
│   ├── fourteen_seg_display.hw/
│   ├── fourteen_seg_display.runs/
│   └── ... (all other Vivado files)
├── create_project.tcl          # ← Tracked in Git
├── .gitignore                  # ← Tracked in Git
└── *.md                        # ← Documentation (tracked)
```

## Benefits

1. **Clean Repository**: Only source files tracked in Git
2. **Easy Cleanup**: Just `rm -rf build/` to start fresh
3. **Smaller Repo**: Build artifacts never committed
4. **Portable**: Works on any machine with Vivado

## Creating the Project

```bash
# From the project root directory
vivado -mode batch -source create_project.tcl
```

This creates:
- `build/fourteen_seg_display.xpr` (the Vivado project file)
- All other Vivado-generated files in `build/`

## Opening in Vivado GUI

```bash
vivado build/fourteen_seg_display.xpr
```

Or from Vivado GUI:
- File → Open Project
- Navigate to `build/fourteen_seg_display.xpr`

## Building from Command Line

```bash
# After creating project
cd build
vivado -mode batch -source <(cat << 'EOF'
open_project fourteen_seg_display.xpr
launch_runs impl_1 -to_step write_bitstream -jobs 4
wait_on_run impl_1
EOF
)
```

The bitstream will be in:
```
build/fourteen_seg_display.runs/impl_1/top_module.bit
```

## Workflow

### 1. Clone Repository
```bash
git clone <your-repo>
cd fourteen_seg_display
```

### 2. Create Vivado Project
```bash
vivado -mode batch -source create_project.tcl
```

### 3. Work on Your Design
- Edit files in `src/hdl/`
- Vivado project references these files directly
- Changes are immediately reflected in both places

### 4. Build and Test
```bash
vivado build/fourteen_seg_display.xpr
# ... work in Vivado GUI ...
```

### 5. Commit Changes
```bash
git add src/hdl/modified_file.vhd
git commit -m "Description of changes"
git push
```

## Cleaning Up

Remove all generated files:
```bash
rm -rf build/ .Xil/ *.log *.jou
```

Then recreate:
```bash
vivado -mode batch -source create_project.tcl
```

## What Gets Committed to Git

✅ **Committed:**
- `src/` directory (all source files)
- `create_project.tcl`
- `.gitignore`
- Documentation files (`*.md`, `*.txt`)

❌ **Not Committed (in .gitignore):**
- `build/` directory
- `.xpr` files
- Log files (`*.log`, `*.jou`)
- `.Xil/` directory

## Notes

- The old `fourteen_seg_display/` directory structure is replaced with `build/`
- The TCL script automatically creates the `build/` directory
- All Vivado work happens in `build/`, keeping the root clean
- Source files in `src/` are the single source of truth
