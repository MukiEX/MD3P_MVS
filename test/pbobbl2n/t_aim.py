import util, pickle, numpy as np
ROM = 'build/pbobbl2n_paddle.neo'
n = util.load('pst_play.pkl', ROM)
n.spinner(0, True, quantum_us=1000)
n.run(60)
n.shot('/tmp/p0.png')
def L(): return np.frombuffer(bytes(n.ram), '>i4').copy(), np.frombuffer(bytes(n.ram)[2:] + b'\0\0', '>i4').copy()
a0, b0 = L()
n.spin_counts(0, 20, rate=200); n.run(20)
a1, b1 = L()
n.spin_counts(0, -50, rate=200); n.run(30)
a2, b2 = L()
for arr0, arr1, arr2, off in [(a0, a1, a2, 0), (b0, b1, b2, 2)]:
    for i in np.nonzero((arr1 - arr0 == 20 << 16) & (arr2 - arr1 == -50 << 16))[0]:
        print(hex(0x100000 + i * 4 + off), arr0[i] / 65536, arr1[i] / 65536, arr2[i] / 65536)
