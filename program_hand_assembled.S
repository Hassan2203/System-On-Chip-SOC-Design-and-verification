# Hand-assembled RV32I firmware used to generate program.hex.
# LED register: 0x00002000
# Pattern: 1 -> 2 -> 4 -> 8 -> repeat

    lui  x5, 0x2          # x5 = 0x00002000
    addi x6, x0, 1        # x6 = LED pattern
loop_pattern:
    sw   x6, 0(x5)        # write LEDs
    lui  x7, 0x200        # x7 = delay count 0x00200000
delay:
    addi x7, x7, -1
    bne  x7, x0, delay
    slli x6, x6, 1
    sltiu x8, x6, 16
    bne  x8, x0, loop_pattern
    addi x6, x0, 1
    jal  x0, loop_pattern
