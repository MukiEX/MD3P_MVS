import util
# lever on char select and level select must behave like the original
for rom in ['in/magdrop3.neo', 'build/magdrop3_paddle.neo']:
    n = util.load('st_char.pkl', rom)
    seq = []
    for b in ['RIGHT', 'RIGHT', 'DOWN', 'LEFT', 'UP']:
        n.tap(0, b, 3, 20); seq.append(n.r8(0x1000fa))
    m = util.load('st_chsel.pkl', rom)
    lv = []
    for b in ['DOWN', 'DOWN', 'UP']:
        m.tap(0, b, 3, 20); lv.append(bytes(m.fb[::997]) .__hash__() % 1000)
    print(rom, 'charsel', seq, 'levelsel frames', lv)
