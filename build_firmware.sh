#!/usr/bin/env bash
set -euo pipefail

riscv64-unknown-elf-gcc \
  -march=rv32i \
  -mabi=ilp32 \
  -nostdlib \
  -nostartfiles \
  -ffreestanding \
  -fno-pic \
  -mcmodel=medlow \
  -O2 \
  -T link.ld \
  startup.s code.c \
  -o program.elf

riscv64-unknown-elf-objdump -d program.elf > firmware.dump

riscv64-unknown-elf-objcopy -O binary program.elf program.bin

python3 - <<'PY'
from pathlib import Path

data = Path("program.bin").read_bytes()

# pad to multiple of 4 bytes
if len(data) % 4 != 0:
    data += b"\x00" * (4 - (len(data) % 4))

words = []
for i in range(0, len(data), 4):
    b = data[i:i+4]
    word = int.from_bytes(b, byteorder="little")
    words.append(f"{word:08x}")

Path("program.hex").write_text("\n".join(words) + "\n")
print("Generated program.hex")
print("Total words:", len(words))
PY

./make_rom_init.sh

echo "===== program.hex first 40 lines ====="
head -n 40 program.hex

echo "===== firmware.dump first 80 lines ====="
head -n 80 firmware.dump
