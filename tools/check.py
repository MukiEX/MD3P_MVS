"""Check built .neo files against the CRC32s of the released builds."""
import os, sys, zlib

TESTED = {
    'magdrop3_paddle.neo': 0x0FFD5A29,
    'magdrop3_paddle_nomagnet.neo': 0xA3FE73A0,
    'popbounc_paddle.neo': 0x20762158,
    'pbobbl2n_paddle.neo': 0xB262D81C,
}

def main(build):
    bad = 0
    for name, want in TESTED.items():
        got = zlib.crc32(open(os.path.join(build, name), 'rb').read())
        ok = got == want
        bad += not ok
        print(f"{'OK  ' if ok else 'DIFF'} {name}  {got:08X}" + ("" if ok else f" (released build: {want:08X})"))
    sys.exit(1 if bad else 0)

if __name__ == '__main__':
    main(sys.argv[1] if len(sys.argv) > 1 else 'build')
