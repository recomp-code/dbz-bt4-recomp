import os
#!/usr/bin/env python3
# dis.py <start> <end> [file [base]]  -- disassemble DBZ ELF (or a raw BIN with base)
import sys,struct,capstone
args=sys.argv[1:]
lo=int(args[0],16); hi=int(args[1],16)
f=args[2] if len(args)>2 else os.path.expanduser('~/NBAStreetRecomp')+'/dbz/iso/SLUS_219.78'
e=open(f,'rb').read()
segs=[]
if len(args)>3: segs=[(int(args[3],16),0,len(e))]
else:
    phoff=struct.unpack('<I',e[28:32])[0]; phnum=struct.unpack('<H',e[44:46])[0]
    for i in range(phnum):
        t,off,va,pa,fs,ms=struct.unpack('<6I',e[phoff+i*32:phoff+i*32+24])
        if t==1 and fs: segs.append((va,off,fs))
md=capstone.Cs(capstone.CS_ARCH_MIPS,capstone.CS_MODE_MIPS64+capstone.CS_MODE_LITTLE_ENDIAN)
md.skipdata=True
for va,off,fs in segs:
    if va<=lo<va+fs:
        code=e[off+lo-va:off+min(hi,va+fs)-va]
        for ins in md.disasm(code,lo): print('%08x: %08x  %s %s'%(ins.address,struct.unpack('<I',ins.bytes[:4])[0] if len(ins.bytes)>=4 else 0,ins.mnemonic,ins.op_str))
