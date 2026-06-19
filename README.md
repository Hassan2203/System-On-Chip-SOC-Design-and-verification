# RV32I Processor with Wishbone Bus on Colorlight i5 FPGA

This README explains how to build and upload the **RV32I processor + Wishbone bus** project on the **Colorlight i5 / Lattice ECP5 45K FPGA**.

The final project flow is:

```text
C code
  ↓
RISC-V GCC compiler
  ↓
program.elf / program.bin / program.hex
  ↓
rom_init.vh
  ↓
Wishbone ROM instruction memory
  ↓
RV32I CPU fetches instructions through Wishbone
  ↓
CPU writes to LED MMIO address 0x00002000
  ↓
Wishbone interconnect selects LED slave
  ↓
FPGA LEDs on Colorlight i5
```

The complete workflow of the project is mentioned below.
<img width="1055" height="1491" alt="ChatGPT Image Jun 16, 2026, 10_27_35 AM" src="https://github.com/user-attachments/assets/a0c43aa0-e39c-40fc-a8c8-013645bd9359" />


## Project architecture

```text
RV32I CPU
  │
  │ Wishbone Master
  ↓
Wishbone Interconnect
  ├── S0: wb_rom  → Instruction Memory  → 0x00000000 to 0x00000FFF
  ├── S1: wb_ram  → Data Memory         → 0x00001000 to 0x00001FFF
  └── S2: wb_led  → LED Peripheral      → 0x00002000 to 0x00002FFF
```

The C code writes LED values to:

```c
#define LED_ADDR ((volatile unsigned int *)0x00002000)
```
Colorlight i5 FPGA pins used:

```text
clk     = P3
led[0]  = K18
led[1]  = T18
led[2]  = R17
led[3]  = M17
```

---

The architecture is shown below.
<img width="1672" height="941" alt="flow" src="https://github.com/user-attachments/assets/df179d4c-333f-47c1-b9c2-23833a08b183" />


# Separate Step-by-Step Commands

## Step 1: Check GCC compatibility

First go to the project folder:

```bash
cd ~/Downloads/CEP_FPGA_LED_FIXED/wishbone_fixed
```

Check that the RISC-V GCC toolchain is installed:

```bash
which riscv64-unknown-elf-gcc
which riscv64-unknown-elf-objcopy
which riscv64-unknown-elf-objdump

riscv64-unknown-elf-gcc --version
```

If GCC is not installed, install it:

```bash
sudo apt update
sudo apt install gcc-riscv64-unknown-elf binutils-riscv64-unknown-elf -y
```

The firmware must be compiled for RV32I only, so the important GCC flags are:

```text
-march=rv32i
-mabi=ilp32
-nostdlib
-nostartfiles
-ffreestanding
-fno-pic
-mcmodel=medlow
```

These flags make the C program compatible with the custom RV32I processor.

---
The below figure shows the full output using GTKWAVE.
<img width="1075" height="625" alt="image" src="https://github.com/user-attachments/assets/45292eca-74d4-4a96-8686-8764c333b782" />



## Step 2: GCC to HEX conversion

The C firmware is inside:

```text
code.c
```

The startup file is:

```text
startup.s
```

The linker script is:

```text
link.ld
```

Run the firmware build script:

```bash
./build_firmware.sh
```

This script performs:

```text
code.c + startup.s + link.ld
  ↓
program.elf
  ↓
program.bin
  ↓
program.hex
  ↓
rom_init.vh
```

After running it, check the generated files:

```bash
ls -lh program.elf program.bin program.hex rom_init.vh firmware.dump
```

Check that `_start` is placed at address `0x00000000`:

```bash
head -n 50 firmware.dump
```

Expected important line:

```text
00000000 <_start>:
```

This is important because the CPU reset PC starts from address `0x00000000`.

If you manually change `program.hex`, always regenerate `rom_init.vh`:

```bash
./make_rom_init.sh
```

---

The generated binary is shown below.
<img width="846" height="390" alt="image" src="https://github.com/user-attachments/assets/292e0549-91d0-470b-ae0e-2fa3714104a2" />



So the LED Output is shown below
<img width="651" height="246" alt="image" src="https://github.com/user-attachments/assets/18d80f22-6f59-4004-8efb-fe794784c5a9" />

## Step 3: Synthesis using Yosys

Yosys converts the Verilog RTL design into an ECP5 netlist JSON file.

Run synthesis manually:

```bash
yosys -p "read_verilog ALU.v ALU_control.v control_unit.v Immediate_Generator.v Register_file.v wb_interconnect.v wb_rom.v wb_ram.v wb_led.v top.v; synth_ecp5 -top tope -json cpu.json"
```

Output file:

```text
cpu.json
```

This file is used by nextpnr.

---

The resources used in this project is shown below.
<img width="538" height="431" alt="image" src="https://github.com/user-attachments/assets/b5aba75a-e3c1-4842-8309-ff65b9d3dd4d" />


## Step 4: nextpnr-ecp5 command

For Colorlight i5, the FPGA target is:

```text
Lattice ECP5 45K
Package: CABGA381
```

Run nextpnr:

```bash
nextpnr-ecp5 --45k --package CABGA381 \
  --json cpu.json \
  --lpf constraints_colorlight_i5.lpf \
  --textcfg cpu.config
```

