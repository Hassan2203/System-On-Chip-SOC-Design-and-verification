
Project Title:
Design and FPGA Implementation of a Single-Cycle RV32I RISC-V SoC with Wishbone Bus and Memory-Mapped LED Pattern Controller

Purpose of this README:
This README is written as a complete code guide for the Computer Architecture CEP/Final Project. It explains what each main file does, why each design step was required, how the hardware and software parts are connected, how the firmware is converted into ROM initialization data, how the design is simulated, how the FPGA bitstream is generated, and how the final LED pattern is verified on hardware. The purpose is not only to list commands, but also to document the complete engineering flow from the first processor module to the final physical LED output.

The project is a hardware/software co-design project. On the hardware side, a custom RV32I processor is written in Verilog HDL and connected to memory and peripherals through a Wishbone bus. On the software side, a bare-metal C program is compiled for RV32I and placed inside the instruction ROM. The software does not directly control pins. Instead, it writes values to a memory-mapped LED register at address 0x00002000. The Wishbone interconnect decodes this address, selects the LED peripheral, and the LED peripheral updates the output pins. This is the same basic concept used in microcontrollers and embedded SoCs, where software controls hardware through peripheral registers.

The final visible output of the project is a walking LED pattern. The firmware repeatedly writes 0x01, 0x02, 0x04, 0x08, 0x04, and 0x02 to the LED address. These values appear on the physical FPGA LEDs after the design is synthesized, placed, routed, packed into a bitstream, and uploaded to the board. The project also contains a hardware-only blinker test. That simple design is useful because it confirms the clock, LED pins, constraints, and programming method before running the complete CPU-based SoC.

This README follows a chronological order. First it explains the project goal and code organization. Then it describes the processor core, the Wishbone bus, the memory map, the firmware flow, the simulation flow, the FPGA implementation flow, and the debugging fixes. At the end, it includes a command checklist, testing checklist, common problems, and future improvements.

-------------------------------------------------------------------------------
1. QUICK PROJECT SUMMARY
-------------------------------------------------------------------------------

This project implements a small but complete RV32I System-on-Chip. The CPU fetches instructions from a Wishbone ROM, executes them, performs load/store operations, and communicates with a memory-mapped LED peripheral. The LED peripheral is placed at address 0x00002000. Whenever the firmware executes a store word instruction to that address, the Wishbone interconnect routes the transaction to the LED slave. The LED slave stores the lower bits of the write data and drives the LED outputs.

Main technical points:
- Instruction set target: RV32I base integer RISC-V subset.
- Hardware language: Verilog HDL.
- Bus architecture: Wishbone-compatible master/slave interconnect.
- CPU role: Wishbone master.
- Slaves: program ROM, data RAM, and LED peripheral.
- LED base address: 0x00002000.
- Firmware language: bare-metal C with startup code and linker script.
- Firmware conversion: C/startup/linker -> ELF -> BIN -> HEX -> rom_init.vh.
- Simulation tools: Icarus Verilog and GTKWave.
- FPGA tools: Yosys, nextpnr-ecp5, ecppack, and openFPGALoader.
- Important hardware fixes: startup reset, register file reset, clean acknowledgement behavior, larger LED delay, separated board constraints, and hardware-only blinker test.

Important memory map:

Address range                  Purpose                         File/module
0x00000000 - 0x00000FFF        Program ROM / instruction fetch  wb_rom.v
0x00001000 - 0x00001FFF        Data RAM / load-store memory     wb_ram.v
0x00002000 - 0x00002FFF        LED peripheral / GPIO output     wb_led.v
Other addresses                Default/unmapped area            interconnect returns zero or safe response

Important modules:
- top.v / tope: top-level SoC, CPU FSM, PC, instruction register, Wishbone master logic, and slave instantiation.
- ALU.v: arithmetic, logical, shift, and comparison operations.
- ALU_control.v: converts instruction funct fields and opcode type into ALU operation codes.
- control_unit.v: generates main control signals from opcode.
- Register_file.v: implements the 32 RV32I integer registers with read and write ports.
- Immediate_Generator.v: extracts and sign-extends I, S, B, U, and J type immediates.
- wb_interconnect.v: decodes addresses and selects ROM, RAM, or LED slave.
- wb_rom.v: stores the compiled firmware instruction words.
- wb_ram.v: implements data memory.
- wb_led.v: implements the memory-mapped LED register.
- code.c: C firmware that writes LED patterns.
- startup.S: startup entry code that jumps to main.
- link.ld: linker script that places code at reset address 0x00000000.
- program.hex / rom_init.vh: generated firmware data used by the ROM.
- build_wishbone_colorlight_i5.sh: build script for FPGA flow.
- constraints_colorlight_i5.lpf: board-specific pin constraints.

-------------------------------------------------------------------------------
2. REPOSITORY AND FILE ORGANIZATION
-------------------------------------------------------------------------------

A clean project folder should separate test designs, final SoC source files, firmware files, generated build files, and board constraint files. A recommended structure is shown below. Your exact folder names may be slightly different, but the purpose of each group remains the same.

Recommended folder layout:

CA_CEP_RV32I_Wishbone_SoC/
    README.txt
    rtl/
        top.v
        ALU.v
        ALU_control.v
        control_unit.v
        Register_file.v
        Immediate_Generator.v
        wb_interconnect.v
        wb_rom.v
        wb_ram.v
        wb_led.v
    firmware/
        code.c
        startup.S
        link.ld
        program.hex
        rom_init.vh
    sim/
        tb_top.v
        sim.vvp
        waveform.vcd
    constraints/
        constraints_colorlight_i5.lpf
        constraints_ulx3s.lpf
    scripts/
        build_wishbone_colorlight_i5.sh
        build_firmware.sh
        simulate.sh
        program_fpga.sh
    hard_blinker/
        hard_blinker.v
        hard_blinker.lpf
        build_hard_blinker.sh
    build/
        cpu.json
        cpu.config
        cpu.bit

The generated files such as cpu.json, cpu.config, cpu.bit, and VCD waveforms do not normally need to be submitted in a written report unless the instructor asks for them. However, keeping them in a build folder is useful for debugging. The source files, firmware files, scripts, and constraint files are the most important parts of the project.

The hardware-only blinker should be kept separate from the final Wishbone SoC because it has a different purpose. The blinker is not the final project logic. It is a sanity test. If the blinker works, then the board clock, LED pin mapping, bitstream generation, and programming command are most likely correct. If the blinker does not work, it is not useful to debug the full CPU yet because the problem may be with pins, clock, board connection, or programming.

The final Wishbone SoC folder should contain only the files required to build the processor-based LED project. This includes the top module, CPU datapath blocks, bus interconnect, bus slaves, ROM initialization file, firmware source, linker script, startup file, and board constraints.


-------------------------------------------------------------------------------
3. COMPLETE START-TO-END DEVELOPMENT STEPS
-------------------------------------------------------------------------------

The following steps describe the complete project flow from the beginning to the final FPGA result. Each step explains the aim, the files involved, what was implemented, how it connects to the rest of the SoC, and what should be checked during debugging.


Step 1 - Define the project goal
--------------------------------

Aim:
At the beginning of the project the main goal was fixed: build a custom RISC-V based SoC and prove that C firmware running on that CPU can control physical FPGA LEDs. This goal is important because it connects three layers that are often studied separately: processor architecture, embedded software, and FPGA implementation. The goal was not only to simulate an ALU or a register file. The goal was to create a complete path from instruction fetch to physical output pin. The LED pattern was selected because it is simple, visible, and easy to verify. A processor that can fetch instructions, execute a loop, calculate addresses, and store to a memory-mapped peripheral is already demonstrating a meaningful embedded system. The LED address 0x00002000 was chosen as the peripheral base address. This value is outside the ROM and RAM ranges, so the interconnect can decode it separately. The expected final result is that the LEDs follow the pattern 0001, 0010, 0100, 1000, 0100, 0010, and repeat continuously.

