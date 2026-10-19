"""Apply an assembled S-record patch to a .neo and write the result."""
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

# expected original bytes at each patch site (guards against wrong ROM)
EXPECT = {
    0x000068: '00000ce0',
    0x000d0e: '123900300000',
    0x000d3a: '123900340000',
    0x000e10: '08b9000700100060',
    0x0015bc: '33c0003c0006',
    0x0020a2: '33c7003c0006',
    0x025c00: '33c7003c0006',
    0x025ee2: '33c7003c0006',
    0x026106: '33c7003c0006',
    0x018bc8: '0200000c6600001e',
    0x027698: '10110240000f',
    0x027246: '4eba00cc',
    0x010a24: '23f900100102001014e4',
    0x010abc: '23f9001014e400100102',
    0x010a8c: '0c790004001014e0',
    0x010aaa: '0c790004001014e0',
    0x010b34: '43fa00c24e71',
    0x010b7c: '207c00010bb8',
    0x010bd0: '41fa001e4e71',
    0x010fa8: '70000802000467027001804336983a188a40368551cefff6',
    0x019196: '10280004d0403a330000',
    0x019268: '10280004d0403a330000',
    0x019196: '10280004d0403a330000',
    0x019268: '10280004d0403a330000',
    0x0152a0: '102b0003d04030320000',
    0x009dcc: '122900020201000c',
}

def build(neo_in, srec, neo_out, free_lo=0x4db16, free_hi=0x66000):
    d = bytearray(open(neo_in, 'rb').read())
    psize = struct.unpack('<I', d[4:8])[0]
    p = bytearray(d[4096:4096 + psize])
    p[0::2], p[1::2] = p[1::2], p[0::2]          # .neo P is word-swapped
    for a, exp in EXPECT.items():
        got = p[a:a + len(exp) // 2].hex()
        assert got == exp, f'site {a:06x}: expected {exp}, found {got}'
    for addr, data in srec_records(srec):
        if free_lo <= addr < free_hi:
            assert all(b == 0xff for b in p[addr:addr + len(data)]), f'free area not free at {addr:x}'
        elif addr not in EXPECT and not any(s <= addr < s + len(e) // 2 for s, e in EXPECT.items()):
            raise SystemExit(f'unexpected patch address {addr:06x}')
        p[addr:addr + len(data)] = data
    open(neo_out.replace('.neo', '_p1.bin'), 'wb').write(p)
    q = bytearray(p)
    q[0::2], q[1::2] = p[1::2], p[0::2]
    d[4096:4096 + psize] = q
    name = b'Magical Drop III Paddle Edition'   # .neo header: MiSTer's game name
    d[44:77] = name.ljust(33, b'\0')[:33]
    open(neo_out, 'wb').write(d)
    return p

if __name__ == '__main__':
    build(*sys.argv[1:4])