Input file:

```text
cpu.json
```

Constraint file:

```text
constraints_colorlight_i5.lpf
```

<img width="582" height="339" alt="image" src="https://github.com/user-attachments/assets/e784effa-27b1-47b1-abf4-70eacd6f2421" />


Output file:

```text
cpu.config
```

---

## Step 5: Place-and-route and bitstream packing

In this flow, `nextpnr-ecp5` performs the place-and-route step and generates:

```text
cpu.config
```

Then `ecppack` converts `cpu.config` into the final FPGA bitstream:

```bash
ecppack --idcode 0x41112043 cpu.config cpu.bit
```

Output bitstream:

```text
cpu.bit
```

Check the bitstream:

```bash
ls -lh cpu.bit
```

The IDCODE used for Colorlight i5 ECP5 45K is:

```text
0x41112043
```

---

## Step 6: Burn/upload bitstream into FPGA

First check that the FPGA is detected through CMSIS-DAP:

```bash
sudo ~/fpga/openFPGALoader/build/openFPGALoader -c cmsisdap --detect
```

Expected board family:

```text
family ECP5
model  LFE5U-45
idcode 0x41112043
```

Upload the bitstream:

```bash
sudo ~/fpga/openFPGALoader/build/openFPGALoader -c cmsisdap cpu.bit
```

Successful upload shows:

```text
Loading: [==================================================] 100.00%
Done
```

After upload, the C program should run on the FPGA and control the LEDs through the Wishbone LED peripheral.

Expected C-code LED sequence:

```text
0001 → 0010 → 0100 → 1000 → 0100 → 0010 → repeat
```

---

<img width="647" height="180" alt="image" src="https://github.com/user-attachments/assets/dd0759ab-b601-49eb-8beb-fec7d18a02db" />

LED Blinking sequence on FPGA is shown below.

<img width="516" height="269" alt="image" src="https://github.com/user-attachments/assets/46f49c15-7d8a-4c36-b95b-25b243691ed3" />


# Complete Combined Flow

Use this complete command sequence when all files are already prepared:

```bash
cd ~/Downloads/CEP_FPGA_LED_FIXED/wishbone_fixed

# 1. Check RISC-V GCC
which riscv64-unknown-elf-gcc
which riscv64-unknown-elf-objcopy
which riscv64-unknown-elf-objdump
riscv64-unknown-elf-gcc --version

# 2. Compile C firmware and generate program.hex + rom_init.vh
./build_firmware.sh

# 3. Synthesis using Yosys
yosys -p "read_verilog ALU.v ALU_control.v control_unit.v Immediate_Generator.v Register_file.v wb_interconnect.v wb_rom.v wb_ram.v wb_led.v top.v; synth_ecp5 -top tope -json cpu.json"

# 4. Place-and-route using nextpnr-ecp5
nextpnr-ecp5 --45k --package CABGA381 \
  --json cpu.json \
  --lpf constraints_colorlight_i5.lpf \
  --textcfg cpu.config

# 5. Pack the bitstream
ecppack --idcode 0x41112043 cpu.config cpu.bit

# 6. Detect FPGA
sudo ~/fpga/openFPGALoader/build/openFPGALoader -c cmsisdap --detect

# 7. Upload bitstream to FPGA
sudo ~/fpga/openFPGALoader/build/openFPGALoader -c cmsisdap cpu.bit
```

---

# Short Combined Flow Using Scripts

This is the easiest working flow:

```bash
cd ~/Downloads/CEP_FPGA_LED_FIXED/wishbone_fixed

./build_firmware.sh
./build_wishbone_colorlight_i5.sh
sudo ~/fpga/openFPGALoader/build/openFPGALoader -c cmsisdap --detect
sudo ~/fpga/openFPGALoader/build/openFPGALoader -c cmsisdap cpu.bit
```

---

# Important Files

```text
code.c                         C firmware for LED blinking
startup.s                      startup code, places _start at address 0x00000000
link.ld                        linker script, ROM/RAM memory map
program.hex                    machine code in HEX format
rom_init.vh                    generated ROM initialization file
wb_rom.v                       Wishbone instruction memory
wb_ram.v                       Wishbone data memory
wb_led.v                       Wishbone LED peripheral
wb_interconnect.v              Wishbone address decoder/interconnect
top.v                          CPU + Wishbone SoC top module
constraints_colorlight_i5.lpf  Colorlight i5 FPGA pin constraints
build_firmware.sh              builds C firmware to program.hex and rom_init.vh
make_rom_init.sh               converts program.hex to rom_init.vh
build_wishbone_colorlight_i5.sh builds FPGA cpu.bit
```

---

# Notes

- Always run `./build_firmware.sh` after changing `code.c`.
- Always run `./make_rom_init.sh` after manually changing `program.hex`.
- Always use the Colorlight i5 upload command with `-c cmsisdap`.
- Do not use `openFPGALoader -b ulx3s` for this board.
- The FPGA board must be connected to the local PC when running openFPGALoader.
- The CPU starts from address `0x00000000`, so `_start` must be placed at address `0x00000000`.
- The LED peripheral is memory-mapped at `0x00002000`.
