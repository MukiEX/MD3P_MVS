import util, pickle
base = util.load('st_play.pkl', 'build/magdrop3_paddle.neo'); base.held[0]=set()
base.spinner(0, True, 1000); base.spin_counts(0, 6, 100); base.run(30)
# put the clown mid-field
st = base.save_state()
def trial(counts, rate=300):
    n = base; n.load_state(st); n.spin[0].rate=0; n.spin[0].t0=n.now(); n.spin[0].target=None
    n.run(20)                       # rest -> settle
    c0 = n.r8(0x100404)
    n.spin_counts(0, counts, rate); n.run(20)
    return n.r8(0x100404) - c0
print('start col', base.r8(0x100404))
for c in [1,2,3,4,5,6,7,8,9,10,11,12,-2,-3,-6,-7,-10]:
    print(f'{c:+3d} counts -> {trial(c):+d} cols', end='   ')
    print(f'(fast) {trial(c, 900):+d}')
