import util, neo, ctypes as C, numpy as np, wave, sys
P = open('p.bin', 'rb').read()
SR = int(sys.argv[2]) if len(sys.argv) > 2 else 48000
def make(st):
    n = util.load(st, 'in/magdrop3.neo'); n.held[0] = set()
    n.abuf = []
    def ab(d, cnt):
        n.abuf.append(np.ctypeslib.as_array(C.cast(d, C.POINTER(C.c_int16)), (cnt * 2,)).copy()); return cnt
    n._audiob = neo.AUDIOB_CB(ab); n.lib.retro_set_audio_sample_batch(n._audiob)
    n.lib.geo_dbg_sound.argtypes = [C.c_uint]
    return n
def render(n, st0, code, frames=50):
    n.load_state(st0); n.abuf.clear(); n.run(frames); base = np.concatenate(n.abuf)
    n.load_state(st0); n.abuf.clear()
    if code is not None:
        b0, b1 = P[0x11450 + 2 * code], P[0x11451 + 2 * code]
        n.lib.geo_dbg_sound(b0); n.run(1); n.lib.geo_dbg_sound(b1)
        n.run(frames - 1)
    else:
        n.run(frames)
    x = np.concatenate(n.abuf)
    m = min(len(x), len(base))
    return (x[:m].astype(np.int32) - base[:m]).reshape(-1, 2)
