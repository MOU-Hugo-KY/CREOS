"""Géométrie originale, en coordonnées de jeu Y-up, façade +Z.
Ce module reste exécutable sans Blender pour auditer les budgets.
"""
import math, random
from dataclasses import dataclass, field

PALETTE = {
 'plaster':(.79,.69,.51), 'stone':(.53,.54,.48), 'wood':(.29,.17,.095),
 'wood_light':(.53,.34,.17), 'blue':(.20,.33,.43), 'red':(.57,.24,.16),
 'green':(.29,.40,.26), 'cream':(.89,.81,.61), 'iron':(.16,.18,.19),
 'orange':(.69,.39,.19), 'purple':(.49,.18,.72), 'window':(1,.64,.19),
 'leaves':(.27,.39,.18), 'flower':(.75,.34,.34), 'paper':(.80,.73,.54),
 'water':(.24,.48,.50), 'coal':(.11,.09,.08)
}
@dataclass
class Part:
 name: str
 pivot: tuple=(0,0,0)
 vertices: list=field(default_factory=list)
 faces: list=field(default_factory=list)
 materials: list=field(default_factory=list)
 smooth: list=field(default_factory=list)
 wind: bool=False
 def add(self,verts,faces,mat,smooth=False):
  offset=len(self.vertices); self.vertices.extend(verts)
  for face in faces:
   self.faces.append(tuple(offset+i for i in face)); self.materials.append(mat); self.smooth.append(smooth)
 def triangles(self): return sum(len(f)-2 for f in self.faces)
@dataclass
class Asset:
 name: str
 footprint: tuple
 parts: dict=field(default_factory=dict)
 theme: str=''
 layout: tuple=(0,0,0)
 yaw: float=0
 def part(self,name='Structure',pivot=(0,0,0),wind=False):
  if name not in self.parts: self.parts[name]=Part(name,pivot,wind=wind)
  return self.parts[name]
 def triangles(self): return sum(p.triangles() for p in self.parts.values())
 def bounds(self):
  vv=[v for p in self.parts.values() for v in p.vertices]
  return [[min(v[i] for v in vv) for i in range(3)],[max(v[i] for v in vv) for i in range(3)]]

def box(p,c,s,mat='wood',angle=0,axis='z'):
 x,y,z=c; a,b,d=[q/2 for q in s]; co,si=math.cos(angle),math.sin(angle)
 vv=[]
 for X,Y,Z in [(-a,-b,-d),(a,-b,-d),(a,b,-d),(-a,b,-d),(-a,-b,d),(a,-b,d),(a,b,d),(-a,b,d)]:
  if axis=='z': X,Y=X*co-Y*si,X*si+Y*co
  elif axis=='x': Y,Z=Y*co-Z*si,Y*si+Z*co
  else: X,Z=X*co+Z*si,-X*si+Z*co
  vv.append((x+X,y+Y,z+Z))
 p.add(vv,[(0,3,2,1),(4,5,6,7),(0,1,5,4),(3,7,6,2),(0,4,7,3),(1,2,6,5)],mat)

def rod(p,a,b,r,mat='wood',n=8,r2=None,smooth=True):
 v=[b[i]-a[i] for i in range(3)]; ln=math.sqrt(sum(q*q for q in v)); v=[q/ln for q in v]
 seed=(0,1,0) if abs(v[1])<.9 else (1,0,0)
 u=(v[1]*seed[2]-v[2]*seed[1],v[2]*seed[0]-v[0]*seed[2],v[0]*seed[1]-v[1]*seed[0]); un=math.sqrt(sum(q*q for q in u)); u=[q/un for q in u]
 w=(v[1]*u[2]-v[2]*u[1],v[2]*u[0]-v[0]*u[2],v[0]*u[1]-v[1]*u[0]); vv=[]
 for c,rr in [(a,r),(b,r if r2 is None else r2)]:
  for k in range(n):
   t=k*math.tau/n; vv.append(tuple(c[i]+rr*(u[i]*math.cos(t)+w[i]*math.sin(t)) for i in range(3)))
 faces=[tuple(reversed(range(n))),tuple(range(n,2*n))]
 faces += [(k,(k+1)%n,(k+1)%n+n,k+n) for k in range(n)]
 p.add(vv,faces,mat,smooth)

