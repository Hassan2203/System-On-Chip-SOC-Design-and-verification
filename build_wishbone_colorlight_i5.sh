#!/usr/bin/env bash
set -euo pipefail

yosys -p "read_verilog ALU.v ALU_control.v control_unit.v Immediate_Generator.v Register_file.v wb_interconnect.v wb_rom.v wb_ram.v wb_led.v top.v; synth_ecp5 -top tope -json cpu.json"

nextpnr-ecp5 --45k --package CABGA381 \
  --json cpu.json \
  --lpf constraints_colorlight_i5.lpf \
  --textcfg cpu.config

ecppack --idcode 0x41112043 cpu.config cpu.bit

ls -lh cpu.bit

echo "Generated Colorlight i5 bitstream: cpu.bit"
echo "Program command:"
echo "sudo ~/fpga/openFPGALoader/build/openFPGALoader -c cmsisdap cpu.bit"
