import util, neo
# 1) lever still works on patched ROM in-game
n = util.load('st_play.pkl', 'build/magdrop3_paddle.neo'); n.held[0]=set(); n.run(30)
c0 = n.r8(0x100404); n.tap(0,'LEFT',2,10); c1 = n.r8(0x100404); n.tap(0,'RIGHT',2,10); c2=n.r8(0x100404)
print('lever in-game', c0, c1, c2, 'det', n.r8(0x10f011))
# 2) tick rate with/without spinner, same state, idle
for spin in (False, True):
    n = util.load('st_play.pkl', 'build/magdrop3_paddle.neo'); n.held[0]=set()
    if spin:
        n.spinner(0, True, 1000); n.spin_counts(0, 6, 100)
    n.run(10)
    t0 = n.r16(0x100066); f0 = n.frame_no
    n.spin_rate(0, 0); n.run(600)
    print('spinner' if spin else 'lever', 'ticks per 600 frames', n.r16(0x100066)-t0)
# 3) fast spin accuracy at 1 ms quantum and raw
for q in (1000, 0):
    n = util.load('st_x.pkl', 'build/magdrop3_paddle.neo')
    n.spinner(0, True, q); n.spin_counts(0, 6, 100); n.run(5)
    c0 = n.r16(0x10f012)
    if c0 & 0x8000: c0 -= 0x10000
    for rate in (500, 1000, 3000):
        start = c0 = (n.r16(0x10f012) ^ 0x8000) - 0x8000
        n.spin_counts(0, 600, rate); n.run(3)
        end = (n.r16(0x10f012) ^ 0x8000) - 0x8000
        print(f'quantum {q}us rate {rate}/s: counted {end-start} of 600')
