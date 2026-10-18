import os
#!/usr/bin/env python3
# Clip Ghidra function ranges: the mod's hook chunks (j into DBZP overlay and back) make Ghidra merge
# far-apart bodies into one function (FUN_0025b5b8 spans 1.4 MB). End = min(End, next real function start).
import csv,sys,bisect
rows=list(csv.DictReader(open(sys.argv[1])))
real=sorted({int(r['Start'],16) for r in rows if r['Name'].startswith(('FUN_','thunk_','entry,')) or r['Name']=='entry'})
out=open(sys.argv[2],'w'); out.write('Name,Start,End,Size\n'); n=0
for r in rows:
    s=int(r['Start'],16); e=int(r['End'],16)
    i=bisect.bisect_right(real,s)
    if i<len(real) and real[i]<e: e=real[i]; n+=1
    out.write('%s,0x%08X,0x%08X,%d\n'%(r['Name'],s,e,e-s))
print('clipped',n)

# Second pass: Ghidra stopped some bodies at an R5900 LQ/SQ/MMI word (FUN_00121fa8 was 1 byte:
# lq; jr ra; sq). Such functions (odd size, or ending on an MMI-class opcode) run to the next start.
import struct
e=open(os.path.expanduser('~/NBAStreetRecomp')+'/dbz/iso/SLUS_219.78.combined','rb').read()
def w(a):
    if 0x100000<=a<0x2c33c0: return struct.unpack_from('<I',e,a-0x100000+0x1000)[0]
    if 0x334c00<=a<0x3c01d4: return struct.unpack_from('<I',e,a-0x334c00+0x205000)[0]
    return None
rows=list(csv.DictReader(open(sys.argv[2])))
allstarts=sorted({int(r['Start'],16) for r in rows})
out=open(sys.argv[2],'w'); out.write('Name,Start,End,Size\n'); n=0
for r in rows:
    s=int(r['Start'],16); en=int(r['End'],16)
    x=w(en&~3)
    if (en-s)%4 or (x is not None and (x>>26) in (0x1c,0x1e,0x1f)):
        i=bisect.bisect_right(allstarts,s)
        if i<len(allstarts): en=allstarts[i]; n+=1
    out.write('%s,0x%08X,0x%08X,%d\n'%(r['Name'],s,en,en-s))
print('extended',n)
