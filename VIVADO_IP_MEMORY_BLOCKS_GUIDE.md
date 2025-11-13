# Using Predefined Memory Blocks in Vivado (Nexys Video FPGA)

This guide explains how to create and use Block Memory Generator (BRAM) IP cores in Vivado for the Nexys Video FPGA board (xc7a200tsbg484-1).

## Overview

Memory blocks are created as **IP (Intellectual Property) cores** in Vivado. These become `.xci` files that contain the IP configuration and generate the actual implementation files during synthesis.

## Step 1: Create a New IP Core

### Method A: Using IP Catalog (GUI)

1. **Open your Vivado project**
   - Project → Open Project
   - Or create a new project: File → New → Project

2. **Navigate to IP Catalog**
   - Window → IP Catalog (or Ctrl+I)
   - Search for "Block Memory Generator" (or "BRAM")

3. **Instantiate the IP**
   - Double-click "Block Memory Generator"
   - Or right-click → Customize IP

### Method B: Using TCL (Command Line)

```tcl
# Create a new IP
set ip [create_ip -name blk_mem_gen -vendor xilinx.com \
  -library ip -version 8.4 -module_name my_memory]

# Set properties
set_property -dict [list \
  CONFIG.Memory_Type {Dual_Port_RAM} \
  CONFIG.Write_Width_A {8} \
  CONFIG.Read_Width_A {8} \
  CONFIG.Write_Depth_A {1024} \
] $ip
```

## Step 2: Configure the IP Block

### Common Configuration Parameters

**Memory Type** (CONFIG.C_MEM_TYPE):
- `0` = Single Port RAM (one read/write port)
- `1` = Dual Port RAM (one read, one write port)
- `2` = Simple Dual Port (dual read or write)
- `3` = ROM (Read-only memory)

**Data Width** (CONFIG.C_WRITE_WIDTH_A / C_READ_WIDTH_A):
- 1-72 bits per word
- Common: 8, 16, 32 bits

**Memory Depth** (CONFIG.C_WRITE_DEPTH_A / C_READ_DEPTH_A):
- Total number of words
- Example: 1024 = 1KB (for 8-bit words)
- Example: 512 = 4KB (for 64-bit words)

**Address Width** (automatically calculated):
- For 1024 words: 10-bit address
- For 512 words: 9-bit address

**Initialization** (CONFIG.C_LOAD_INIT_FILE):
- Set to `1` to load data from file
- CONFIG.C_INIT_FILE_NAME: Path to `.coe` or `.mem` file

### Step 3: Configure Memory in GUI

1. **In the IP Customization window:**

2. **Port A / Port B Configuration:**
   - Set Memory Type (Dual Port RAM recommended for display buffer)
   - Set Write Width/Depth
   - Set Read Width/Depth
   - Enable "Write Enable" if you need it
   - Configure read latency (1 cycle is typical)

3. **Initialization Tab:**
   - Check "Load Init File"
   - Browse to your data file (`.coe`, `.mif`, or `.mem`)

4. **Other Options:**
   - Primitive Type: Auto (let Vivado choose BRAM/LUTRAM)
   - Enable ECC: No (unless error correction needed)
   - Common Clock: Yes (if using same clock for both ports)

5. **Click OK** to finish configuration

## Step 4: Generate the IP Core

### GUI Method:
1. **Project Manager** → IP Sources
2. Right-click your `.xci` file
3. **Generate Output Products** (or Run Customization)
4. Wait for generation to complete

### TCL Method:
```tcl
generate_target {simulation synthesis} $ip
export_ip_user_files -of_objects $ip -no_script -force -quiet
```

## Step 5: Use the IP in Your HDL Code

### VHDL Example:

```vhdl
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity top is
    Port (
        clk : in STD_LOGIC;
        write_data : in STD_LOGIC_VECTOR(7 downto 0);
        write_addr : in STD_LOGIC_VECTOR(8 downto 0);
        write_en : in STD_LOGIC;
        read_addr : in STD_LOGIC_VECTOR(8 downto 0);
        read_data : out STD_LOGIC_VECTOR(7 downto 0)
    );
end top;

architecture Behavioral of top is

    component my_memory
        port (
            clka : in STD_LOGIC;
            wea : in STD_LOGIC_VECTOR(0 downto 0);
            addra : in STD_LOGIC_VECTOR(8 downto 0);
            dina : in STD_LOGIC_VECTOR(7 downto 0);
            clkb : in STD_LOGIC;
            addrb : in STD_LOGIC_VECTOR(8 downto 0);
            doutb : out STD_LOGIC_VECTOR(7 downto 0)
        );
    end component;

begin

    -- Instantiate BRAM IP
    pixel_buffer : my_memory
    port map (
        clka => clk,
        wea(0) => write_en,
        addra => write_addr,
        dina => write_data,
        clkb => clk,
        addrb => read_addr,
        doutb => read_data
    );

end Behavioral;
```

