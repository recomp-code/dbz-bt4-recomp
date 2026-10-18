import os
#!/usr/bin/env python3
# xref.py <addr>... : code locations that build the address with lui+addiu/ori/lw (combined ELF incl. DBZP)
import struct,sys
e=open(os.path.expanduser('~/NBAStreetRecomp')+'/dbz/iso/SLUS_219.78.combined','rb').read()
segs=[(0x100000,0x1000,0x1c33c0),(0x334c00,0x205000,0x8b5d4)]
for t in [int(a,16) for a in sys.argv[1:]]:
    hi=(t+0x8000)>>16 & 0xffff; lo=t&0xffff; hio=t>>16
    for va,off,sz in segs:
        W=struct.unpack_from('<%dI'%(sz//4),e,off)
        for k,x in enumerate(W):
            if (x>>26)==15 and (x&0xffff) in (hi,hio):
                rt=(x>>16)&31
                for m in range(k+1,min(k+16,len(W))):
                    y=W[m]
                    if (y&0xffff)==lo and ((y>>21)&31)==rt and (y>>26) in (8,9,13,24,25,35,32,36,33,37,39,43,40,41,55,63,49,57):
                        print(hex(t),'lui',hex(va+k*4),'use',hex(va+m*4)); break
