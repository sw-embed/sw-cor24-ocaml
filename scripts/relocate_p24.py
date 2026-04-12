#!/usr/bin/env python3
"""Relocate a .p24 binary for loading at a given address.

Copied from sw-cor24-pascal/scripts/relocate_p24.py.
Rewrites absolute data-section references in p-code instructions
to account for a non-zero load address.
"""
import sys, struct
data = open(sys.argv[1], 'rb').read()
load_addr = int(sys.argv[2], 0) if len(sys.argv) > 2 else 0x010000
magic, ver = data[:4], data[4]
entry = int.from_bytes(data[5:8], 'little')
code_size = int.from_bytes(data[8:11], 'little')
data_size = int.from_bytes(data[11:14], 'little')
global_count = int.from_bytes(data[14:17], 'little')
body = bytearray(data[18:18+code_size+data_size])
total = code_size + data_size
i = 0
while i < code_size:
    op = body[i]
    if op == 0x01 and i + 4 <= code_size:
        val = int.from_bytes(body[i+1:i+4], 'little')
        if code_size <= val < total:
            val += load_addr
            body[i+1:i+4] = val.to_bytes(3, 'little')
        i += 4
    elif op in (0x30,0x31,0x32,0x33,0x54,0x55,0x56): i += 4
    elif op in (0x02,0x34,0x35,0x36,0x40,0x42,0x43,0x44,0x45,0x57,0x60): i += 2
    elif op in (0x58,0x59): i += 3
    elif op == 0x5A: i += 5
    else: i += 1
open(sys.argv[1].replace('.p24', '.bin'), 'wb').write(body)
print(f"Wrote {len(body)} bytes (code={code_size}, data={data_size}, globals={global_count}, entry=0x{entry:06X})")