def ring(p,y,r,inner,h,mat='stone',n=24):
 vv=[(rr*math.cos(k*math.tau/n),yy,rr*math.sin(k*math.tau/n)) for yy,rr in [(y,r),(y,inner),(y+h,r),(y+h,inner)] for k in range(n)]
 ff=[]
 for k in range(n):
  j=(k+1)%n; ff += [(k,j,2*n+j,2*n+k),(n+j,n+k,3*n+k,3*n+j),(2*n+k,2*n+j,3*n+j,3*n+k),(j,k,n+k,n+j)]
 p.add(vv,ff,mat)

def gem(p,c,r,h,mat='purple',n=6):
 x,y,z=c; vv=[(x,y-h/2,z)]+[(x+r*math.cos(k*math.tau/n),y-h*.12,z+r*math.sin(k*math.tau/n)) for k in range(n)]+[(x+r*.72*math.cos(k*math.tau/n),y+h*.27,z+r*.72*math.sin(k*math.tau/n)) for k in range(n)]+[(x,y+h/2,z)]
 ff=[]
 for k in range(n):
  j=(k+1)%n; ff += [(0,1+j,1+k),(1+k,1+j,1+n+j,1+n+k),(1+n+k,1+n+j,len(vv)-1)]
 p.add(vv,ff,mat)

def marker(a,name,c): a.part(name,c)

def lantern(a,c,label):
 x,y,z=c; p=a.part(); rod(p,(x,y+.35,z-.15),(x,y+.35,z),.035,'iron',6)
 box(p,(x,y,z),(.30,.45,.25),'iron'); box(p,(x,y,z+.135),(.21,.32,.02),'window')
 for xx in [-.1,.1]: box(p,(x+xx,y,z+.15),(.025,.34,.035),'iron')
 marker(a,'Lumiere_'+label,(x,y,z+.25))

def window(a,x,y,z,w=.85,h=1.1,shutters=True):
 p=a.part(); box(p,(x,y,z),(w,h,.08),'wood'); box(p,(x,y,z+.048),(w-.16,h-.16,.025),'window')
 for xx in [-w/2,w/2,0]: box(p,(x+xx,y,z+.10),(.07,h+.12,.08),'wood_light')
 box(p,(x,y,z+.10),(w+.12,.07,.08),'wood_light'); box(p,(x,y-h/2-.06,z+.08),(w+.28,.13,.26),'stone')
 if shutters:
  for side in [-1,1]:
   xx=x+side*(w*.74); box(p,(xx,y,z),(w*.40,h,.1),'blue')
   for dy in [-h*.31,h*.31]: box(p,(xx,y+dy,z+.065),(w*.4,.07,.05),'iron')

def pot(a,x,y,z,size=.35,flowers=True):
 p=a.part(); rod(p,(x,y,z),(x,y+size*.7,z),size*.55,'red',8,r2=size*.7)
 for k in range(3):
  xx=x+(k-1)*size*.30; rod(p,(xx,y+size*.5,z),(xx,y+size*1.65,z),.025,'leaves',5)
  gem(p,(xx,y+size*1.25,z),size*.22,size*.35,'leaves',5)
  if flowers: gem(p,(xx,y+size*1.7,z),size*.14,size*.16,'flower',5)

def barrel(p,x,y,z,r=.35,h=.8):
 rod(p,(x,y,z),(x,y+h,z),r,'wood_light',10)
 for yy in [y+.12,y+h-.12]: ring_local(p,x,z,yy,r+.025,r-.02,.055,'iron',10)

def ring_local(p,x,z,y,r,inner,h,mat,n):
 tmp=Part('tmp'); ring(tmp,y,r,inner,h,mat,n)
 p.add([(v[0]+x,v[1],v[2]+z) for v in tmp.vertices],tmp.faces,mat)

def sign(a,x,y,z,kind):
 p=a.part(); box(p,(x,y,z),(1.35,.78,.15),'wood'); box(p,(x,y,z+.09),(1.16,.60,.04),'cream')
 if kind=='heroes':
  rod(p,(x-.38,y-.22,z+.13),(x+.38,y+.23,z+.13),.06,'iron',6)
  rod(p,(x+.38,y-.22,z+.13),(x-.38,y+.23,z+.13),.06,'iron',6)
 elif kind=='bakery': rod(p,(x-.36,y,z+.13),(x+.36,y,z+.13),.16,'orange',8)
 elif kind=='forge': box(p,(x,y-.03,z+.14),(.62,.15,.08),'iron'); box(p,(x,y+.10,z+.14),(.37,.15,.08),'iron')
 elif kind=='tavern': barrel(p,x-.14,y-.24,z+.12,.15,.44)
 elif kind=='fisher': gem(p,(x,y,z+.16),.23,.28,'blue',4); box(p,(x+.30,y,z+.16),(.18,.21,.045),'blue',math.pi/4)
 elif kind=='herbalist': rod(p,(x,y-.20,z+.15),(x,y+.2,z+.15),.035,'leaves',5); gem(p,(x-.13,y+.1,z+.15),.15,.23,'leaves',5)
 else: box(p,(x,y,z+.14),(.46,.46,.05),'blue',math.pi/4)

