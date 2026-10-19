import util, neo
ROM = 'build/pbobbl2n_paddle.neo'
A = 0x10d5da
n = util.load('pst_play.pkl', ROM)
def ang(): v = n.r16(A) << 16 | n.r16(A + 2); return (v - (1 << 32) if v & 0x80000000 else v) / 65536
n.run(2); print('start', ang(), 'det', n.r8(0x10f011))
n.press(0, 'RIGHT'); n.run(20); n.release(0, 'RIGHT'); print('lever R 20f', ang())
n.press(0, 'LEFT'); n.run(80); n.release(0, 'LEFT'); print('lever L 80f', ang())
n.tap(0, 'RIGHT', 1, 5); print('tap R', ang())
# menu with lever
m = util.load('pst_sel.pkl', ROM); F = util.Film()
m.run(1); F.add(m, 'sel')
m.tap(0, 'LEFT', 3, 20); F.add(m, 'L')
m.tap(0, 'RIGHT', 3, 20); F.add(m, 'R')
m.tap(0, 'A', 3, 90)
m.tap(0, 'DOWN', 3, 20); F.add(m, 'D')
m.tap(0, 'LEFT', 3, 20); F.add(m, 'L (no-op)')
m.tap(0, 'UP', 3, 20); F.add(m, 'U')
F.save('/tmp/lever.png', cols=6, scale=0.5)
# tick sounds with spinner
s = util.load('pst_play.pkl', ROM); s.spinner(0, True, quantum_us=1000)
s.spin_counts(0, 2, rate=60); s.run(5); neo.snd_log(s)
s.spin_counts(0, 20, rate=200); s.run(20); print('snd during +20', neo.snd_log(s))