### Port Naming Convention:

- **Port A** (usually write):
  - `clka`: Clock
  - `addra(n downto 0)`: Address (n depends on depth)
  - `dina(m downto 0)`: Input data (m depends on width)
  - `wea(0)`: Write enable (note: vector form)
  - `douta(m downto 0)`: Output data (if dual read)

- **Port B** (usually read):
  - `clkb`: Clock
  - `addrb(n downto 0)`: Address
  - `doutb(m downto 0)`: Output data

## Step 6: Add IP to Your Project

### Method A: GUI
1. **Sources** panel
2. Right-click **IP Sources**
3. **Add Sources** → **Add or Create Design Sources**
4. Select your `.xci` file
5. Click Finish

### Method B: TCL
```tcl
add_files [glob *.xci]
```

## Step 7: Get Component Wrapper from IP

1. **In Vivado GUI:**
   - **File** → **Design Sources**
   - Right-click on your IP `.xci` file
   - Select **View IP Instantiation Template**
   - Copy the component declaration and port map

2. **Or find the wrapper:**
   - Look in `hw.gen/<ip_name>/ip/<ip_name>/synth/` folder
   - Find the `.vhd` file (e.g., `my_memory.vhd`)
   - Use the entity and port definitions from there

## Step 8: Complete VHDL Example

### Using charLib (Font ROM) and pixel_buffer (Dual Port RAM)

```vhdl
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity oled_memory_example is
    Port (
        clk : in STD_LOGIC;
        
        -- Character write interface
        char_write_en : in STD_LOGIC;
        char_ascii : in STD_LOGIC_VECTOR(7 downto 0);
        char_row : in STD_LOGIC_VECTOR(2 downto 0);
        char_bitmap : out STD_LOGIC_VECTOR(7 downto 0);
        
        -- Display read interface
        display_addr : in STD_LOGIC_VECTOR(8 downto 0);
        display_data : out STD_LOGIC_VECTOR(7 downto 0)
    );
end oled_memory_example;

architecture Behavioral of oled_memory_example is

    component charLib
        port (
            clka : in STD_LOGIC;
            addra : in STD_LOGIC_VECTOR(9 downto 0);
            douta : out STD_LOGIC_VECTOR(7 downto 0)
        );
    end component;

    component pixel_buffer
        port (
            clka : in STD_LOGIC;
            wea : in STD_LOGIC_VECTOR(0 downto 0);
            addra : in STD_LOGIC_VECTOR(8 downto 0);
            dina : in STD_LOGIC_VECTOR(7 downto 0);
            clkb : in STD_LOGIC;
            addrb : in STD_LOGIC_VECTOR(8 downto 0);
            doutb : out STD_LOGIC_VECTOR(7 downto 0)
        );
    end component;

    signal char_lib_addr : STD_LOGIC_VECTOR(9 downto 0);
    signal char_bitmap_data : STD_LOGIC_VECTOR(7 downto 0);

begin

    -- Character ROM: 10-bit address = {ASCII code (7 bits), row (3 bits)}
    char_lib_addr <= char_ascii(6 downto 0) & char_row;

    font_rom : charLib
    port map (
        clka => clk,
        addra => char_lib_addr,
        douta => char_bitmap_data
    );

    char_bitmap <= char_bitmap_data;

    -- Pixel Buffer: Dual port RAM
    -- Port A: Write character data from ROM
    -- Port B: Read for display output
    frame_buffer : pixel_buffer
    port map (
        clka => clk,
        wea(0) => char_write_en,
        addra => display_addr,  -- Normally would be write_addr, simplified here
        dina => char_bitmap_data,
        clkb => clk,
        addrb => display_addr,
        doutb => display_data
    );

end Behavioral;
```

## Step 9: Synthesis and Implementation

1. **Run Synthesis**: Flow → Run Synthesis
2. **Run Implementation**: Flow → Run Implementation
3. **Generate Bitstream**: Flow → Generate Bitstream

Vivado will automatically:
- Map IP cores to FPGA resources
- Handle timing constraints
- Optimize for your target device

## Memory Block Data File Formats

### COE Format (.coe):
```
memory_initialization_radix=16;
memory_initialization_vector=
00,01,02,03,04,05,06,07,
08,09,0A,0B,0C,0D,0E,0F;
```

