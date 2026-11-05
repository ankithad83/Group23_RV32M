#!/usr/bin/env python3
"""bin2mem.py in.bin out.mem -- raw binary -> one 32-bit little-endian word per
line in hex, for $readmemh into instruction memory."""
import sys
data = open(sys.argv[1], "rb").read()
data += b"\0" * (-len(data) % 4)
with open(sys.argv[2], "w") as f:
    for i in range(0, len(data), 4):
        f.write(f"{int.from_bytes(data[i:i+4], 'little'):08x}\n")
