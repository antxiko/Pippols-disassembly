#!/bin/sh
# dis.sh <ini_hex> <fin_hex>  - desensambla un rango de la ROM (org 0x4000)
ROM=pippols.rom
INI=$(printf "%d" $1)
FIN=$(printf "%d" $2)
OFF=$((INI - 16384))
LEN=$((FIN - INI))
dd if=$ROM of=work/_dis.bin bs=1 skip=$OFF count=$LEN 2>/dev/null
TMP=work TEMP=work z80dasm -a -t -g $1 work/_dis.bin
