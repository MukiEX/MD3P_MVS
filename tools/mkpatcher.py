"""Build the single-file HTML patcher from the original ROMs and the built Paddle Editions.

The page carries only the changed bytes (and CRCs to recognise the inputs and
check the outputs), never ROM data.

usage: mkpatcher.py ROM_DIR BUILD_DIR TEMPLATE OUT_HTML
"""
import base64, json, os, struct, sys, zlib

GAMES = {   # key: (original .neo, built .neo)
    'md3': ('magdrop3.neo', 'magdrop3_paddle.neo'),
    'pnb': ('popbounc.neo', 'popbounc_paddle.neo'),
    'pb2': ('pbobbl2n.neo', 'pbobbl2n_paddle.neo'),
}
MD3_NOMAGNET = 'magdrop3_paddle_nomagnet.neo'


def prom(path):
    """(raw .neo bytes, P ROM in CPU byte order)"""
    d = open(path, 'rb').read()
    ps = struct.unpack('<I', d[4:8])[0]
    p = bytearray(d[4096:4096 + ps])
    p[0::2], p[1::2] = p[1::2], p[0::2]          # .neo P ROM is word-swapped
    return d, bytes(p)


def raw_pcrc(d):
    ps = struct.unpack('<I', d[4:8])[0]
    return zlib.crc32(d[4096:4096 + ps])


def runs(a, b):
    """[cpu_offset, base64 bytes] for every stretch of b that differs from a"""
    out, i, n = [], 0, len(b)
    while i < n:
        if a[i] == b[i]:
            i += 1
            continue
        j = i
        while j < n and not (a[j] == b[j] and a[j:j + 8] == b[j:j + 8]):
            j += 1
        out.append([i, base64.b64encode(b[i:j]).decode()])
        i = j
    return out


def main(rom_dir, build_dir, template, out_html):
    data = {}
    for key, (orig, built) in GAMES.items():
        do, po = prom(os.path.join(rom_dir, orig))
        dn, pn = prom(os.path.join(build_dir, built))
        base = po + b'\xff' * (len(pn) - len(po))   # Puzzle Bobble 2 grows to 2 MB
        data[key] = dict(psize=len(po), newsize=len(pn), name=dn[44:77].rstrip(b'\0').decode(),
                         runs=runs(base, pn), rawcrc=raw_pcrc(do), rawout=raw_pcrc(dn))
    nm = os.path.join(build_dir, MD3_NOMAGNET)
    data['md3']['rawout_nomag'] = raw_pcrc(open(nm, 'rb').read())
    html = open(template).read().replace('__DATA__', json.dumps(data, separators=(',', ':')))
    open(out_html, 'w').write(html)


if __name__ == '__main__':
    main(*sys.argv[1:5])
