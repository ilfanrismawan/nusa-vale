import numpy as np
from PIL import Image
D='/mnt/user-data/uploads/nusa-vale/assets/farm_rpg/tileset/ext/'
def load(n): return Image.open(D+n).convert('RGBA')
def cellbox(c,r): return (c*16,r*16,c*16+16,r*16+16)
def nonempty(im,c,r):
    b=cellbox(c,r)
    if b[2]>im.width or b[3]>im.height: return False
    return (np.array(im.crop(b))[...,3]>0).any()

def remap_cliff():
    sp=load('Tileset Grass Cliff Tileset Spring.png'); wi=load('Tileset Grass Cliff Tileset Winter.png')
    out=Image.new('RGBA',sp.size,(0,0,0,0)); log=[]
    for r in range(sp.height//16):
        for c in range(sp.width//16):
            if not nonempty(sp,c,r): continue
            rr=r if r<6 else r-6; off=0 if r<6 else 12
            src=None
            if c<12:
                src=(c+off,rr)
                if rr==4 and 1<=c<=4 and not nonempty(wi,*src): src=(min(c,3)+off,5)
                elif rr==5 and c>=4: src=(1+(c%2)+off,5)
            elif c<=16 and rr in (0,1):            # mulut gua
                src=((6 if c==12 else 7)+off,4+rr)
            elif rr in (2,3):                      # tebing berair
                src=(9+off, 4)
            if src is None or not nonempty(wi,*src):
                out.paste(sp.crop(cellbox(c,r)),(c*16,r*16)); log.append(('spring',c,r)); continue
            out.paste(wi.crop(cellbox(*src)),(c*16,r*16))
    return out,log

def remap_water():
    sp=load('Tileset Grass Water Spring.png'); wi=load('Tileset Grass Water Winter.png')
    out=Image.new('RGBA',sp.size,(0,0,0,0)); log=[]
    for r in range(sp.height//16):
        for c in range(sp.width//16):
            if not nonempty(sp,c,r): continue
            bc,lc=divmod(c,12); V,lr=divmod(r,8)
            src=(lc+12*(bc%2), lr+12*V)
            if not nonempty(wi,*src):
                out.paste(sp.crop(cellbox(c,r)),(c*16,r*16)); log.append(('spring',c,r)); continue
            out.paste(wi.crop(cellbox(*src)),(c*16,r*16))
    return out,log
if __name__=='__main__':
    for fn,name in [(remap_cliff,'Tileset Grass Cliff Tileset Winter.png'),(remap_water,'Tileset Grass Water Winter.png')]:
        im,log=fn(); im.save('/tmp/claude-0/remap/'+name); print(name,im.size,'fallback cells:',len(log),log[:40])
