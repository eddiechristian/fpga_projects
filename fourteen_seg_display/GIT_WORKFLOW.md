# Git Workflow for Vivado Projects

## Project Structure

```
fourteen_seg_display/
├── src/
│   ├── hdl/                    # All VHDL design files
│   │   ├── counter.vhd
│   │   ├── debouncer.vhd
│   │   ├── ascii_to_14seg.vhd
│   │   ├── display_dec_to_hex.vhd
│   │   ├── segment_multiplexor.vhd
│   │   └── top_module.vhd
│   ├── sim/                    # Testbench files
│   │   └── tb_segment_multiplexor.vhd
│   └── constraints/            # Constraint files
│       └── nexys_video.xdc
├── create_project.tcl          # Project creation script
├── .gitignore                  # Git ignore patterns
├── README.md                   # Project documentation
├── WIRING_DIAGRAM.md          # Hardware wiring guide
├── LTP-3786E_PINOUT.txt       # Display pinout
├── RESISTOR_SELECTION.md      # Resistor guide
└── GIT_WORKFLOW.md            # This file
```

## Initial Setup

### 1. Initialize Git Repository

```bash
cd /home/eddie/fpga_projects/fourteen_seg_display
git init
```

### 2. Add Files to Git

```bash
# Add source files
git add src/

# Add TCL script
git add create_project.tcl

# Add documentation
git add README.md WIRING_DIAGRAM.md LTP-3786E_PINOUT.txt RESISTOR_SELECTION.md GIT_WORKFLOW.md

# Add gitignore
git add .gitignore
```

### 3. Make Initial Commit

```bash
git commit -m "Initial commit: 14-segment display project for Nexys Video"
```

## Creating the Vivado Project from Git

After cloning the repository or checking out a clean copy:

### Option 1: Command Line (Batch Mode)
```bash
cd fourteen_seg_display
vivado -mode batch -source create_project.tcl
```

### Option 2: Vivado GUI
```bash
cd fourteen_seg_display
vivado -source create_project.tcl
```

This will:
- Create `build/` directory with all Vivado project files
- Add all HDL files from `src/hdl/`
- Add simulation files from `src/sim/`
- Add constraints from `src/constraints/`
- Set up proper file hierarchy

## Daily Workflow

### Making Changes

1. **Edit source files in `src/` directory**
   ```bash
   # Edit your VHDL files
   vim src/hdl/top_module.vhd
   ```

2. **Work in Vivado normally**
   - The Vivado project references files in `src/` directly
   - Changes in Vivado are reflected in `src/`

3. **Check what changed**
   ```bash
   git status
   git diff
   ```

4. **Commit changes**
   ```bash
   git add src/hdl/top_module.vhd
   git commit -m "Add feature X to top module"
   ```

### Updating Constraints

```bash
# Edit constraints
vim src/constraints/nexys_video.xdc

# Commit
git add src/constraints/nexys_video.xdc
git commit -m "Update pin constraints for new feature"
```

### Adding New Files

If you add new VHDL files in Vivado:

1. **Copy to src directory**
   ```bash
   cp fourteen_seg_display.srcs/sources_1/new/new_module.vhd src/hdl/
   ```

2. **Update create_project.tcl**
   Add the new file to the `add_files` section:
   ```tcl
   add_files -norecurse {
       src/hdl/counter.vhd
       src/hdl/new_module.vhd    # <-- Add here
       ...
   }
   ```

3. **Commit both**
   ```bash
   git add src/hdl/new_module.vhd create_project.tcl
   git commit -m "Add new_module.vhd"
   ```

## What Gets Tracked in Git

✅ **Tracked:**
- Source files (`.vhd`, `.xdc`)
- TCL project creation script
- Documentation (`.md`, `.txt`)
- `.gitignore`

❌ **Not Tracked (ignored):**
- `.xpr` project files
- Build artifacts (`.runs/`, `.cache/`, etc.)
- Simulation files (`.sim/`)
- Generated files (`.gen/`)
- Log files

## Cleaning Up

To remove all generated Vivado files:

```bash
# Remove build directory (contains all Vivado-generated files)
rm -rf build/

# Remove other generated files
rm -rf .Xil/ *.log *.jou
```

Then recreate from TCL script:
```bash
vivado -mode batch -source create_project.tcl
```

## Working with Branches

### Create a feature branch
```bash
git checkout -b feature/new-display-mode
# Make changes...
git add src/hdl/top_module.vhd
git commit -m "Implement new display mode"
```

### Merge back to main
```bash
git checkout main
git merge feature/new-display-mode
```

## Remote Repository (GitHub/GitLab)

### Initial push
```bash
git remote add origin https://github.com/yourusername/fourteen_seg_display.git
git branch -M main
git push -u origin main
```

### Daily sync
```bash
# Pull latest changes
git pull origin main

# Push your changes
git push origin main
```

## Collaboration Tips

1. **Always recreate project after pulling**
   ```bash
   git pull
   rm -rf build/
   vivado -mode batch -source create_project.tcl
   ```

2. **Commit often, push regularly**
   - Commit after each logical change
   - Push at the end of your work session

3. **Write good commit messages**
   - Bad: "fixed stuff"
   - Good: "Fix timing violation in counter module"

4. **Use branches for experiments**
   - Don't commit broken code to main
   - Test thoroughly before merging

## Troubleshooting

### "File not found" when creating project
- Make sure you're in the root directory
- Check that `src/` directory structure is correct
- Verify file paths in `create_project.tcl`

### Vivado made changes to project structure
- Don't commit the auto-generated changes
- Keep working in `src/` directory
- Let Vivado generate its structure in `build/`

### Merge conflicts in VHDL files
```bash
# See what files have conflicts
git status

# Edit files to resolve conflicts
vim src/hdl/conflicted_file.vhd

# Mark as resolved and commit
git add src/hdl/conflicted_file.vhd
git commit -m "Resolve merge conflict in conflicted_file"
```

## Best Practices

1. ✅ **DO**: Keep all source files in `src/` directory
2. ✅ **DO**: Commit TCL script when you change project settings
3. ✅ **DO**: Write descriptive commit messages
4. ✅ **DO**: Test before committing
5. ❌ **DON'T**: Commit `.xpr` files
6. ❌ **DON'T**: Commit build artifacts
7. ❌ **DON'T**: Edit files directly in `build/fourteen_seg_display.srcs/`
8. ❌ **DON'T**: Commit bitstreams (unless intentional)

## Summary

This workflow keeps your repository clean and portable:
- **Small repo size**: Only source files tracked
- **Reproducible**: Anyone can recreate the project with one command
- **Flexible**: Work in Vivado normally, commit from `src/`
- **Portable**: Works on any machine with Vivado installed