def flag(a,name,c,s=(.68,1.1),mat='red'):
 x,y,z=c; w,h=s; p=a.part('Drapeau_'+name,c,True)
 p.add([(x-w/2,y+h/2,z),(x+w/2,y+h/2,z),(x+w*.47,y-h*.35,z+.05),(x,y-h/2,z+.08),(x-w*.47,y-h*.35,z+.05)],[(0,1,2,3,4)],mat)
 rod(a.part(),(x-w*.65,y+h/2+.06,z),(x+w*.65,y+h/2+.06,z),.045,'iron',6)

def house(name,theme,w,d,stories,roofmat,seed,lod=False):
 rng=random.Random(seed); a=Asset(name,(w,d),theme=theme); p=a.part(); h=3.6 if stories==1 else 6.45
 box(p,(0,.17,0),(w,.34,d),'stone'); box(p,(0,h/2+.3,0),(w-.35,h-.3,d-.35),'plaster')
 # Continuous high-contrast timbers, corner ashlar and floor bands.
 for x in [-w/2+.22,0,w/2-.22]: box(p,(x,h/2+.25,d/2-.08),(.16,h-.2,.18),'wood')
 for x in [-w/2+.08,w/2-.08]:
  for zz in [-d/2+.18,d/2-.18]: box(p,(x,h/2+.25,zz),(.17,h-.2,.17),'wood')
  for yy in [.65,1.15,1.65]: box(p,(x,yy,d/2-.03),(.30,.36,.29),'stone')
 for yy in [.45,3.30,h]: box(p,(0,yy,0),(w,.17,d),'wood')
 z=d/2+.03; doorw=1.5
 box(p,(0,1.53,z),(doorw,2.9,.15),'wood'); box(p,(0,1.53,z+.09),(doorw-.18,2.70,.04),'wood_light')
 for yy in [.55,2.35]: box(p,(0,yy,z+.12),(doorw-.15,.10,.05),'iron')
 gem(p,(.46,1.45,z+.16),.055,.11,'iron',6); box(p,(0,.08,z+.35),(1.95,.16,.65),'stone')
 for x in [-w*.29,w*.29]: window(a,x,1.95,z,w=.83 if w<5 else 1.1)
 if stories==2:
  for x in [-w*.29,0,w*.29]: window(a,x,4.75,z,w=.95)
  for side in [-1,1]:
   rod(p,(side*w*.43,3.45,z+.06),(side*w*.10,5.9,z+.06),.07,'wood',4,smooth=False)
 # Gabled roof ridge runs along game Z.
 e=w/2+.32; rz=d/2+.34; ridge=h+2.00
 vv=[(-e,h,-rz),(e,h,-rz),(0,ridge,-rz),(-e,h,rz),(e,h,rz),(0,ridge,rz)]
 p.add(vv,[(0,2,1),(3,4,5)],'plaster')
 p.add(vv,[(0,3,5,2),(2,5,4,1)],roofmat)
 for side in [-1,1]:
  rod(p,(side*e,h,-rz),(side*e,h,rz),.11,'wood',6)
  rod(p,(side*e,h,rz),(0,ridge,rz),.10,'wood',6)
 rod(p,(0,ridge,-rz),(0,ridge,rz),.13,roofmat,8)
 if not lod:
  # Actual tiles concentrated at the silhouette and front edge.
  count=max(7,int(d/.35)); step=2*rz/count
  for side in [-1,1]:
   for k in range(count): box(p,(side*(e-.10),h+.04,-rz+(k+.5)*step),(.48,.13,step*.93),roofmat,axis='z',angle=-side*.28)
   for k in range(9):
    t=(k+.5)/9; x=side*e*t; y=ridge-2*t+.055
    box(p,(x,y,rz+.045),(.33,.11,.38),roofmat,axis='z',angle=-side*math.atan2(2,e))
 # Chimney with distinct open smoke attachment.
 cx=-w*.29; cy=ridge-.65
 box(p,(cx,cy, -d*.20),(.60,1.30,.62),'stone'); box(p,(cx,cy+.70,-d*.20),(.78,.16,.80),'stone'); box(p,(cx,cy+.79,-d*.20),(.43,.02,.43),'coal')
 marker(a,'Fumee_'+name,(cx,cy+.9,-d*.2))
 sign(a,0,3.10 if stories==1 else 3.45,z+.15,theme)
 lantern(a,(w*.43,2.75,z+.22),name)
 if not lod:
  for x in [-w*.31,w*.31]:
   box(p,(x,1.22,z+.17),(.85,.22,.35),'wood_light')
   for dx in [-.24,0,.24]: pot(a,x+dx,1.30,z+.19,.17)
  pot(a,-w*.40,.34,z+.24,.34)
 # Theme objects are part of the building, standalone reusable props are lot 3.
 if theme=='heroes': flag(a,'Chasseurs',(w*.42,4.7,z+.65),(.65,1.5),'blue')
 elif theme=='player': flag(a,'Joueur',(w*.37,3.95,z+.65),(.7,1.5),'red')
 elif theme=='bakery':
  box(p,(-1.4,.80,z+.40),(1.5,.15,.65),'wood_light')
  for dx in [-.43,0,.43]: rod(p,(-1.4+dx-.12,.96,z+.4),(-1.4+dx+.12,.96,z+.4),.10,'orange',6)
 elif theme=='forge':
  box(p,(1.5,.55,z+.48),(.65,1.0,.60),'wood'); box(p,(1.5,1.1,z+.48),(1.0,.26,.58),'iron'); box(p,(1.5,1.32,z+.48),(.55,.18,.45),'iron')
  box(p,(-1.6,1.0,z+.02),(.9,1.2,.6),'stone'); box(p,(-1.6,.9,z+.34),(.62,.65,.035),'coal'); gem(p,(-1.6,.7,z+.38),.18,.30,'orange',5)
 elif theme=='tavern':
  for x in [-1.65,-.92]: barrel(p,x,.34,z+.34,.32,.80)
 elif theme=='fisher':
  if not lod:
   for k in range(6):
    rod(p,(1.00+k*.14,.55,z+.18),(1.00+k*.14,2.10,z+.18),.012,'cream',4)
    rod(p,(1.00,.55+k*.25,z+.19),(1.7,.55+k*.25,z+.19),.012,'cream',4)
  barrel(p,-1.5,.34,z+.3,.33,.72)
 elif theme=='herbalist':
  for x in [-1.6,-1.1,1.4]: pot(a,x,.34,z+.35,.45)
 else:
  box(p,(1.4,1.10,z+.30),(1.0,.65,.10),'paper'); rod(p,(1.4,1.5,z+.32),(1.4,1.8,z+.32),.12,'blue',8)
 return a

