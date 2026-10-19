import util, sys
ROM = 'build/pbobbl2n_paddle.neo'
def run(spin, up):
    n = util.load('pst_play.pkl', ROM)
    n.spinner(0, spin, quantum_us=1000)
    if spin:
        n.spin_counts(0, 30, rate=300); n.run(15)
    n.tap(0, 'A', 3, 30)
    if up: n.press(0, 'UP')
    n.run(40); n.release(0, 'UP'); n.run(60)
    return hex(n.pc()), n.r16(0x10f004)
for spin in (False, True):
    for up in (False, True):
        print(spin, up, run(spin, up))
