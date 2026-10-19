import util, pickle, numpy as np
from PIL import Image
n = util.load(None, 'build/pbobbl2n_paddle.neo')
n.run(400)
def img():
    return np.asarray(Image.frombuffer('RGBX', (n.fbw, n.fbh), n.fb, 'raw', 'BGRX', n.fbpitch, 1).convert('RGB')).astype(int)
for tries in range(20):
    n.tap(0, 'SELECT', 5, 60)
    n.tap(0, 'START', 5, 120)
    a = img()
    teal = ((a[..., 1] > a[..., 0] + 40) & (a[..., 2] > a[..., 0] + 40)).mean()
    if teal > 0.4:
        break
    n.run(100)
print('game select after', tries, 'tries; teal', round(teal, 2))
n.shot('/tmp/sel.png')
pickle.dump(n.save_state(), open('pst_sel.pkl', 'wb'))
