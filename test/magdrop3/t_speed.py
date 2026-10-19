import util, neo
base = util.load('st_play.pkl', 'build/magdrop3_paddle.neo'); base.held[0]=set()
base.spinner(0, True, 1000); base.spin_counts(0, 6, 100); base.run(30)
st = base.save_state()
def trial(speed, counts):
    n = base; n.load_state(st); n.spin[0].rate=0; n.spin[0].t0=n.now(); n.spin[0].target=None
    neo.w8(n, 0x10f00a, speed); n.run(20)
    c0 = n.r8(0x100404); n.spin_counts(0, counts, 300); n.run(20)
    return n.r8(0x100404) - c0
for sp in (2,1,0):
    print('speed', ['x0.25','x0.5','x1'][sp], [ (c, trial(sp,c)) for c in (2,3,5,6,7,11,12,13,-3,-6,-12)])