Files or signals normally related to this step:

top.v, RTL source files, firmware files, constraints, scripts, simulation and build outputs

Verification notes:

After completing this step, do not immediately assume that the whole system is correct. Verify the related signals in simulation or by using a small hardware test. The safest method is to test one layer at a time. First check syntax, then check internal waveforms, then check bus transactions, then check FPGA output. A project of this type fails most often because two layers do not agree: firmware and memory map, reset and startup, ROM initialization and PC value, or constraints and physical board pins.


Step 2 - Select the instruction set and processor style
-------------------------------------------------------

Aim:
The selected instruction set was RV32I, the 32-bit base integer subset of RISC-V. RV32I is suitable for educational CPU design because it uses fixed 32-bit instructions and a clean register-based architecture. It has 32 integer registers, separate source and destination fields, and clear instruction formats such as R-type, I-type, S-type, B-type, U-type, and J-type. The processor was kept simple so that the datapath remains easy to understand. The implementation is described as a single-cycle or simple multi-state educational CPU. The final code uses a finite-state style for fetch waiting, instruction execution, and data access waiting. This is practical because Wishbone transactions use acknowledgement signals. The CPU must wait until the selected slave asserts acknowledge before it safely captures instruction or data. This design avoids pipeline hazards, forwarding, caches, privilege modes, interrupts, and branch prediction. Those features are useful in advanced CPUs, but they were not necessary for this project.

Files or signals normally related to this step:

top.v, RTL source files, firmware files, constraints, scripts, simulation and build outputs

Verification notes:

After completing this step, do not immediately assume that the whole system is correct. Verify the related signals in simulation or by using a small hardware test. The safest method is to test one layer at a time. First check syntax, then check internal waveforms, then check bus transactions, then check FPGA output. A project of this type fails most often because two layers do not agree: firmware and memory map, reset and startup, ROM initialization and PC value, or constraints and physical board pins.


Step 3 - Design the processor datapath
--------------------------------------

Aim:
The processor datapath was built around the basic stages of instruction execution. The program counter holds the address of the current instruction. The instruction register stores the 32-bit instruction fetched from ROM. The register file provides two read ports for source registers and one write port for destination register update. The immediate generator extracts constant values from the instruction according to instruction format. The ALU performs addition, subtraction, bitwise logic, shifts, comparisons, branch comparisons, and address calculation. The control unit reads the opcode and generates signals that select ALU sources, memory access behavior, write-back source, register write enable, branch behavior, and jump behavior. For store instructions, the ALU output becomes the memory or peripheral address. For branch and jump instructions, PC update logic chooses the next program counter value. This datapath is the central part of the project because every later feature, including Wishbone access and LED control, depends on correct instruction execution.

Files or signals normally related to this step:

top.v, RTL source files, firmware files, constraints, scripts, simulation and build outputs

Verification notes:

After completing this step, do not immediately assume that the whole system is correct. Verify the related signals in simulation or by using a small hardware test. The safest method is to test one layer at a time. First check syntax, then check internal waveforms, then check bus transactions, then check FPGA output. A project of this type fails most often because two layers do not agree: firmware and memory map, reset and startup, ROM initialization and PC value, or constraints and physical board pins.


Step 4 - Extract instruction fields
-----------------------------------

Aim:
After the instruction is fetched from ROM, the CPU extracts the fields using fixed RV32I bit positions. The opcode is instruction[6:0], rd is instruction[11:7], funct3 is instruction[14:12], rs1 is instruction[19:15], rs2 is instruction[24:20], and funct7 is instruction[31:25]. This field extraction is simple in Verilog because it uses direct bit slicing. These fields are passed to different blocks. The opcode goes to the control unit. The register addresses go to the register file. The function bits go to ALU control. The immediate generator uses different groups of instruction bits depending on the instruction type. Correct field extraction is essential. If even one slice is wrong, the CPU may write to the wrong register, read the wrong source value, calculate the wrong immediate, or execute the wrong ALU operation. Therefore, this step should be verified early in simulation by observing the instruction word and decoded fields in GTKWave.

Files or signals normally related to this step:

top.v, RTL source files, firmware files, constraints, scripts, simulation and build outputs

Verification notes:

After completing this step, do not immediately assume that the whole system is correct. Verify the related signals in simulation or by using a small hardware test. The safest method is to test one layer at a time. First check syntax, then check internal waveforms, then check bus transactions, then check FPGA output. A project of this type fails most often because two layers do not agree: firmware and memory map, reset and startup, ROM initialization and PC value, or constraints and physical board pins.


Step 5 - Implement the control unit
-----------------------------------

Aim:
The control unit is responsible for converting the opcode into control signals. It identifies instruction classes such as R-type arithmetic, I-type arithmetic, loads, stores, branches, JAL, JALR, LUI, and AUIPC. For R-type instructions the ALU uses two register operands and writes the ALU result back to rd. For I-type ALU instructions the second ALU input comes from the immediate. For load instructions the ALU calculates an address, memory data is read, and the load result is written back to the register file. For store instructions the ALU calculates an address and the CPU writes rs2 data to the bus. For branch instructions the CPU compares register values and changes the PC if the branch condition is true. For jump instructions the CPU writes PC+4 to rd and updates the PC to the target. The control unit is one of the most important modules because it decides the behavior of the entire datapath. When debugging the CPU, opcode and control signals should be inspected together.

Files or signals normally related to this step:

control_unit.v, opcode, Branch, MemRead, MemWrite, ALUSrc, RegWrite, MemToReg, Jump

Verification notes:

After completing this step, do not immediately assume that the whole system is correct. Verify the related signals in simulation or by using a small hardware test. The safest method is to test one layer at a time. First check syntax, then check internal waveforms, then check bus transactions, then check FPGA output. A project of this type fails most often because two layers do not agree: firmware and memory map, reset and startup, ROM initialization and PC value, or constraints and physical board pins.


Step 6 - Implement the immediate generator
------------------------------------------

Aim:
The immediate generator builds signed or unsigned immediate values from instruction bits. RV32I uses different immediate layouts for different instruction types. I-type immediates are used by loads, immediate ALU operations, and JALR. S-type immediates are used by stores. B-type immediates are used by branches and include shifted bit positions because branch targets are aligned. U-type immediates are used by LUI and AUIPC. J-type immediates are used by JAL. The immediate generator sign-extends values when required so that negative offsets work correctly. This is important for loops, branches, stack offsets, and address calculations. The LED firmware uses loops and stores, so immediate generation affects both delay loop control and LED address access. In simulation, the immediate output should be checked for store instructions and branch instructions because those are common sources of mistakes in RISC-V student projects.

Files or signals normally related to this step:

Immediate_Generator.v, I/S/B/U/J immediate formats, sign extension

Verification notes:

After completing this step, do not immediately assume that the whole system is correct. Verify the related signals in simulation or by using a small hardware test. The safest method is to test one layer at a time. First check syntax, then check internal waveforms, then check bus transactions, then check FPGA output. A project of this type fails most often because two layers do not agree: firmware and memory map, reset and startup, ROM initialization and PC value, or constraints and physical board pins.


Step 7 - Implement the register file
------------------------------------

Aim:
The RV32I register file has 32 registers, each 32 bits wide. Register x0 must always read as zero. The design includes two read ports and one write port. Two read ports are needed because most instructions read rs1 and rs2 in the same instruction. One write port is enough because each RV32I instruction writes at most one destination register. A hardware-safe reset was added so that all registers start from a known value. This is important on FPGA hardware because registers may not start as zero unless reset logic or initial values are properly supported. Even if simulation seems correct, hardware may behave incorrectly when registers start in unknown states. The fixed project resets the register file, keeps x0 zero, and writes only when register write enable is active and the destination register is not x0. In the LED firmware, register correctness affects the base address, delay counter, loop values, and store data.

