#!/usr/bin/env bash
set -euo pipefail

if [ ! -f program.hex ]; then
    echo "ERROR: program.hex not found"
    exit 1
fi

rm -f rom_init.vh

i=0
while read -r word; do
    # skip empty lines
    [ -z "$word" ] && continue

    echo "        rom[$i] = 32'h$word;" >> rom_init.vh
    i=$((i + 1))
done < program.hex

echo "Generated rom_init.vh from program.hex"
echo "Total ROM words: $i"
