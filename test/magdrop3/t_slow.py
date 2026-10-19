import util, sys
def patch(src, dst, off, val):
    d=bytearray(open(src,'rb').read()); d[4096+((0x4e000+off)^1)]=val; open(dst,'wb').write(d)
patch('build/magdrop3_paddle.neo','/tmp/dk0.neo',24,0)
for rom in ['/tmp/dk0.neo','build/magdrop3_paddle.neo']:
    n=util.load('st_held.pkl',rom); n.held[0]=set(); n.spinner(0,True,1000)
    n.spin_counts(0,-4,200); n.run(10); t0=n.r16(0x100066); f0=n.frame_no
    for i in range(20): n.spin_counts(0,4 if i%2 else -4,100)
    n.run(200); print(rom,'ticks', n.r16(0x100066)-t0, 'in', n.frame_no-f0, 'frames')