def market(lod=False):
 a=Asset('Marche',(4,2),theme='market'); p=a.part()
 box(p,(0,.10,0),(4,.20,2),'stone'); box(p,(0,1.05,.30),(3.8,.17,1.10),'wood_light')
 for x in [-1.78,1.78]:
  for z in [-.7,.7]: box(p,(x,1.65,z),(.15,3.1,.15),'wood')
 for k in range(8):
  x=-1.75+k*.5; mat='red' if k%2==0 else 'cream'
  p.add([(x-.25,3.1,-1.0),(x+.25,3.1,-1.0),(x+.25,2.80,1.14),(x-.25,2.80,1.14)],[(0,3,2,1)],mat)
  box(p,(x,2.67,1.12),(.48,.26,.06),mat)
 for x in [-1.15,0,1.15]:
  box(p,(x,1.24,.30),(.95,.25,.77),'wood'); box(p,(x,1.39,.30),(.77,.04,.61),'coal')
  for k in range(3 if lod else 6):
   gem(p,(x+(k%3-1)*.22,1.49,.12+(k//3)*.28),.11,.20,['red','green','orange'][int((x+1.2)/1.15)],5)
 barrel(p,-1.5,.20,-.45,.26,.60); flag(a,'Marche',(0,3.45,-.5),(.6,.55),'red')
 lantern(a,(1.82,2.22,.86),'Marche'); return a

def hunts(lod=False):
 a=Asset('Table_Des_Chasses',(4,3),theme='hunts'); p=a.part(); box(p,(0,.10,0),(4,.20,3),'stone')
 box(p,(0,1.4,.45),(3.2,.18,1.35),'wood_light'); box(p,(0,1.51,.45),(2.20,.025,.95),'paper')
 for x in [-1.4,1.4]:
  for z in [0,.9]: box(p,(x,.78,z),(.16,1.2,.16),'wood')
 for x in [-1.7,1.7]: box(p,(x,1.7,-.95),(.19,3,.19),'wood')
 box(p,(0,2.50,-.97),(3.5,1.5,.14),'wood'); box(p,(0,2.50,-.87),(3.25,1.25,.04),'coal')
 for k in range(3 if lod else 5):
  x=-1.23+k*.61; box(p,(x,2.5,-.83),(.46,.75,.02),'paper',.04*(k-2)); gem(p,(x,2.93,-.80),.035,.065,'iron',4)
 # Map mountains, route and seal, without unreadable fake text.
 for x,z in [(-.6,.35),(.3,.65),(.6,.3)]: gem(p,(x,1.545,z),.12,.06,'green',4)
 for k in range(7): box(p,(-.85+k*.24,1.545,.48+math.sin(k)*.17),(.11,.01,.04),'red')
 flag(a,'Chasses',(1.65,3.55,-.97),(.65,1.0),'blue'); lantern(a,(-1.60,3.15,-.73),'Chasses'); return a

def altar(lod=False):
 a=Asset('Autel_Des_Reliques',(5,5),theme='altar'); p=a.part(); n=16 if lod else 32
 rod(p,(0,0,0),(0,.22,0),2.5,'stone',n,smooth=False); ring(p,.22,2.27,1.94,.47,'stone',n)
 rod(p,(0,.22,0),(0,.30,0),1.95,'blue',n,smooth=False)
 rod(p,(0,.3,0),(0,1.24,0),.40,'stone',8,smooth=False)
 for k in range(4):
  t=math.pi/4+k*math.pi/2; x,z=1.60*math.cos(t),1.60*math.sin(t)
  box(p,(x,1.41,z),(.43,2.36,.43),'stone'); box(p,(x,2.65,z),(.62,.15,.62),'stone')
  # Rune inlays on both exposed axes.
  for yy in [1.1,1.6,2.1]:
   box(p,(x,yy,z+.224),(.18,.07,.025),'purple',math.pi/4)
   box(p,(x+.224,yy,z),(.025,.18,.07),'purple',axis='x',angle=math.pi/4)
 crystal=a.part('Cristal',(0,2.28,0)); gem(crystal,(0,2.28,0),.44,1.62,'purple',6)
 marker(a,'Lumiere_Reliques',(0,2.28,0)); return a

HOUSE_SPECS=[('Maison_Boulangerie','bakery','orange'),('Maison_Forge','forge','blue'),('Maison_Taverne','tavern','red'),('Maison_Pecheur','fisher','green'),('Maison_Herboriste','herbalist','green'),('Maison_Cartographe','cartographer','red')]
def build_all(seed=731,lod=False):
 assets=[house('Loge_Des_Heros','heroes',7,4.5,2,'blue',seed,lod),house('Ma_Loge','player',6,4.5,1,'red',seed+1,lod),market(lod),hunts(lod),altar(lod)]
 for i,(name,theme,roof) in enumerate(HOUSE_SPECS): assets.append(house(name,theme,4.5,4,1 if i%3 else 2,roof,seed+10+i,lod))
 placements=[(-8.5,0,-11,14),(8.5,0,-11,-14),(-10,0,-.5,0),(8.8,0,.8,0),(0,0,-3,0),(-17,0,-7,20),(-17,2.4,-21,18),(-8,2.4,-23,8),(16,2.4,-23,-18),(8,4.8,-34,-8),(-8,4.8,-34,8)]
 for a,(x,y,z,angle) in zip(assets,placements): a.layout=(x,y,z); a.yaw=angle
 return assets

def audit(seed=731):
 full=build_all(seed); low=build_all(seed,True); report=[]
 for a,b in zip(full,low):
  lo,hi=a.bounds(); tris=a.triangles()
  assert tris<=6000,(a.name,tris)
  assert abs(lo[1])<1e-7,(a.name,'ground',lo)
  assert b.triangles()<tris,(a.name,'LOD does not simplify')
  for p in a.parts.values():
   assert len(p.faces)==len(p.materials)==len(p.smooth)
   for f in p.faces:
    assert len(f)>=3 and all(0<=i<len(p.vertices) for i in f)
  report.append({'name':a.name,'triangles':tris,'lod1_triangles':b.triangles(),'dimensions':[round(hi[i]-lo[i],4) for i in range(3)],'bounds_game':[lo,hi],'special_nodes':[n for n in a.parts if n!='Structure']})
 assert sum(a.triangles() for a in full)<80000
 return report
