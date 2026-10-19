import util, neo
n = util.load('st_x.pkl', 'build/magdrop3_paddle.neo')
f = util.Film()
n.run(2); f.add(n, 'start')
n.spinner(0, True, quantum_us=1000)
n.run(2)
print('magic', n.peek(0x10f000, 4), 'p1', n.peek(0x10f010, 12).hex(), 'lspc', n.peek(0x10f004,4).hex())
for step in [16, 16, -16, -32]:
    n.spin_counts(0, step, rate=200)
    n.run(20)
    f.add(n, f'{step:+d}')
    print(step, 'p1', n.peek(0x10f010, 12).hex(), 'reads/frame', n.reads[0])
f.save('/tmp/grid.png', cols=5)
