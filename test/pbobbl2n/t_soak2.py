import util, neo, sys
rom, st, spin, N, play = sys.argv[1], sys.argv[2], sys.argv[3] == '1', int(sys.argv[4]), sys.argv[5] == '1'
n = util.load(None if st == '-' else st, rom)
if spin: n.spinner(0, True, quantum_us=1000)
n.run(300)
for i in range(N // 50):
    if spin and i % 4 == 0: n.spin_counts(0, (37, -53, 21, -9)[i // 4 % 4], rate=250)
    if play and i % 3 == 0: n.tap(0, 'A', 2, 0)
    if not spin and play and i % 5 == 0: n.press(0, 'LEFT' if i % 10 else 'RIGHT')
    if i % 5 == 2: n.release(0, 'LEFT', 'RIGHT')
    neo.watch(n, 0x10f000, 0x10f002, False, True); n.run(50)
    if any(pc >= 0xc00000 for pc, a, v, rw, sz in neo.watch_log(n)):
        print(sys.argv[2:], 'REBOOT at', n.frame_no); n.shot('/tmp/reboot.png'); break
else:
    print(sys.argv[2:], 'ok', n.frame_no, 'det', n.r8(0x10f011))
