import util, pickle, sys
ROM = 'build/pbobbl2n_paddle.neo'
def R32(n, a): return n.r16(a) << 16 | n.r16(a + 2)
def s16(v): return v - 0x10000 if v & 0x8000 else v
def angle(n, a4): v = R32(n, a4 + 0xc); return (v - (1 << 32) if v & 0x80000000 else v) / 65536
F = util.Film()
n = util.load('pst_sel.pkl', ROM)
n.spinner(0, True, quantum_us=1000)
n.run(5)
print('magic', hex(R32(n, 0x10f000)), 'det', n.r8(0x10f011), 'cnt', n.r16(0x10f012))
n.spin_counts(0, 2, rate=60); n.run(10)
print('after spin det', n.r8(0x10f011), 'cnt', s16(n.r16(0x10f012)))
F.add(n, 'game sel')
for c, lab in [(16, '+16'), (16, '+16'), (-16, '-16'), (8, '+8'), (8, '+8 (=16)')]:
    n.spin_counts(0, c); n.run(20); F.add(n, lab)
n.spin_counts(0, -16); n.run(20); F.add(n, '-16'); n.tap(0, 'A', 3, 90); F.add(n, 'A -> diff')
for c, lab in [(16, '+16'), (16, '+16'), (-16, '-16'), (-16, '-16'), (-16, '-16')]:
    n.spin_counts(0, c); n.run(20); F.add(n, lab)
pickle.dump(n.save_state(), open('st_p_diff.pkl', 'wb'))
F.save('/tmp/t_menu.png', cols=4, scale=0.75)
