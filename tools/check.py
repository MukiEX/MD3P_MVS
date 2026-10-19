"""Check built .neo files against the CRC32s of the builds tested on MiSTer."""
import os, sys, zlib

TESTED = {
    'magdrop3_paddle.neo': 0x5B2C556D,
    'magdrop3_paddle_nomagnet.neo': 0xF72F7CE4,
    'popbounc_paddle.neo': 0x8FCD904F,
    'pbobbl2n_paddle.neo': 0x54DDB460,
}

def main(build):
    bad = 0
    for name, want in TESTED.items():
        got = zlib.crc32(open(os.path.join(build, name), 'rb').read())
        ok = got == want
        bad += not ok
        print(f"{'OK  ' if ok else 'DIFF'} {name}  {got:08X}" + ("" if ok else f" (tested build: {want:08X})"))
    sys.exit(1 if bad else 0)

if __name__ == '__main__':
    main(sys.argv[1] if len(sys.argv) > 1 else 'build')
