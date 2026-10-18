import os
#!/usr/bin/env python3
# Entry points for code the Ghidra map does not cover (Ghidra stops at VU0 macro / MMI words and
# misses functions only reached through pointers): each gap start + every address after
# "jr ra; delay" (nops skipped) inside a gap. Writes config/gap_entries.txt.
import struct,csv
e=open(os.path.expanduser('~/NBAStreetRecomp')+'/dbz/iso/SLUS_219.78.combined','rb').read()
CODE=[(0x100000,0x2bf6b0,0x1000),(0x334c00,0x3c01d4,0x205000)]
def w(a):
    for lo,hi,off in CODE:
        if lo<=a<hi: return struct.unpack_from('<I',e,a-lo+off)[0]
    return None
rows=list(csv.DictReader(open(os.path.expanduser('~/NBAStreetRecomp')+'/dbz/config/functions.csv')))
iv=sorted((int(r['Start'],16),int(r['End'],16)) for r in rows)
cov=[]
for s,en in iv:
    if cov and s<=cov[-1][1]: cov[-1][1]=max(cov[-1][1],en)
    else: cov.append([s,en])
bounds=[]
for lo,hi,off in CODE:
    pts=[c for c in cov if c[0]<hi and c[1]>lo]
    prev=lo
    for s,en in pts:
        if s>prev: bounds.append((prev,s))
        prev=max(prev,en)
    if prev<hi: bounds.append((prev,hi))
out=set()
for a,b in bounds:
    p=a
    while p<b and w(p)==0: p+=4
    if p<b: out.add(p)
    q=p
    while q<b-4:
        if w(q)==0x03e00008:
            r=q+8
            while r<b and w(r)==0: r+=4
            if r<b: out.add(r)
        q+=4
out=sorted(out)
open(os.path.expanduser('~/NBAStreetRecomp')+'/dbz/config/gap_entries.txt','w').write('\n'.join('%x'%x for x in out))
print('gaps',len(bounds),'entries',len(out),'bytes',sum(b-a for a,b in bounds))
