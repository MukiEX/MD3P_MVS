import util, neo, sys
n = util.load(None, sys.argv[1])
n.run(300)
for i in range(30):
    neo.watch(n, 0x10f000, 0x10f002, False, True); n.run(50)
    if any(pc >= 0xc00000 for pc, a, v, rw, sz in neo.watch_log(n)):
        print(sys.argv[2], 'REBOOT at', n.frame_no); break
else:
    print(sys.argv[2], 'ok to', n.frame_no)
