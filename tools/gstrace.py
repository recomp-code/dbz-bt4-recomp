#!/usr/bin/env python3
# gstrace.py <console.log>: groups the F9 GS register trace into draw states
import sys,re,collections
regs={}; groups=collections.OrderedDict(); cur=None
order=[]
def key():
    p=regs.get(0,0); ctx=(p>>9)&1
    g=lambda a,b: regs.get(b if ctx else a,0)
    return (p&0x7ff, g(0x4c,0x4d), g(0x4e,0x4f), g(0x06,0x07), g(0x47,0x48), g(0x42,0x43), g(0x4a,0x4b), regs.get(0x3b,0), g(0x08,0x09), g(0x14,0x15))
for line in open(sys.argv[1]):
    if not line.startswith('[trace]'): continue
    m=re.match(r'\[trace\] ([0-9a-f]{2}) ([0-9a-f]{16})',line)
    if m:
        r=int(m.group(1),16); v=int(m.group(2),16)
        if r in (4,5,0xc,0xd):
            k=key(); groups[k]=groups.get(k,0)+1
            if not order or order[-1][0]!=k: order.append([k,0])
            order[-1][1]+=1
        else: regs[r]=v
        continue
    m=re.match(r'\[trace\]   \.\.\. (\d+) vertex',line)
    if m:
        k=key(); n=int(m.group(1))//2; groups[k]=groups.get(k,0)+n
        if order and order[-1][0]==k: order[-1][1]+=n
PSM={0:'CT32',1:'CT24',2:'CT16',0xa:'CT16S',0x13:'T8',0x14:'T4',0x1b:'T8H',0x24:'T4HL',0x2c:'T4HH',0x30:'Z32',0x31:'Z24',0x32:'Z16',0x3a:'Z16S'}
def fmt(k):
    prim,frame,zbuf,tex0,test,alpha,fba,texa,clamp,tex1=k
    fbp=(frame&0x1ff)*0x800*4; fbw=((frame>>16)&0x3f)*64; fpsm=(frame>>24)&0x3f; fbmsk=frame>>32
    zbp=(zbuf&0x1ff)*0x800*4; zpsm=(zbuf>>24)&0xf; zmsk=(zbuf>>32)&1
    tbp=(tex0&0x3fff)*256; tbw=((tex0>>14)&0x3f)*64; tpsm=(tex0>>20)&0x3f; tw=1<<((tex0>>26)&0xf); th=1<<((tex0>>30)&0xf); tcc=(tex0>>34)&1; tfx=(tex0>>35)&3; cbp=((tex0>>37)&0x3fff)*256; cpsm=(tex0>>51)&0xf; csm=(tex0>>55)&1; cld=(tex0>>61)&7
    ate=test&1; atst=(test>>1)&7; aref=(test>>4)&0xff; afail=(test>>12)&3; date=(test>>14)&1; zte=(test>>16)&1; ztst=(test>>17)&3
    pt=prim&7; tme=(prim>>4)&1; abe=(prim>>6)&1; ctxt=(prim>>9)&1
    a=alpha&3;b=(alpha>>2)&3;c=(alpha>>4)&3;d=(alpha>>6)&3;fix=(alpha>>32)&0xff
    s='prim %d tme%d abe%d ctx%d | FB %x w%d %s msk%08x | Z %x %s zmsk%d | '%(pt,tme,abe,ctxt,fbp,fbw,PSM.get(fpsm,hex(fpsm)),fbmsk,zbp,PSM.get(0x30|zpsm,hex(zpsm)),zmsk)
    if tme: s+='TEX %x w%d %s %dx%d tcc%d tfx%d cbp %x cpsm%x csm%d cld%d | '%(tbp,tbw,PSM.get(tpsm,hex(tpsm)),tw,th,tcc,tfx,cbp,cpsm,csm,cld)
    s+='ATE%d atst%d aref%x afail%d DATE%d ZTE%d ztst%d | A(%d%d%d%d fix%x) FBA%d TEXA %x'%(ate,atst,aref,afail,date,zte,ztst,a,b,c,d,fix,fba&1,texa)
    return s
mode=sys.argv[2] if len(sys.argv)>2 else 'groups'
if mode=='groups':
    for k,n in sorted(groups.items(),key=lambda x:-x[1]): print('%6d  %s'%(n,fmt(k)))
else:
    for k,n in order: print('%6d  %s'%(n,fmt(k)))
