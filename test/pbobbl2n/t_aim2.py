import util
ROM = 'build/pbobbl2n_paddle.neo'
n = util.load('pst_play.pkl', ROM)
n.spinner(0, True, quantum_us=1000)
A = 0x10d5da
def ang(): v = n.r16(A) << 16 | n.r16(A + 2); return (v - (1 << 32) if v & 0x80000000 else v) / 65536
F = util.Film()
n.run(2); F.add(n, 'start %.1f' % ang()); print(F.frames.__len__(), 'start %.1f' % ang())
n.spin_counts(0, 40, rate=300); n.run(15); F.add(n, '+40 -> %.1f' % ang()); print(F.frames.__len__(), '+40 -> %.1f' % ang())
n.spin_counts(0, -150, rate=600); n.run(30); F.add(n, '-150 -> %.1f' % ang()); print(F.frames.__len__(), '-150 -> %.1f' % ang())
n.spin_counts(0, 30, rate=300); n.run(15); F.add(n, '+30 -> %.1f' % ang()); print(F.frames.__len__(), '+30 -> %.1f' % ang())
n.tap(0, 'A', 3, 30); F.add(n, 'fire'); print(F.frames.__len__(), 'fire')
n.press(0, 'UP'); n.run(40); n.release(0, 'UP'); F.add(n, 'UP -> %.1f' % ang()); print(F.frames.__len__(), 'UP -> %.1f' % ang())
n.spin_counts(0, 3, rate=100); n.run(10); F.add(n, '+3 -> %.1f' % ang()); print(F.frames.__len__(), '+3 -> %.1f' % ang())
F.save('/tmp/aim.png', cols=4)
