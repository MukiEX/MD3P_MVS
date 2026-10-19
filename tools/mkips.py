import sys
def ips(a, b):
    assert len(a) == len(b)
    out = bytearray(b'PATCH'); i = 0; n = len(a)
    while i < n:
        if a[i] == b[i]: i += 1; continue
        j = i
        while j < n and j - i < 0xffff and (a[j] != b[j] or (j + 1 < n and a[j+1] != b[j+1] and j + 1 - i < 0xffff)):
            j += 1
        if i == 0x454f46: i -= 1   # avoid 'EOF' offset
        out += i.to_bytes(3, 'big') + (j - i).to_bytes(2, 'big') + b[i:j]
        i = j
    return bytes(out + b'EOF')
if __name__ == '__main__':
    a = open(sys.argv[1], 'rb').read(); b = open(sys.argv[2], 'rb').read()
    open(sys.argv[3], 'wb').write(ips(a, b))
