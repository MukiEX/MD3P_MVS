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
    0x000068: '000012b4',
    0x001214: '4eb90000696e',
    0x001ea4: '33f900100002003c0006',
    0x002310: '103900300000', 0x002316: '123900340000', 0x00231c: '143900300000', 0x002322: '163900340000',
    0x00239e: '103900300000', 0x0023a4: '123900340000', 0x0023aa: '143900300000', 0x0023b0: '163900340000',
    0x002406: '02410080e609', 0x002414: '02410080e609', 0x002428: '02410080e609', 0x002436: '02410080e609',
    0x0023f2: '4a390010fd8c', 0x002736: '4a390010fd8c', 0x002a24: '4a390010fd8c',
}

def build(neo_in, srec, neo_out, free_lo=0xe85c2, free_hi=0x100000):
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
    name = b"Pop 'n Bounce Paddle Edition"   # .neo header: MiSTer's game name
    d[44:77] = name.ljust(33, b'\0')[:33]
    open(neo_out, 'wb').write(d)
    return p

if __name__ == '__main__':
    build(*sys.argv[1:4])