Files or signals normally related to this step:

Register_file.v, rs1, rs2, rd, RegWrite, x0, reset loop

Verification notes:

After completing this step, do not immediately assume that the whole system is correct. Verify the related signals in simulation or by using a small hardware test. The safest method is to test one layer at a time. First check syntax, then check internal waveforms, then check bus transactions, then check FPGA output. A project of this type fails most often because two layers do not agree: firmware and memory map, reset and startup, ROM initialization and PC value, or constraints and physical board pins.


Step 8 - Implement ALU and ALU control
--------------------------------------

Aim:
The ALU performs the actual arithmetic and logical operations used by the CPU. It supports addition, subtraction, bitwise AND, OR, XOR, shifts, signed set-less-than, unsigned set-less-than, and comparison behavior needed for branches. The ALU control block decides which operation the ALU should perform by looking at opcode category, funct3, and funct7. For example, ADD and SUB may share the same opcode and funct3 but differ by funct7. Branch operations also depend on funct3 because BEQ, BNE, BLT, BGE, BLTU, and BGEU require different comparisons. In this project the LED firmware mainly requires address calculation, immediate arithmetic, store data preparation, and loop comparison. However, supporting more instruction behavior makes the CPU more general and allows the GCC-generated firmware to run more reliably. During simulation, ALU inputs, ALU control code, ALU result, and zero/compare outputs should be inspected together.

Files or signals normally related to this step:

ALU.v, ALU_control.v, funct3, funct7, opcode, ALU result, comparison flags

Verification notes:

After completing this step, do not immediately assume that the whole system is correct. Verify the related signals in simulation or by using a small hardware test. The safest method is to test one layer at a time. First check syntax, then check internal waveforms, then check bus transactions, then check FPGA output. A project of this type fails most often because two layers do not agree: firmware and memory map, reset and startup, ROM initialization and PC value, or constraints and physical board pins.


Step 9 - Build the processor state machine
------------------------------------------

Aim:
The top-level CPU uses a simple finite-state controller. A pure single-cycle processor would try to complete fetch, decode, execute, memory access, and write-back in one clock cycle, but Wishbone bus transactions require acknowledgement. Therefore, the submitted project uses states such as S_FETCH, S_WAIT_INSTR, S_EXECUTE, and S_WAIT_DATA. In S_FETCH, the CPU begins an instruction read transaction to ROM. In S_WAIT_INSTR, it waits until the ROM or interconnect acknowledges the instruction fetch. After the instruction is captured, the CPU moves to S_EXECUTE and performs decode, ALU calculation, branch decision, and possible write-back. If the instruction needs data memory or peripheral access, the CPU enters S_WAIT_DATA and waits for the selected slave acknowledgement. This state machine makes the design more robust because the CPU does not assume that every bus response is immediate. The state signal is a very useful waveform signal during debugging.

Files or signals normally related to this step:

top.v, state register, S_FETCH, S_WAIT_INSTR, S_EXECUTE, S_WAIT_DATA, PC update

Verification notes:

After completing this step, do not immediately assume that the whole system is correct. Verify the related signals in simulation or by using a small hardware test. The safest method is to test one layer at a time. First check syntax, then check internal waveforms, then check bus transactions, then check FPGA output. A project of this type fails most often because two layers do not agree: firmware and memory map, reset and startup, ROM initialization and PC value, or constraints and physical board pins.


Step 10 - Add load and store alignment logic
--------------------------------------------

Aim:
Load and store instructions need correct byte selection. A 32-bit Wishbone data bus can write a full word, halfword, or byte depending on instruction funct3 and address offset. Store word uses all byte select lines. Store halfword uses two selected bytes. Store byte uses one selected byte. Load instructions also need sign extension or zero extension depending on whether the instruction is LB, LH, LW, LBU, or LHU. Even if the final LED firmware uses store word to the LED register, correct load/store alignment makes the CPU more complete and allows GCC-generated programs to use memory more safely. The address lower bits determine which byte lane is being accessed. The data RAM uses byte-selectable write behavior. The LED peripheral can simply capture the lower useful bits of the write data, but the CPU must still generate a valid Wishbone transaction. Alignment mistakes can show up as wrong data in RAM or incorrect peripheral writes.

Files or signals normally related to this step:

top.v, RTL source files, firmware files, constraints, scripts, simulation and build outputs

Verification notes:

After completing this step, do not immediately assume that the whole system is correct. Verify the related signals in simulation or by using a small hardware test. The safest method is to test one layer at a time. First check syntax, then check internal waveforms, then check bus transactions, then check FPGA output. A project of this type fails most often because two layers do not agree: firmware and memory map, reset and startup, ROM initialization and PC value, or constraints and physical board pins.


Step 11 - Create the Wishbone master interface
----------------------------------------------

Aim:
The CPU acts as the only Wishbone master in this SoC. The master interface provides address, write data, write enable, byte select, cycle, strobe, and receives read data and acknowledgement. During instruction fetch, the CPU sends a read transaction to the ROM address. During store instructions, it sends a write transaction to the address calculated by the ALU. During load instructions, it sends a read transaction to the data memory or selected peripheral. The CPU must keep cycle and strobe active until acknowledgement is received. When acknowledgement arrives, the CPU can capture data, finish the transaction, and move to the next state. This handshake is important because it separates CPU speed from peripheral response timing. If acknowledgement handling is wrong, the CPU may hang forever, skip instructions, or capture invalid data. The README user should always check wb_adr, wb_dat_w, wb_dat_r, wb_we, wb_cyc, wb_stb, and wb_ack in waveforms.

Files or signals normally related to this step:

wb_interconnect.v, wb_rom.v, wb_ram.v, wb_led.v, wb_adr, wb_dat_w, wb_dat_r, wb_we, wb_sel, wb_cyc, wb_stb, wb_ack

Verification notes:

After completing this step, do not immediately assume that the whole system is correct. Verify the related signals in simulation or by using a small hardware test. The safest method is to test one layer at a time. First check syntax, then check internal waveforms, then check bus transactions, then check FPGA output. A project of this type fails most often because two layers do not agree: firmware and memory map, reset and startup, ROM initialization and PC value, or constraints and physical board pins.


Step 12 - Design the Wishbone interconnect
------------------------------------------

Aim:
The interconnect connects the CPU master to multiple slaves. It decodes the high address bits and selects one slave at a time. In this project, addresses from 0x00000000 to 0x00000FFF select program ROM. Addresses from 0x00001000 to 0x00001FFF select data RAM. Addresses from 0x00002000 to 0x00002FFF select the LED peripheral. The interconnect routes master address, write data, write enable, byte select, cycle, and strobe signals to the selected slave. It also multiplexes acknowledgement and read data from the selected slave back to the CPU. A default response is useful for unmapped addresses so the CPU does not hang forever. The memory map is the hardware/software contract of the project. The firmware only knows that writing to 0x00002000 controls LEDs. The interconnect and LED peripheral implement that behavior in hardware.

Files or signals normally related to this step:

wb_interconnect.v, wb_rom.v, wb_ram.v, wb_led.v, wb_adr, wb_dat_w, wb_dat_r, wb_we, wb_sel, wb_cyc, wb_stb, wb_ack

Verification notes:

After completing this step, do not immediately assume that the whole system is correct. Verify the related signals in simulation or by using a small hardware test. The safest method is to test one layer at a time. First check syntax, then check internal waveforms, then check bus transactions, then check FPGA output. A project of this type fails most often because two layers do not agree: firmware and memory map, reset and startup, ROM initialization and PC value, or constraints and physical board pins.


