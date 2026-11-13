"""Pose des atlas de refonte sans effacer les anciens dessins. Manifeste : {id:{atlas, attack, x_edges, y_edges, attack_x_edges, attack_y_edges}}.
Les images restent intactes ; seules les régions, durées et ancres sont écrites.
Usage : python tools/import_hero_redesigns.py manifeste.json
"""
import json, shutil, sys
from pathlib import Path
import numpy as np
from PIL import Image
ROOT=Path(__file__).resolve().parent.parent
STATES=['idle','walk','attack_1','attack_2','ultimate','skill','dodge','hurt','death']

def measure(image,region):
 x,y,w,h=region
 a=np.array(image)[y:y+h,x:x+w,3]>=128
 ys,xs=np.where(a)
 if not len(xs):raise ValueError(f'Case vide : {region}')
 bottom=int(ys.max())+1
 feet=xs[ys>=bottom-5]
 return [round(float(feet.mean()),2),bottom],[int(xs.min()),int(ys.min()),int(xs.max()-xs.min()+1),int(ys.max()-ys.min()+1)]

def apply(hero,entry):
 folder=ROOT/'assets/anim/pixel'/hero;path=folder/'sheet.json';sheet=json.loads(path.read_text())
 original=sheet['anims'].get('idle_original',sheet['anims']['idle'])
 ref=Image.open(folder/original['frames'][0][0]).convert('RGBA')
 if len(original['frames'][0])>2:
  old=original['frames'][0][2];old_height=old.get('bounds',[0,0,0,0])[3]
 else:old_height=measure(ref,[0,0,*ref.size])[1][3]
 for key in STATES:
  sheet['anims'].setdefault(key+'_original',sheet['anims'][key])
 for mode,src in [('atlas',entry['atlas']),('attack',entry['attack'])]+([('death',entry['death'])] if entry.get('death') else []):
  src=Path(src)
  if not src.is_absolute():src=ROOT/src
  image=Image.open(src).convert('RGBA');name=f'{hero}_redesign_{mode}.png'
  if src.resolve()!=(folder/name).resolve():shutil.copyfile(src,folder/name)
  xe=entry['x_edges' if mode=='atlas' else mode+'_x_edges'];ye=entry['y_edges' if mode=='atlas' else mode+'_y_edges']
  count=len(xe)-1
  first=[xe[0],ye[0],xe[1]-xe[0],ye[1]-ye[0]]
  factor=sheet['scale']*old_height/measure(image,first)[1][3]
  states=STATES if mode=='atlas' else (['attack_1'] if mode=='attack' else ['death'])
  for row,state in enumerate(states):
   old=sheet['anims'][state+'_original'];total=sum(f[1] for f in old['frames']);frames=[]
   for index in range(count if mode=='atlas' else 16):
    r,c=(row,index) if mode=='atlas' else divmod(index,4)
    region=[xe[c],ye[r],xe[c+1]-xe[c],ye[r+1]-ye[r]]
    anchor,bounds=measure(image,region)
    frames.append([name,round(total/(count if mode=='atlas' else 16),6),{'region':region,'anchor':anchor,'scale':round(factor,6),'bounds':bounds}])
   sheet['anims'][state]={'loop':old['loop'],'frames':frames,'hit_frame':None if old.get('hit_frame') is None else (8 if mode=='attack' else count//2)}
 sheet['redesign']=True;path.write_text(json.dumps(sheet,ensure_ascii=False,indent=1)+'\n')
 print(hero,len(sheet['anims']['attack_1']['frames']),'poses attaque, refonte des 9 mouvements')

if __name__=='__main__':
 for hero,entry in json.loads(Path(sys.argv[1]).read_text()).items():apply(hero,entry)
