"""Aperçus géométriques CPU ; ne représentent pas un bake/rendu Blender.
Optionnel : Python + NumPy + Pillow. Non requis pour lancer build_port_franc.
"""
from pathlib import Path
import sys, math
import numpy as np
from PIL import Image, ImageDraw, ImageFont
from .buildings import build_all,PALETTE

def font(size):
 for f in ['/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf','C:/Windows/Fonts/arial.ttf']:
  if Path(f).exists(): return ImageFont.truetype(f,size)
 return ImageFont.load_default()

def render(asset,size=580):
 low,high=asset.bounds(); span=max(high[i]-low[i] for i in range(3)); target=np.array([0,high[1]*.46,0])
 view=np.array([4.,2.7,6.]); view/=np.linalg.norm(view); right=np.cross([0,1,0],view); right/=np.linalg.norm(right); up=np.cross(view,right)
 light=np.array([-2.,5.,6.]); light/=np.linalg.norm(light)
 img=np.full((size,size,3),[230,225,211],dtype=np.uint8); zz=np.full((size,size),-1e9)
 scale=size/(span*1.58)
 for part in asset.parts.values():
  for face,mat in zip(part.faces,part.materials):
   for k in range(1,len(face)-1):
    pts=np.array([part.vertices[j] for j in [face[0],face[k],face[k+1]]]); normal=np.cross(pts[1]-pts[0],pts[2]-pts[0]); ln=np.linalg.norm(normal)
    if ln<1e-8:continue
    normal/=ln; q=pts-target; xs=q@right*scale+size/2; ys=-q@up*scale+size/2; depths=q@view
    xmin=max(0,int(min(xs))); xmax=min(size-1,int(max(xs))+1); ymin=max(0,int(min(ys))); ymax=min(size-1,int(max(ys))+1)
    if xmin>xmax or ymin>ymax:continue
    den=(ys[1]-ys[2])*(xs[0]-xs[2])+(xs[2]-xs[1])*(ys[0]-ys[2])
    if abs(den)<1e-8:continue
    X,Y=np.meshgrid(np.arange(xmin,xmax+1)+.5,np.arange(ymin,ymax+1)+.5)
    a=((ys[1]-ys[2])*(X-xs[2])+(xs[2]-xs[1])*(Y-ys[2]))/den
    b=((ys[2]-ys[0])*(X-xs[2])+(xs[0]-xs[2])*(Y-ys[2]))/den; c=1-a-b
    depth=a*depths[0]+b*depths[1]+c*depths[2]; zbuf=zz[ymin:ymax+1,xmin:xmax+1]
    mask=(a>=-1e-7)&(b>=-1e-7)&(c>=-1e-7)&(depth>zbuf)
    shade=.57+.43*max(0,float(normal@light)); shade=1.10 if mat in ['window','purple'] else shade
    color=np.clip(np.array(PALETTE[mat])*255*shade,0,255).astype(np.uint8)
    img[ymin:ymax+1,xmin:xmax+1][mask]=color; zbuf[mask]=depth[mask]
 out=Image.fromarray(img); draw=ImageDraw.Draw(out); draw.text((12,size-22),'Volumes seuls — sans cuisson Blender',font=font(12),fill=(90,82,72)); return out

def main():
 root=Path(__file__).resolve().parents[1]; folder=root/'previews'; folder.mkdir(exist_ok=True)
 assets=build_all(); sheet=Image.new('RGB',(1500,1850),(243,239,228)); draw=ImageDraw.Draw(sheet)
 draw.text((36,20),'PORT-FRANC  /  LOT 1',font=font(36),fill=(67,53,42))
 draw.text((36,72),'Prévisualisation géométrique • textures procédurales et cuisson à lancer dans Blender',font=font(17),fill=(100,91,79))
 for i,a in enumerate(assets):
  im=render(a); im.save(folder/(a.name+'_Geometrie.png')); x=(i%3)*500; y=116+(i//3)*428
  sheet.paste(im.resize((480,380)),(x+10,y)); label=a.name.replace('Maison_','').replace('_',' ')
  draw.text((x+24,y+380),label,font=font(19),fill=(65,54,43)); draw.text((x+24,y+404),str(a.triangles())+' triangles',font=font(13),fill=(100,90,78))
 sheet.save(root/'Apercu_Geometrie_Lot1.png')
if __name__=='__main__':main()
