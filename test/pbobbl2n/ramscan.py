import util, neo, numpy as np, ctypes as C, sys, pickle
used = np.zeros(0x10000, bool); anyw = np.zeros(0x10000, bool)
def scan(n, frames, inputs=None, skip=0):
    for f in range(frames // 50):
        if f * 50 < skip:
            n.run(50); continue
        neo.watch(n, 0x100000, 0x110000, False, True)
        if inputs: inputs(n, f)
        n.run(50)
        L = neo.watch_log(n)
        for pc, a, v, rw, sz in L:
            o = a - 0x100000
            if 0 <= o < 0x10000:
                for k in range(2 if sz == 2 else (4 if sz == 4 else 1)):
                    anyw[min(o + k, 0xffff)] = True
                    if v: used[min(o + k, 0xffff)] = True
def lever(n, f):
    n.release(0, 'LEFT', 'RIGHT', 'A'); n.press(0, ['LEFT', 'RIGHT', 'A', 'LEFT'][f % 4])
n = util.load(None, 'pbobbl2n.neo'); scan(n, 20000, skip=900)
for st in ['st_play.pkl', 'st_x.pkl', 'st_diff.pkl']:
    n = util.load(st, 'pbobbl2n.neo'); scan(n, 4000, lever)
pickle.dump((used, anyw), open('ramscan.pkl', 'wb'))
def gaps(u, m=0x40):
    out = []; s = None
    for i in range(0x10001):
        if i < 0x10000 and not u[i]:
            s = i if s is None else s
        else:
            if s is not None and i - s >= m: out.append((hex(0x100000 + s), hex(i - s)))
            s = None
    return out
print('never nonzero:', gaps(used))
print('never written:', gaps(anyw))
