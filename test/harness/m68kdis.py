import sys,struct
import capstone
# P ROM in CPU byte order (un-word-swapped from the .neo); path via P_BIN
import os
P=open(os.environ.get('P_BIN','p.bin'),'rb').read()
md=capstone.Cs(capstone.CS_ARCH_M68K, capstone.CS_MODE_BIG_ENDIAN|capstone.CS_MODE_M68K_000)
md.skipdata=True
def dis(start,n=40,end=None):
    out=[]
    for i in md.disasm(P[start:(end or start+n*10)],start):
        out.append(f"{i.address:06x}: {i.bytes.hex():<20} {i.mnemonic} {i.op_str}")
        if end is None and len(out)>=n: break
    return "\n".join(out)
if __name__=='__main__':
    a=int(sys.argv[1],16); n=int(sys.argv[2]) if len(sys.argv)>2 else 40
    print(dis(a,n))
