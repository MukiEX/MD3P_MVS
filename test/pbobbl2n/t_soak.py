import util, sys, time
ROM = sys.argv[1]; spin = sys.argv[2] == '1'; N = int(sys.argv[3])
n = util.load(None, ROM)
if spin: n.spinner(0, True, quantum_us=1000)
F = util.Film(); last = None; still = 0
for i in range(N // 100):
    if spin and i % 3 == 0: n.spin_counts(0, 37 if i % 2 else -41, rate=300)
    n.run(100)
    k = (n.r16(0x10ee08), n.r16(0x10f004), n.r16(0x10fe80) if False else 0)
    still = still + 1 if k == last else 0; last = k
    if i % 10 == 9: F.add(n, str(n.frame_no))
    if still >= 8 and n.frame_no > 3000:
        print('STUCK at', n.frame_no, hex(n.pc())); F.add(n, 'stuck'); break
print('end', n.frame_no, 'det', n.r8(0x10f011))
F.save('/tmp/soak_%d.png' % spin, cols=6, scale=0.4)
