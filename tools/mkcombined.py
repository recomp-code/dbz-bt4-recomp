import os
#!/usr/bin/env python3
# Build SLUS_219.78 + BIN/DBZP.BIN (code overlay loaded at 0x334c00 by 0x100280) as one ELF for recompilation.
import struct,sys
iso=os.path.expanduser('~/NBAStreetRecomp')+'/dbz/iso/'
e=bytearray(open(iso+'SLUS_219.78','rb').read())
b=open(iso+'BIN/DBZP.BIN','rb').read()
BASE=0x334c00
phoff,shoff=struct.unpack_from('<II',e,28)
phentsize,phnum,shentsize,shnum,shstrndx=struct.unpack_from('<HHHHH',e,42)
# append overlay data
while len(e)%0x1000: e.append(0)
X=len(e); e+=b
while len(e)%16: e.append(0)
# repurpose the empty 4th PT_LOAD
for i in range(phnum):
    p=phoff+i*32
    t,off,va,pa,fs,ms,fl,al=struct.unpack_from('<8I',e,p)
    if t==1 and fs==0 and ms==0:
        struct.pack_into('<8I',e,p,1,X,BASE,BASE,len(b),len(b),5,0x1000); break
else: sys.exit('no free phdr')
# new shstrtab
sh=[bytearray(e[shoff+i*40:shoff+i*40+40]) for i in range(shnum)]
so=struct.unpack_from('<I',sh[shstrndx],16)[0]; ss=struct.unpack_from('<I',sh[shstrndx],20)[0]
strtab=bytearray(e[so:so+ss]); nameoff=len(strtab); strtab+=b'.dbzp\0'
S=len(e); e+=strtab
while len(e)%16: e.append(0)
struct.pack_into('<II',sh[shstrndx],16,S,len(strtab))
new=struct.pack('<10I',nameoff,1,6,BASE,X,len(b),0,0,4,0)
# insert the new section right after .vubss (keep index order irrelevant; append at end)
SH=len(e)
for s in sh: e+=s
e+=new
struct.pack_into('<I',e,32,SH)
struct.pack_into('<H',e,48,shnum+1)
open(sys.argv[1],'wb').write(e)
print('ok',hex(X),hex(len(b)))
