import util, neo
n = util.load('st_play.pkl', 'build/magdrop3_paddle.neo')
n.held[0] = set()
n.run(30)
f = util.Film()
n.spinner(0, True, quantum_us=1000)
n.spin_counts(0, 8, rate=100); n.run(10)   # get detected
print('det', n.peek(0x10f010, 12).hex(), 'col', n.r8(0x100404), 'width', n.r8(0x10061a))
f.add(n, 'det')
for step in [4, 4, 4, -4, -8, 40, -40]:
    c0 = n.r8(0x100404)
    n.spin_counts(0, step, rate=150)
    n.run(15)
    print(f'{step:+d}: col {c0} -> {n.r8(0x100404)}   GACC {n.peek(0x10f01c,2).hex()} claim {n.r8(0x10f008)}')
    f.add(n, f'{step:+d} col{n.r8(0x100404)}')
f.save('/tmp/grid.png', cols=4, scale=0.75)
