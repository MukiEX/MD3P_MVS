import util, neo, pickle
n = util.load('st_play.pkl', 'build/magdrop3_paddle.neo'); n.held[0]=set()
n.spinner(0, True, 1000); n.spin_counts(0, 6, 100); n.run(20)
n.tap(0, 'A', 2, 40)   # pull
held = n.r8(0x100408)
def bottoms():
    out=[]
    for c in range(7):
        cnt = n.r8(0x100680 + c*64 + 1)
        v = n.r8(0x100680 + c*64 + 0x1c) if cnt >= 0xd else n.r8(0x100cf8 + 24*c)
        out.append(v)
    return out
print('held', held, 'col', n.r8(0x100404), 'bottoms', bottoms())
st = n.save_state()
def trial(counts, start_col_moves=0):
    n.load_state(st); n.spin[0].rate=0; n.spin[0].t0=n.now(); n.spin[0].target=None
    n.run(20); c0 = n.r8(0x100404)
    n.spin_counts(0, counts, 300); n.run(20)
    return c0, n.r8(0x100404)
for c in (3,4,5,6,7,-3,-5,-6,-7):
    print(c, trial(c))
pickle.dump(st, open('st_held.pkl','wb'))