Step 13 - Implement the Wishbone ROM
------------------------------------

Aim:
The Wishbone ROM stores the program instructions. It is read-only from the CPU point of view. The ROM is initialized with the firmware words generated from the C program and startup code. In the project flow, the firmware is compiled into an ELF file, converted into a raw binary, converted into a hexadecimal word file, and then converted or included as rom_init.vh. The ROM module reads this initialization file so that the FPGA bitstream contains the program. When the processor comes out of reset, the PC starts at 0x00000000, and the first instruction is fetched from the ROM. If the ROM initialization is wrong, the CPU may execute invalid instructions or jump to the wrong address. Therefore, program.hex should be inspected after compilation. The first words should match the expected startup and firmware instructions. The ROM acknowledgement must also be clean and deterministic for hardware.

Files or signals normally related to this step:

wb_interconnect.v, wb_rom.v, wb_ram.v, wb_led.v, wb_adr, wb_dat_w, wb_dat_r, wb_we, wb_sel, wb_cyc, wb_stb, wb_ack

Verification notes:

After completing this step, do not immediately assume that the whole system is correct. Verify the related signals in simulation or by using a small hardware test. The safest method is to test one layer at a time. First check syntax, then check internal waveforms, then check bus transactions, then check FPGA output. A project of this type fails most often because two layers do not agree: firmware and memory map, reset and startup, ROM initialization and PC value, or constraints and physical board pins.


Step 14 - Implement the Wishbone RAM
------------------------------------

Aim:
The data RAM provides read and write memory for load and store instructions. It is mapped at 0x00001000 to 0x00001FFF. The RAM supports byte select lines so byte, halfword, and word operations can be handled correctly. Although the main LED demonstration can work without large data memory, the RAM is important because compiled C programs often expect memory space for variables, stack, and data operations. The linker script places RAM at the correct address so that software and hardware agree. If the linker script and hardware memory map do not match, the CPU may try to access RAM at an address that the interconnect does not decode. This can lead to hangs or wrong data. RAM waveforms should be checked with load and store tests before relying on full firmware behavior.

Files or signals normally related to this step:

wb_interconnect.v, wb_rom.v, wb_ram.v, wb_led.v, wb_adr, wb_dat_w, wb_dat_r, wb_we, wb_sel, wb_cyc, wb_stb, wb_ack

Verification notes:

After completing this step, do not immediately assume that the whole system is correct. Verify the related signals in simulation or by using a small hardware test. The safest method is to test one layer at a time. First check syntax, then check internal waveforms, then check bus transactions, then check FPGA output. A project of this type fails most often because two layers do not agree: firmware and memory map, reset and startup, ROM initialization and PC value, or constraints and physical board pins.


Step 15 - Implement the memory-mapped LED peripheral
----------------------------------------------------

Aim:
The LED peripheral is the visible output device of the SoC. It behaves like a simple Wishbone slave. When the CPU performs a valid write transaction to the LED address range, the LED module captures the write data and stores it in an LED register. The lower bits of this register are connected to FPGA output pins. The firmware writes values such as 0x01, 0x02, 0x04, and 0x08, so the physical LEDs turn on one by one. The LED peripheral may also return the current LED register value during reads, although the main firmware does not need to read it back. This module proves the complete CPU-to-peripheral path. The path is: C instruction -> compiled store instruction -> CPU decode -> ALU address calculation -> Wishbone write -> interconnect decode -> LED slave capture -> FPGA pins.

Files or signals normally related to this step:

wb_led.v, LED register, LED_ADDR 0x00002000, physical LED pins, LPF constraints

Verification notes:

After completing this step, do not immediately assume that the whole system is correct. Verify the related signals in simulation or by using a small hardware test. The safest method is to test one layer at a time. First check syntax, then check internal waveforms, then check bus transactions, then check FPGA output. A project of this type fails most often because two layers do not agree: firmware and memory map, reset and startup, ROM initialization and PC value, or constraints and physical board pins.


Step 16 - Write the C firmware
------------------------------

Aim:
The firmware is a simple bare-metal program. It defines LED_ADDR as a volatile pointer to 0x00002000. The volatile keyword is important because the address is not normal memory. It represents a hardware register. Without volatile, the compiler may optimize repeated writes because it does not know that the writes affect hardware. The firmware defines a led_write function that writes the pattern value to LED_ADDR. It also defines a delay function with a volatile loop counter. The main function runs forever and writes the sequence 0x01, 0x02, 0x04, 0x08, 0x04, and 0x02 with delay calls between writes. The delay count was increased for hardware visibility. A delay that looks clear in simulation may be too fast for human eyes on FPGA. Therefore, the final code uses a large delay count such as 2000000u.

Files or signals normally related to this step:

code.c, LED_ADDR, DELAY_COUNT, led_write(), delay(), main(), program.hex, rom_init.vh

Verification notes:

After completing this step, do not immediately assume that the whole system is correct. Verify the related signals in simulation or by using a small hardware test. The safest method is to test one layer at a time. First check syntax, then check internal waveforms, then check bus transactions, then check FPGA output. A project of this type fails most often because two layers do not agree: firmware and memory map, reset and startup, ROM initialization and PC value, or constraints and physical board pins.


Step 17 - Add startup code
--------------------------

Aim:
Bare-metal C code cannot start by itself unless the reset entry point calls main. The startup file provides the first instructions executed after reset. It sets the initial execution flow and jumps or calls main. In small bare-metal projects, startup code can be minimal because there is no operating system, no standard library, and no complex initialization. However, it is still necessary to make sure that execution begins at the correct address. The linker script places the startup section at the beginning of ROM, usually address 0x00000000. When the CPU reset logic sets PC to zero, the ROM returns the first startup instruction. Startup then transfers control to the C main function. If startup is missing or linked at the wrong address, the CPU will not run the intended firmware. This is why the firmware build process includes both startup.S and code.c.

Files or signals normally related to this step:

startup.S, reset entry, call main, infinite fallback loop, linker entry symbol

Verification notes:

After completing this step, do not immediately assume that the whole system is correct. Verify the related signals in simulation or by using a small hardware test. The safest method is to test one layer at a time. First check syntax, then check internal waveforms, then check bus transactions, then check FPGA output. A project of this type fails most often because two layers do not agree: firmware and memory map, reset and startup, ROM initialization and PC value, or constraints and physical board pins.


Step 18 - Write the linker script
---------------------------------

Aim:
The linker script is the software-side description of the memory map. It tells the compiler and linker where ROM and RAM are located. In this project ROM starts at 0x00000000 and RAM starts at 0x00001000. This must match the hardware interconnect. The reset code and text section are placed in ROM. Data, bss, and stack areas can be placed in RAM if required. For the LED demo, the most important requirement is that the first executable instruction appears at address zero and that any memory references are valid for the implemented RAM. The linker script is a common source of mistakes in soft-core CPU projects. If the linker places code at a high address but the CPU resets to zero, the CPU fetches empty or invalid data. If RAM is placed at a different address than hardware, loads and stores fail. Always review the linker memory regions.

Files or signals normally related to this step:

link.ld, ROM origin 0x00000000, RAM origin 0x00001000, text/data/bss/stack placement

Verification notes:

After completing this step, do not immediately assume that the whole system is correct. Verify the related signals in simulation or by using a small hardware test. The safest method is to test one layer at a time. First check syntax, then check internal waveforms, then check bus transactions, then check FPGA output. A project of this type fails most often because two layers do not agree: firmware and memory map, reset and startup, ROM initialization and PC value, or constraints and physical board pins.


Step 19 - Compile firmware and generate ROM initialization
----------------------------------------------------------