### MIF Format (.mif):
```
DEPTH = 256;
WIDTH = 8;
ADDRESS_RADIX = HEX;
DATA_RADIX = BIN;

CONTENT BEGIN
00: 00000000;
01: 00000001;
...
END;
```

### MEM Format (.mem):
```
00000000
00000001
00000010
...
```

## Example: Creating a 512-byte Pixel Buffer

### Configuration for OLED Display:

```
Memory Type:     Dual Port RAM
Write Width:     8 bits
Read Width:      8 bits
Write Depth:     512
Read Depth:      512
Address Width:   9 bits (auto)
Write Mode:      No Change
Read Latency:    1 cycle
Common Clock:    Yes
Init File:       pixel_buffer.coe
```

### Address Mapping:

```
Address(8 downto 0) <= page(1 downto 0) & column(6 downto 0);
Range: 0x000 to 0x1FF (512 bytes)
```

## File Organization

Your project structure should look like:

```
project/
├── hw.xpr                          (Vivado project)
├── hw.srcs/
│   ├── sources_1/
│   │   └── hdl/
│   │       ├── top.vhd             (Your design)
│   │       └── oled_ctrl.vhd       (Modules using IP)
│   └── constrs_1/
│       └── constraints.xdc         (Pin assignments)
├── hw.ip_user_files/
│   ├── mem_init_files/
│   │   └── my_memory.coe           (Initialization file)
│   └── ip/
│       └── my_memory/              (Generated IP)
└── hw.gen/
    └── my_memory/                  (Generated output products)
```

## Important Notes

1. **IP Caching**: Vivado caches generated IP. If you modify `.xci` settings, regenerate:
   - Right-click `.xci` → Reset Output Products
   - Then regenerate

2. **Device Constraints**: Nexys Video has:
   - 1 x 36 Kbit BRAM (or 2 x 18 Kbit)
   - Total ~13 Mbits available
   - 512 bytes = 4 Kbits (well within limits)

3. **Timing**: 
   - Set read latency to match your design requirements
   - 1 cycle is most common
   - Single Port RAM is faster than Dual Port

4. **Simulation**: 
   - Vivado generates simulation models automatically
   - Use `vivado_sim` for testing before synthesis

5. **Bitstream Size**: 
   - IP cores add minimal overhead
   - Nexys Video bitstream size ≈ 6-8 MB

6. **VHDL Port Mapping Notes:**
   - Write enable (`wea`) is a **vector** even for single bit (use `wea(0) => signal`)
   - Clock and address signals are standard STD_LOGIC(_VECTOR)
   - Port names are case-sensitive in the generated wrapper

## Troubleshooting

| Issue | Solution |
|-------|----------|
| "IP not found" | Regenerate output products |
| Initialization file not loading | Check file path is absolute or relative to `.xci` location |
| Address width mismatch | Verify log₂(depth) = address width |
| Timing errors | Increase read latency or relax timing constraints |
| Resource errors | Check total BRAM usage vs. available |
| Port map errors in VHDL | Ensure vector sizes match exactly (e.g., `wea(0)` not `wea`) |

## Quick Reference: Nexys Video BRAM Resources

- **Total BRAM**: ~13 Mbits
- **Block size**: 36 Kbits or dual 18 Kbits
- **Max configurations**: 
  - 1 × 512KB RAM
  - 32 × 16KB RAMs
  - 128 × 4KB RAMs

For your OLED project:
- charLib (1K × 8-bit) = 8 Kbits = 1 BRAM
- pixel_buffer (512 × 8-bit) = 4 Kbits = 1 BRAM
- init_sequence_rom (16 × 16-bit) = 256 bits = negligible

**Total used: ~2 BRAMs out of available ~350 BRAMs** ✓

## VHDL Tips for IP Integration

### Convert Entity to Component Declaration:

From generated `my_memory.vhd`:
```vhdl
entity my_memory is
  port (
    clka : in std_logic;
    wea : in std_logic_vector(0 downto 0);
    addra : in std_logic_vector(8 downto 0);
    ...
  );
end my_memory;
```

Component in your code:
```vhdl
component my_memory
    port (
        clka : in std_logic;
        wea : in std_logic_vector(0 downto 0);
        addra : in std_logic_vector(8 downto 0);
        ...
    );
end component;
```

### Use instantiation template from Vivado:
1. Right-click `.xci` file
2. **View IP Instantiation Template**
3. Copy-paste into your VHDL file
4. Adjust signal names as needed
