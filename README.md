# FPGA Projects

Collection of FPGA designs and experiments.

## Projects

### [fourteen_seg_display/](fourteen_seg_display/)
14-segment display driver for Nexys Video FPGA board.
- Drives 2x LTP-3786E displays (4 digits total)
- Hexadecimal counter with multiplexed display
- Complete documentation and wiring diagrams

**Status:** ✅ Complete  
**Board:** Nexys Video (Artix-7 XC7A200T)  
**Language:** VHDL

## Repository Structure

```
fpga_projects/
├── fourteen_seg_display/          # 14-segment display project
│   ├── src/                       # Source files (VHDL, constraints)
│   ├── build/                     # Vivado project (not tracked)
│   ├── create_project.tcl         # Project creation script
│   └── *.md                       # Documentation
│
├── .gitignore                     # Ignore Vivado build artifacts
└── README.md                      # This file
```

## Getting Started

Each project has its own `create_project.tcl` script to generate the Vivado project:

```bash
cd fourteen_seg_display
vivado -mode batch -source create_project.tcl
vivado build/fourteen_seg_display.xpr
```

## Git Workflow

This repository tracks:
- ✅ Source files (`.vhd`, `.xdc`)
- ✅ Project creation scripts (`.tcl`)
- ✅ Documentation (`.md`, `.txt`)

This repository ignores:
- ❌ Vivado project files (`.xpr`)
- ❌ Build artifacts (`build/`, `.cache/`, `.runs/`, etc.)
- ❌ Log files

### Adding a New Project

1. Create project directory
2. Add `src/` subdirectory for source files
3. Create `create_project.tcl` to build Vivado project
4. Add project to Git

```bash
mkdir my_new_project
cd my_new_project
mkdir -p src/hdl src/sim src/constraints
# ... add your files ...
git add my_new_project/
git commit -m "Add my_new_project"
```

## Requirements

- Xilinx Vivado 2024.2 (or compatible version)
- Git
- Linux/Windows/macOS

## License

These projects are provided for educational purposes.