Aim:
The firmware build converts human-written C code into instruction words that the custom CPU can execute. A typical flow uses riscv64-unknown-elf-gcc or another RISC-V GCC cross compiler with options for RV32I and ILP32 ABI. The compile command should avoid operating system features by using options such as -nostdlib and -nostartfiles when appropriate. After linking, objcopy converts the ELF file into a raw binary. The binary is then converted into 32-bit hexadecimal instruction words. These words become program.hex and are included or converted into rom_init.vh. The ROM module uses that file during simulation and synthesis. This step connects software to hardware. Any time the C program is changed, the firmware must be rebuilt and the ROM initialization file must be updated before simulation or FPGA build.

Files or signals normally related to this step:

code.c, LED_ADDR, DELAY_COUNT, led_write(), delay(), main(), program.hex, rom_init.vh

Verification notes:

After completing this step, do not immediately assume that the whole system is correct. Verify the related signals in simulation or by using a small hardware test. The safest method is to test one layer at a time. First check syntax, then check internal waveforms, then check bus transactions, then check FPGA output. A project of this type fails most often because two layers do not agree: firmware and memory map, reset and startup, ROM initialization and PC value, or constraints and physical board pins.


Step 20 - Verify firmware contents
----------------------------------

Aim:
After generating program.hex, the first words should be checked before running the full SoC. This catches build errors early. The hex file should contain 32-bit instruction words, one per line, in the order expected by the ROM. The reset address should correspond to the first instruction. If the LED address is loaded using LUI and ADDI or similar instructions, the disassembly should show that 0x00002000 is being formed correctly. The store instructions should write the pattern values to that address. It is also useful to generate a disassembly file using objdump. The disassembly lets the designer compare C statements with actual RV32I instructions. If the compiler emits an instruction that the CPU does not support, the firmware will fail. Therefore, the compile flags must match the implemented instruction subset.

Files or signals normally related to this step:

code.c, LED_ADDR, DELAY_COUNT, led_write(), delay(), main(), program.hex, rom_init.vh

Verification notes:

After completing this step, do not immediately assume that the whole system is correct. Verify the related signals in simulation or by using a small hardware test. The safest method is to test one layer at a time. First check syntax, then check internal waveforms, then check bus transactions, then check FPGA output. A project of this type fails most often because two layers do not agree: firmware and memory map, reset and startup, ROM initialization and PC value, or constraints and physical board pins.


Step 21 - Create the simulation testbench
-----------------------------------------

Aim:
Before programming the FPGA, the SoC must be simulated. The testbench creates a clock, applies reset, instantiates the top-level SoC, and dumps waveforms to a VCD file. It should run long enough for the CPU to fetch several instructions, enter the firmware loop, and write LED values. Important signals to dump include clk, reset, cpu_reset, state, pc, instruction, opcode, ALU inputs, ALU result, register write-back, Wishbone address, write data, read data, write enable, cycle, strobe, acknowledge, slave select signals, and LED output. A good testbench does not only check final LED values. It allows internal behavior to be inspected. If the LED output is wrong, the waveform helps determine whether the problem is in instruction fetch, decode, ALU address calculation, bus handshake, interconnect decode, or LED register update.

Files or signals normally related to this step:

tb_top.v, Icarus Verilog, vvp, waveform.vcd, GTKWave signal list

Verification notes:

After completing this step, do not immediately assume that the whole system is correct. Verify the related signals in simulation or by using a small hardware test. The safest method is to test one layer at a time. First check syntax, then check internal waveforms, then check bus transactions, then check FPGA output. A project of this type fails most often because two layers do not agree: firmware and memory map, reset and startup, ROM initialization and PC value, or constraints and physical board pins.


Step 22 - Compile and run simulation
------------------------------------

Aim:
The simulation can be compiled using Icarus Verilog. A typical command uses iverilog with SystemVerilog or Verilog-2005 support depending on the code style. The top-level testbench is selected with -s if required. All RTL files must be included in the correct order or through a file list. After compilation, vvp runs the simulation and produces a VCD waveform file. The console output should show that simulation completed without syntax errors or runtime fatal errors. If the ROM initialization file is missing, simulation may fail or the ROM may contain zeros. If the testbench does not run long enough, the LED pattern may not appear. For fast simulation, the firmware delay can temporarily be reduced, but for hardware it must be increased again. This difference between simulation delay and hardware delay must be handled carefully.

Files or signals normally related to this step:

tb_top.v, Icarus Verilog, vvp, waveform.vcd, GTKWave signal list

Verification notes:

After completing this step, do not immediately assume that the whole system is correct. Verify the related signals in simulation or by using a small hardware test. The safest method is to test one layer at a time. First check syntax, then check internal waveforms, then check bus transactions, then check FPGA output. A project of this type fails most often because two layers do not agree: firmware and memory map, reset and startup, ROM initialization and PC value, or constraints and physical board pins.


Step 23 - Inspect waveforms in GTKWave
--------------------------------------

Aim:
GTKWave is used to visually verify internal signals. First inspect reset and PC behavior. The PC should start from 0x00000000 after reset. Then inspect instruction fetch. The Wishbone address should point to ROM and acknowledgement should return. Then inspect instruction decode and state transitions. For store instructions, the ALU result should become 0x00002000 and the Wishbone write data should contain the LED pattern. The interconnect should select the LED slave and the LED register should update after acknowledgement. The LED output should show values such as 0x01, 0x02, 0x04, and 0x08. If the PC stops changing, check acknowledgement. If the LED address is wrong, check immediate generation and ALU source selection. If the LED register does not update even though the write occurs, check address decode and LED write-enable logic.

Files or signals normally related to this step:

tb_top.v, Icarus Verilog, vvp, waveform.vcd, GTKWave signal list

Verification notes:

After completing this step, do not immediately assume that the whole system is correct. Verify the related signals in simulation or by using a small hardware test. The safest method is to test one layer at a time. First check syntax, then check internal waveforms, then check bus transactions, then check FPGA output. A project of this type fails most often because two layers do not agree: firmware and memory map, reset and startup, ROM initialization and PC value, or constraints and physical board pins.


Step 24 - Run the hardware-only blinker test
--------------------------------------------

Aim:
Before loading the full SoC, run a hardware-only blinker. This design does not use the CPU, ROM, RAM, firmware, or Wishbone bus. It only uses a counter connected to LED outputs. The purpose is to verify that the board clock is correct, the LPF pin mapping is correct, the LEDs are connected correctly, and the programming tool can load a bitstream. If this simple blinker does not work, the problem is almost certainly not in the CPU. It could be a wrong clock pin, wrong LED pin, wrong active-high or active-low LED polarity, wrong board package, wrong programmer cable, or wrong bitstream command. Once the hardware-only blinker works, the designer has confidence that the board-level path is correct. Then it becomes meaningful to debug the full Wishbone SoC.

Files or signals normally related to this step:

link.ld, ROM origin 0x00000000, RAM origin 0x00001000, text/data/bss/stack placement

Verification notes:

After completing this step, do not immediately assume that the whole system is correct. Verify the related signals in simulation or by using a small hardware test. The safest method is to test one layer at a time. First check syntax, then check internal waveforms, then check bus transactions, then check FPGA output. A project of this type fails most often because two layers do not agree: firmware and memory map, reset and startup, ROM initialization and PC value, or constraints and physical board pins.


Step 25 - Prepare board constraints
-----------------------------------

Aim:
The LPF constraint file maps Verilog ports to physical FPGA pins. This file is board-specific and must match the exact FPGA board schematic. For the Colorlight i5 flow, constraints_colorlight_i5.lpf maps the clock, reset, and LED pins. If another board such as ULX3S or iCESugar is used, a different LPF file must be used. Constraint files should not be mixed because the same Verilog port may connect to different physical pins on different boards. LED polarity must also be checked. Some board LEDs are active-low, meaning the FPGA pin must drive 0 to turn the LED on. Others are active-high, meaning the pin must drive 1. If all LEDs look inverted or stuck, polarity may be the issue. Constraint problems can make a correct CPU appear broken, so pin mapping should be verified early.

