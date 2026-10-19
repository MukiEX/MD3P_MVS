import util
n = util.load('st_char.pkl', 'build/magdrop3_paddle.neo')
f = util.Film()
n.spinner(0, True, 1000)
n.spin_counts(0, 6, 100); n.run(10)     # detect
f.add(n, 'det fa=%d' % n.r8(0x1000fa))
for st in [16, 16, 16, -16, -16, -16, -16, -16, -16, -16, -16]:
    n.spin_counts(0, st, 200); n.run(8)
    f.add(n, '%+d fa=%d' % (st, n.r8(0x1000fa)))
print([n.r8(0x1000fa)])
f.save('/tmp/grid.png', cols=4, scale=0.6)
