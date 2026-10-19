import neo,util,pickle
n=neo.Neo('build/magdrop3_paddle.neo'); n.run(1300)
n.tap(0,'SELECT',5,30); neo.w8(n,0x10fd82,0)
n.tap(0,'START',5,90); n.tap(0,'DOWN',3,10); n.tap(0,'A',3,40)
f=util.Film(); f.add(n,'menu')
for i in range(4): n.tap(0,'DOWN',3,12)
f.add(n,'cursor4 speed=%d'%n.r8(0x10f00a))
n.tap(0,'A',3,12)                      # edit
n.tap(0,'DOWN',3,12); f.add(n,'edit +1')
n.tap(0,'DOWN',3,12); f.add(n,'edit +2')
n.tap(0,'A',3,12)                      # back to list
n.tap(0,'DOWN',3,12); f.add(n,'cursor5 EXIT')
n.tap(0,'A',3,40); f.add(n,'exit speed=%d'%n.r8(0x10f00a))
pickle.dump(n.save_state(),open('st_opt_after.pkl','wb'))
f.save('/tmp/grid.png',cols=3,scale=0.8)
print('speed', n.r8(0x10f00a), 'settings', n.peek(0x100102,4).hex())