Files or signals normally related to this step:

top.v, RTL source files, firmware files, constraints, scripts, simulation and build outputs

Verification notes:

After completing this step, do not immediately assume that the whole system is correct. Verify the related signals in simulation or by using a small hardware test. The safest method is to test one layer at a time. First check syntax, then check internal waveforms, then check bus transactions, then check FPGA output. A project of this type fails most often because two layers do not agree: firmware and memory map, reset and startup, ROM initialization and PC value, or constraints and physical board pins.


Step 26 - Synthesize with Yosys
-------------------------------

Aim:
Yosys converts the Verilog RTL into a gate-level netlist suitable for the target FPGA. For Lattice ECP5 boards, the synth_ecp5 command is used. The top module name must match the actual top-level Verilog module, such as tope or another wrapper. The output is usually a JSON netlist such as cpu.json. During synthesis, Yosys reports warnings, inferred memories, registers, LUT usage, and possible unused signals. Warnings should be reviewed. Some warnings are harmless, but warnings about undriven nets, multiple drivers, latches, or missing modules can indicate serious design errors. If the ROM initialization include file is missing, synthesis may still run but the ROM contents may be wrong. Synthesis is the first FPGA build step after simulation. It checks that the design can be translated into hardware logic.

Files or signals normally related to this step:

Yosys, synth_ecp5, cpu.json, top module name, RTL file list

Verification notes:

After completing this step, do not immediately assume that the whole system is correct. Verify the related signals in simulation or by using a small hardware test. The safest method is to test one layer at a time. First check syntax, then check internal waveforms, then check bus transactions, then check FPGA output. A project of this type fails most often because two layers do not agree: firmware and memory map, reset and startup, ROM initialization and PC value, or constraints and physical board pins.


Step 27 - Place and route with nextpnr-ecp5
-------------------------------------------

Aim:
After synthesis, nextpnr-ecp5 maps the netlist onto the physical resources of the FPGA. It uses the JSON netlist and the LPF constraint file. The board package, device size, and speed grade must match the target FPGA. nextpnr assigns LUTs, flip-flops, block RAMs, and I/O pins to actual locations and routes connections between them. It also performs timing analysis. The requested clock frequency should be realistic for the design. If timing fails, the design may not run reliably at the desired clock speed. The output of nextpnr is a routed configuration file such as cpu.config. If nextpnr fails because of an invalid pin, the LPF constraints must be checked. If it fails because of resource limits, the design may be too large for the selected FPGA or memory usage may need to be reduced.

Files or signals normally related to this step:

nextpnr-ecp5, cpu.json, constraints_colorlight_i5.lpf, cpu.config, timing report

Verification notes:

After completing this step, do not immediately assume that the whole system is correct. Verify the related signals in simulation or by using a small hardware test. The safest method is to test one layer at a time. First check syntax, then check internal waveforms, then check bus transactions, then check FPGA output. A project of this type fails most often because two layers do not agree: firmware and memory map, reset and startup, ROM initialization and PC value, or constraints and physical board pins.


Step 28 - Pack the bitstream with ecppack
-----------------------------------------

Aim:
ecppack converts the nextpnr routed configuration into a bitstream file that can be loaded onto the FPGA. The output file is commonly named cpu.bit. This file is the final hardware configuration image. It contains the synthesized CPU, Wishbone interconnect, ROM contents, RAM structure, LED peripheral, reset logic, and pin mappings. If firmware changes, the bitstream must be regenerated because the ROM contents are part of the FPGA configuration. It is a common mistake to rebuild firmware but forget to rerun synthesis and packing, which means the board still runs the old program. Always check the timestamp of cpu.bit after rebuilding. If the bitstream was not updated, programming the FPGA will not show the new LED pattern.

Files or signals normally related to this step:

ecppack, cpu.config, cpu.bit, bitstream timestamp

Verification notes:

After completing this step, do not immediately assume that the whole system is correct. Verify the related signals in simulation or by using a small hardware test. The safest method is to test one layer at a time. First check syntax, then check internal waveforms, then check bus transactions, then check FPGA output. A project of this type fails most often because two layers do not agree: firmware and memory map, reset and startup, ROM initialization and PC value, or constraints and physical board pins.


Step 29 - Program the FPGA with openFPGALoader
----------------------------------------------

Aim:
openFPGALoader is used to upload the bitstream to the FPGA board through the selected programmer interface. The exact command depends on the board and cable. For a CMSIS-DAP based setup, the command may include a cable option such as -c cmsisdap followed by cpu.bit. During programming, the tool should detect the FPGA and show successful upload progress. If the FPGA is not detected, check USB attachment, board power, programmer driver, cable connection, and command options. If upload succeeds but LEDs do not behave as expected, check whether the correct bitstream was programmed, whether the correct constraints were used, and whether the hardware-only blinker works. Programming is the step where all previous work becomes a real hardware test.

Files or signals normally related to this step:

wb_ram.v, byte select lines, load/store data, RAM acknowledgement

Verification notes:

After completing this step, do not immediately assume that the whole system is correct. Verify the related signals in simulation or by using a small hardware test. The safest method is to test one layer at a time. First check syntax, then check internal waveforms, then check bus transactions, then check FPGA output. A project of this type fails most often because two layers do not agree: firmware and memory map, reset and startup, ROM initialization and PC value, or constraints and physical board pins.


Step 30 - Observe final LED output
----------------------------------

Aim:
The final hardware result should be a visible LED sequence controlled by firmware running on the custom CPU. The expected order is one LED pattern at a time: 0x01, then 0x02, then 0x04, then 0x08, then 0x04, then 0x02, repeating forever. If the LEDs blink too fast, increase DELAY_COUNT in code.c, rebuild firmware, regenerate ROM initialization, rebuild the bitstream, and program again. If all LEDs turn on together, check LED polarity, LED assignment, firmware program.hex, and whether the old bitstream is still being used. If only one LED remains on, check whether the firmware got stuck after one write, whether PC stopped changing, or whether the branch loop is wrong. A final report should include a photograph or video frame of the physical LEDs plus terminal screenshots of successful build and programming.

Files or signals normally related to this step:

wb_led.v, LED register, LED_ADDR 0x00002000, physical LED pins, LPF constraints

Verification notes:

After completing this step, do not immediately assume that the whole system is correct. Verify the related signals in simulation or by using a small hardware test. The safest method is to test one layer at a time. First check syntax, then check internal waveforms, then check bus transactions, then check FPGA output. A project of this type fails most often because two layers do not agree: firmware and memory map, reset and startup, ROM initialization and PC value, or constraints and physical board pins.


Step 31 - Apply debugging fixes
-------------------------------

Aim:
The project required several important hardware fixes. The startup reset fix keeps the CPU reset for a short time after FPGA configuration so internal registers start in a known state. The register file reset fix clears all registers, avoiding unknown startup values. The acknowledgement handling fix makes ROM, RAM, and LED responses cleaner and avoids CPU stalls or invalid captures. The delay loop fix increases the firmware delay so LEDs are visible to the human eye. The constraint separation fix prevents the wrong board pins from being used. The hardware-only blinker fix provides a simple first test before running the CPU. These fixes are important because simulation can hide hardware problems. FPGA hardware needs correct reset, correct pin constraints, correct timing, and reliable bus behavior.

Files or signals normally related to this step:

top.v, RTL source files, firmware files, constraints, scripts, simulation and build outputs

Verification notes:

After completing this step, do not immediately assume that the whole system is correct. Verify the related signals in simulation or by using a small hardware test. The safest method is to test one layer at a time. First check syntax, then check internal waveforms, then check bus transactions, then check FPGA output. A project of this type fails most often because two layers do not agree: firmware and memory map, reset and startup, ROM initialization and PC value, or constraints and physical board pins.


Step 32 - Document final results and limitations
------------------------------------------------

Aim:
After successful testing, the final result should be documented. The documentation should include the project goal, block diagram, memory map, module list, firmware code, build commands, simulation screenshots, waveforms, synthesis output, nextpnr output, ecppack output, programming log, and physical LED evidence. The limitations should also be stated clearly. The design is not pipelined. It does not include caches, interrupts, privilege modes, exceptions, compressed instructions, multiplication, division, or a UART console. These limitations are acceptable because the goal is to demonstrate a complete CPU-to-peripheral SoC flow, not to build a production microcontroller. Future improvements can add UART, timer, more GPIO, self-checking testbenches, formal Wishbone checks, instruction-level tests, or a pipelined datapath.

Files or signals normally related to this step:

top.v, RTL source files, firmware files, constraints, scripts, simulation and build outputs

Verification notes:

After completing this step, do not immediately assume that the whole system is correct. Verify the related signals in simulation or by using a small hardware test. The safest method is to test one layer at a time. First check syntax, then check internal waveforms, then check bus transactions, then check FPGA output. A project of this type fails most often because two layers do not agree: firmware and memory map, reset and startup, ROM initialization and PC value, or constraints and physical board pins.


-------------------------------------------------------------------------------
4. IMPORTANT CODE SNIPPETS AND COMMANDS
-------------------------------------------------------------------------------

4.1 Firmware LED address

The firmware controls LEDs through a memory-mapped pointer:

#define LED_ADDR ((volatile unsigned int *)0x00002000)

The volatile keyword is required because this address is a hardware register. The compiler must not remove or merge writes to this address.

4.2 Firmware LED loop

A simplified version of the LED firmware is:

#define LED_ADDR ((volatile unsigned int *)0x00002000)
#define DELAY_COUNT 2000000u

static void led_write(unsigned int pattern)
{
    *LED_ADDR = pattern;
}

static void delay(void)
{
    volatile unsigned int i;
    for (i = 0; i < DELAY_COUNT; i++) {
    }
}

void main(void)
{
    while (1) {
        led_write(0x01);
        delay();
        led_write(0x02);
        delay();
        led_write(0x04);
        delay();
        led_write(0x08);
        delay();
        led_write(0x04);
        delay();
        led_write(0x02);
        delay();
    }
}

4.3 Typical firmware build commands

Use the exact toolchain path available on your machine. These are representative commands:

riscv64-unknown-elf-gcc -march=rv32i -mabi=ilp32 -nostdlib -nostartfiles -T link.ld startup.S code.c -o firmware.elf
riscv64-unknown-elf-objdump -d firmware.elf > firmware.dump
riscv64-unknown-elf-objcopy -O binary firmware.elf firmware.bin
hexdump -v -e '1/4 "%08x\n"' firmware.bin > program.hex

Important note: depending on the conversion command, endianness may need to be handled carefully. If the CPU fetches wrong instructions, inspect firmware.dump and program.hex together. A build script is safer because it repeats the same tested conversion every time.

4.4 Typical simulation commands

iverilog -g2012 -o sim.vvp tb_top.v top.v ALU.v ALU_control.v control_unit.v Register_file.v Immediate_Generator.v wb_interconnect.v wb_rom.v wb_ram.v wb_led.v
vvp sim.vvp
gtkwave waveform.vcd

If your project uses a file list, the command may look like this:

iverilog -g2012 -s tb_top -f rtl_files.f -o sim.vvp
vvp sim.vvp
gtkwave waveform.vcd

4.5 Typical Yosys command

yosys -p "read_verilog top.v ALU.v ALU_control.v control_unit.v Register_file.v Immediate_Generator.v wb_interconnect.v wb_rom.v wb_ram.v wb_led.v; synth_ecp5 -top tope -json cpu.json"

If your build script already contains this command, run the script instead:

chmod +x build_wishbone_colorlight_i5.sh
./build_wishbone_colorlight_i5.sh

4.6 Typical nextpnr-ecp5 command

nextpnr-ecp5 --45k --package CABGA381 --json cpu.json --lpf constraints_colorlight_i5.lpf --textcfg cpu.config

Use the correct device and package for your board. If the board uses a 25K ECP5 device, do not use 45k options. If the package differs, update the package option.

4.7 Typical ecppack command

ecppack cpu.config cpu.bit

4.8 Typical programming command

openFPGALoader -c cmsisdap cpu.bit

The cable option depends on your programmer. Some boards use FTDI, CMSIS-DAP, or another interface. The programming log should show that the FPGA is detected and that upload reaches 100 percent.

-------------------------------------------------------------------------------
5. TESTING CHECKLIST
-------------------------------------------------------------------------------

Use this checklist before final submission:

[ ] The Verilog files compile without syntax errors.
[ ] The firmware compiles for RV32I with the correct ABI.
[ ] program.hex is regenerated after changing code.c.
[ ] rom_init.vh is regenerated or updated after changing program.hex.
[ ] The ROM module includes the correct initialization file.
[ ] The PC starts at 0x00000000 after reset.
[ ] The first instruction fetched in simulation matches the first word of program.hex.
[ ] The Wishbone ROM acknowledges instruction fetch.
[ ] The CPU state machine moves through fetch, wait, execute, and data wait states.
[ ] Store instructions generate address 0x00002000 for LED writes.
[ ] The interconnect selects the LED slave for 0x00002000.
[ ] The LED peripheral captures write data 0x01, 0x02, 0x04, and 0x08.
[ ] GTKWave shows LED output changing in the expected order.
[ ] The hardware-only blinker works on the target board.
[ ] The LPF file matches the correct board and physical pins.
[ ] Yosys creates cpu.json.
[ ] nextpnr creates cpu.config and reports acceptable timing.
[ ] ecppack creates cpu.bit.
[ ] openFPGALoader detects and programs the FPGA.
[ ] The physical LED pattern is visible.
[ ] Final screenshots and photographs are saved for the report.

-------------------------------------------------------------------------------
6. COMMON PROBLEMS AND FIXES
-------------------------------------------------------------------------------

Problem: Simulation works but hardware LEDs do not blink.
Possible causes: wrong LPF pins, wrong LED polarity, old bitstream programmed, missing reset, delay too small, or wrong programmer command. First run the hardware-only blinker. If the blinker fails, debug board constraints and programming before debugging the CPU.

Problem: Only one LED stays on.
Possible causes: firmware got stuck after the first store, branch loop is wrong, PC stopped due to missing acknowledgement, or program.hex contains an old program. Check PC, state, wb_ack, and program.hex timestamp.

Problem: All LEDs blink together.
Possible causes: LED pins are mapped incorrectly, LED bus bits are tied together, active-low polarity is wrong, or the LED register is being assigned the wrong bits. Check top-level LED assignments and physical resistor connections.

Problem: CPU does not leave reset.
Possible causes: startup reset counter never finishes, external reset is stuck, reset polarity is wrong, or cpu_reset is connected incorrectly. Inspect reset and state signals in simulation.

Problem: CPU hangs during instruction fetch.
Possible causes: ROM acknowledgement is not asserted, interconnect does not select ROM, PC address is outside the ROM range, or ROM initialization failed. Check wb_adr, ROM select, ROM ack, and instruction value.

Problem: CPU hangs during store instruction.
Possible causes: the selected slave does not acknowledge, address decode is wrong, or LED/RAM acknowledgement logic is missing. Check ALU result, wb_adr, slave select, wb_we, wb_cyc, wb_stb, and wb_ack.

