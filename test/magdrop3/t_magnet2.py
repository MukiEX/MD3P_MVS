import util, neo, pickle, struct, sys
rom = sys.argv[1]
n = util.load('st_held.pkl', rom); n.held[0]=set(); n.spinner(0, True, 1000)
st = n.save_state()
def trial(counts):
    n.load_state(st); n.spin[0].rate=0; n.spin[0].t0=n.now(); n.spin[0].target=None
    n.run(20); c0 = n.r8(0x100404)
    n.spin_counts(0, counts, 200); n.run(25)
    return n.r8(0x100404)
print(rom, [(c, trial(c)) for c in (-10,-11,-12,-13,-14,-15,-16,-17,-18,-19,-20)])
