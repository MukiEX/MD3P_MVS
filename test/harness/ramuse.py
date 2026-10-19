import numpy as np, ctypes as C, neo
def tracker(n):
    n.lib.geo_dbg_logptr.restype = C.c_void_p
    n.lib.geo_dbg_get_count.restype = C.c_uint32
    used = np.zeros(0x10000, bool)
    def step(frames=1):
        for _ in range(frames):
            neo.watch(n, 0x100000, 0x110000, True, True)
            n.run(1)
            cnt = n.lib.geo_dbg_get_count()
            if cnt:
                arr = np.frombuffer((C.c_uint8 * (16 * cnt)).from_address(n.lib.geo_dbg_logptr()), dtype=np.uint32).reshape(-1, 4)
                a = arr[:, 1] - 0x100000; sz = arr[:, 3] & 0xff
                used[a] = True; used[np.minimum(a + 1, 0xffff)[sz == 2]] = True
    return used, step
def gaps(used, minlen=0x80):
    out=[]; s=None
    for i in range(0x10000):
        if not used[i]:
            if s is None: s=i
        else:
            if s is not None and i-s>=minlen: out.append((hex(0x100000+s),hex(i-s)))
            s=None
    if s is not None: out.append((hex(0x100000+s),hex(0x10000-s)))
    return out