Problem: C firmware uses unsupported instructions.
Possible causes: wrong GCC options or compiler emitting instructions outside RV32I. Use -march=rv32i -mabi=ilp32 and inspect firmware.dump. Avoid library calls unless your runtime supports them.

Problem: New C code does not appear on FPGA.
Possible causes: firmware was rebuilt but bitstream was not regenerated, or old bitstream was programmed. Rebuild firmware, regenerate ROM include, rerun Yosys, rerun nextpnr, rerun ecppack, and program the new cpu.bit.

-------------------------------------------------------------------------------
7. EXPECTED FINAL RESULT
-------------------------------------------------------------------------------

After all steps are completed, the project should behave as follows:

1. The FPGA is programmed with cpu.bit.
2. The startup reset holds the CPU briefly after configuration.
3. The CPU PC begins at 0x00000000.
4. The CPU fetches the startup instruction from ROM.
5. Startup code transfers control to main.
6. The firmware calculates or loads the LED peripheral address 0x00002000.
7. The firmware writes pattern 0x01 to the LED address.
8. The CPU performs a Wishbone write transaction.
9. The interconnect decodes 0x00002000 and selects wb_led.v.
10. The LED slave captures the value and updates the LED register.
11. The physical LED output shows the first pattern.
12. The delay loop runs long enough for human visibility.
13. The process repeats for 0x02, 0x04, 0x08, 0x04, and 0x02.
14. The pattern repeats forever.

This result proves that the processor, control unit, ALU, register file, immediate generator, Wishbone master, interconnect, ROM, LED peripheral, firmware, linker script, ROM initialization flow, FPGA build flow, constraints, and programming flow all work together.

-------------------------------------------------------------------------------
8. FUTURE IMPROVEMENTS
-------------------------------------------------------------------------------

The next version of this project can add more useful peripherals. A UART transmitter mapped at address 0x00003000 would be very helpful because firmware could print characters during hardware debugging. A timer peripheral could replace the busy-wait delay loop and create accurate delays. GPIO input pins could be added to read buttons or switches. A seven-segment display controller could show values calculated by the CPU. A self-checking testbench could automatically verify CPU behavior instead of relying only on manual waveform inspection. Formal checks could be added for Wishbone handshake correctness. The CPU could also be extended with a pipeline, interrupt support, exception handling, multiplication and division, or compressed instruction support.

The most practical immediate improvement is a UART peripheral plus a timer. With LEDs, UART, and timer, the SoC would become a stronger embedded platform for future Computer Architecture and FPGA projects.

-------------------------------------------------------------------------------
9. FINAL SUBMISSION NOTES
-------------------------------------------------------------------------------

For final submission, include the source code, firmware files, build scripts, constraint file, README, final report, simulation screenshots, GTKWave screenshots, build terminal screenshots, programming log, and hardware LED photograph. Do not submit unnecessary generated files unless required. Very large VCD files, intermediate JSON/config files, and temporary synthesis directories can make the ZIP too large. Keep the submission clean and organized.

The README should remain in the root of the project folder so that anyone opening the code can understand how the project was built and tested from start to end.


-------------------------------------------------------------------------------
10. EXTENDED TECHNICAL NOTES BASED ON THE PROJECT REPORT
-------------------------------------------------------------------------------

The following extended notes summarize the report narrative in README form. They are included so that this text file can also serve as a long-form documentation file for the code folder. The report explains that the project implements a custom RISC-V processor in Verilog HDL and integrates it with instruction memory, data memory, an address decoder, a Wishbone interconnect, and a memory-mapped LED peripheral. It also explains that the LED peripheral is mapped at address 0x00002000, allowing bare-metal firmware running on the processor to control FPGA LED outputs through ordinary store instructions. The project uses a complete hardware/software co-design flow. On the software side, a C firmware program writes a repeated LED pattern to the memory-mapped address. On the hardware side, the CPU fetches from the Wishbone ROM, executes arithmetic, branch, load/store, and jump operations, and performs Wishbone transactions to memory and the LED slave.

The report also documents practical hardware fixes. These include a hardware-safe startup reset, corrected reset propagation, reset handling in the register file, cleaner acknowledgement behavior in ROM/RAM/LED blocks, a larger firmware delay loop for visible FPGA blinking, separated LPF constraint files for supported boards, and a hardware-only blinker test. These details are important because a design that looks correct in simulation can fail on the real FPGA if reset, timing, constraints, or acknowledgement behavior is not hardware-safe.

The motivation of the project is that computer architecture becomes clearer when the processor is implemented and tested instead of only drawn as a diagram. In this project, the relationship between the program counter, instruction fields, control signals, ALU operations, memory access, and write-back path remains visible. The Wishbone bus adds a system-level layer. Instead of connecting the CPU directly to one LED register, the design uses address decoding and a bus interface, which is closer to real embedded systems.

The scope includes implementation of a custom RV32I core, integration of ROM/RAM/LED through Wishbone, development of bare-metal firmware, conversion of firmware to program.hex and rom_init.vh, simulation and waveform inspection, FPGA synthesis, place-and-route, bitstream generation, programming, and hardware debugging. The main contribution is an end-to-end flow from Verilog CPU design to visible LED output on FPGA hardware.

The problem solved by the project is the gap between isolated computer architecture components and a complete working SoC. Students often design ALUs, registers, decoders, or memories separately, but this project connects them into a processor-driven system where software controls physical I/O. The design problem requires correct reset address, correct RV32I compilation, correct instruction memory initialization, correct Wishbone address decoding, correct acknowledgement routing, correct LED register behavior, and a design that survives FPGA synthesis and startup behavior.

The design requirements include instruction execution, memory map separation, LED control at 0x00002000, ROM initialization from firmware words, ECP5 FPGA build, and board pin constraints. The expected deliverables include Verilog RTL, compiled firmware image, simulation waveform evidence, synthesizable FPGA project, bitstream generation evidence, and physical LED output evidence.

The system architecture contains one CPU master and three main slaves. Program ROM is read-only and stores instructions. Data RAM is read/write and supports load/store operations. The LED peripheral is a simple memory-mapped output register. The interconnect selects the slave using the address region. Instruction fetch transactions select ROM. Load/store transactions select RAM or LED depending on the computed address.

The CPU extracts instruction fields using fixed RV32I bit positions. The control unit decodes opcode. The immediate generator handles I, S, B, U, and J formats. The register file supports two reads and one write. The ALU executes arithmetic, logic, shift, compare, and address calculation. Branch and jump logic update the PC. Load/store alignment logic prepares byte select and sign extension behavior. A finite-state controller handles fetch, wait for instruction, execute, and wait for data.

The Wishbone interconnect uses address decoding. The ROM region starts at 0x00000000. The RAM region starts at 0x00001000. The LED region starts at 0x00002000. The linker script must match these addresses so the software layout agrees with the hardware map. The firmware defines the LED address as a volatile pointer and writes values to it. The C code is compiled for RV32I, linked at reset address 0x00000000, converted to binary and hex, and included in the ROM.

Simulation verifies that the PC begins correctly, instructions are fetched, the state machine progresses, the ALU generates correct results, Wishbone transactions are formed, acknowledgement is received, and LED values change. GTKWave is used to inspect PC, instruction, address, write data, read data, acknowledgement, and LED output. FPGA implementation then uses Yosys for synthesis, nextpnr-ecp5 for place-and-route, ecppack for bitstream generation, and openFPGALoader for programming.

The final functional result is a processor-controlled LED sequence. The CPU fetches firmware instructions from ROM, executes the delay loop and store instructions, writes to 0x00002000, and the LED peripheral drives the physical FPGA LEDs. The design remains intentionally simple and does not include pipelining, interrupts, caches, privilege modes, exceptions, compressed instructions, multiplication/division, or UART. These limitations are acceptable because the objective is to demonstrate a complete CPU-to-peripheral path.
