import util, sys
from PIL import Image
src=open('build/magdrop3_paddle.neo','rb').read()
d=bytearray(src); d[4096+((0x4e000+24)^1)]=5; open('/tmp/pulse.neo','wb').write(d)
n=util.load('st_held.pkl','/tmp/pulse.neo'); n.held[0]=set(); n.spinner(0,True,1000)
n.spin_counts(0,-4,200); n.run(20)
t0=n.r16(0x100066); f0=n.frame_no
ims=[]
for i in range(14):
    n.run(4); n.shot('/tmp/z.png')
    ims.append(Image.open('/tmp/z.png').crop((40,0,110,224)).resize((140,448),Image.NEAREST))
n.run(200)
print('ticks',n.r16(0x100066)-t0,'frames',n.frame_no-f0)
W=Image.new('RGB',(140*14,448))
for i,im in enumerate(ims): W.paste(im,(140*i,0))
W.save('build/pulse_frames.png')
frames=[im.convert('P', palette=Image.ADAPTIVE) for im in ims]
ims[0].save('build/pulse.gif', save_all=True, append_images=ims[1:]+ims[::-1][1:-1], duration=67, loop=0)
