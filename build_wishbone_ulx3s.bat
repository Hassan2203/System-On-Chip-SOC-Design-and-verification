@echo off
yosys -p "read_verilog ALU.v ALU_control.v control_unit.v Immediate_Generator.v Register_file.v wb_interconnect.v wb_rom.v wb_ram.v wb_led.v top.v; synth_ecp5 -top tope -json cpu.json"
nextpnr-ecp5 --45k --package CABGA381 --json cpu.json --lpf constraints_ulx3s_onboard.lpf --textcfg cpu.config
ecppack cpu.config cpu.bit
echo Generated cpu.bit
echo To program temporarily over JTAG: openFPGALoader -b ulx3s cpu.bit
echo To flash permanently:          openFPGALoader -b ulx3s -f cpu.bit
