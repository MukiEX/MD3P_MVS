"""Apply the assembled S-record patch to Puzzle Bobble 2 (.neo) and write the result.

The patch code lives at CPU $200000, so the P ROM grows from 1 MB to 2 MB
(the second megabyte is the P2 bank, which shows at $200000 by default).
"""
import sys, struct

def srec_records(path):
    for line in open(path):
        line = line.strip()
        if not line.startswith('S') or line[1] not in '123':
            continue
        alen = {'1': 2, '2': 3, '3': 4}[line[1]]
        n = int(line[2:4], 16)
        raw = bytes.fromhex(line[4:4 + n * 2])
        addr = int.from_bytes(raw[:alen], 'big')
        yield addr, raw[alen:-1]

# original bytes at each patch site (guards against the wrong ROM)
EXPECT = {
    0x000068: '00002392',
    0x00236c: '4eb900c0044a',
    0x002406: '4eb900c0044a',
    0x0023e8: '33fc0008003c0006',
    0x002440: '33fc0038003c000623fc00006000003c0008',
    0x002480: '10390010fd9c',
    0x002492: '10390010fd96',
    0x062290: '1942000619430007',
    0x027c80: '322dd82a08000000',
}
CODE = 0x200000            # CPU address of the patch code
PBANK = 0x100000           # its P ROM offset (start of the 2nd megabyte)

def build(neo_in, srec, neo_out):
    d = bytearray(open(neo_in, 'rb').read())
    psize = struct.unpack('<I', d[4:8])[0]
    assert psize == 0x100000, 'expected a 1 MB P ROM'
    p = bytearray(d[4096:4096 + psize])
    p[0::2], p[1::2] = p[1::2], p[0::2]          # .neo P is word-swapped
    for a, exp in EXPECT.items():
        got = p[a:a + len(exp) // 2].hex()
        assert got == exp, f'site {a:06x}: expected {exp}, found {got}'
    p += b'\xff' * 0x100000
    for addr, data in srec_records(srec):
        if CODE <= addr < CODE + 0x100000:
            off = addr - CODE + PBANK
        elif any(s <= addr < s + len(e) // 2 for s, e in EXPECT.items()):
            off = addr
        else:
            raise SystemExit(f'unexpected patch address {addr:06x}')
        p[off:off + len(data)] = data
    open(neo_out.replace('.neo', '_p.bin'), 'wb').write(p)
    q = bytearray(p)
    q[0::2], q[1::2] = p[1::2], p[0::2]
    d[4096:4096 + psize] = q                     # replaces 1 MB with 2 MB
    d[4:8] = struct.pack('<I', len(p))
    name = b"Puzzle Bobble 2 Paddle Edition"     # .neo header: MiSTer's game name
    d[44:77] = name.ljust(33, b'\0')[:33]
    open(neo_out, 'wb').write(d)
    return p

if __name__ == '__main__':
    build(*sys.argv[1:4])
