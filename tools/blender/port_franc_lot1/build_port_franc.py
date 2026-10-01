#!/usr/bin/env python3
"""CREOS / Port-Franc — lot 1. Lancer avec Blender --background --python.
Un mode --audit sans Blender vérifie la géométrie, pas la cuisson ni l'import.
"""
from pathlib import Path
import sys, json, argparse, traceback
ROOT=Path(__file__).resolve().parent
if str(ROOT) not in sys.path: sys.path.insert(0,str(ROOT))
from modules.buildings import build_all,audit

# PARAMÈTRES UTILISATEUR : pas de module à installer dans Blender.
CONFIG={
 'seed':731,
 'vegetation_density':1.0, # réservé au lot 2 ; ce lot n'inclut que les jardinières
 'texture_size':2048,
 'bake_samples':32,
 'render_samples':48,
 'lod_ratio':.62,
 'output_folder':'Port_Franc_Lot1_Genere',
}

def arguments():
 parser=argparse.ArgumentParser(description=__doc__)
 parser.add_argument('--audit',action='store_true')
 parser.add_argument('--no-previews',action='store_true')
 parser.add_argument('--output',type=Path)
 parser.add_argument('--texture-size',type=int,choices=[512,1024,2048,4096])
 parser.add_argument('--seed',type=int)
 args=sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else sys.argv[1:] if '--audit' in sys.argv else []
 return parser.parse_args(args)

def main():
 args=arguments(); cfg=CONFIG.copy()
 if args.texture_size: cfg['texture_size']=args.texture_size
 if args.seed is not None: cfg['seed']=args.seed
 report=audit(cfg['seed'])
 if args.audit:
  print(json.dumps({'status':'geometry_audit_passed','total_triangles':sum(r['triangles'] for r in report),'assets':report},ensure_ascii=False,indent=2)); return
 try: import bpy
 except ImportError: raise SystemExit('Lancez ce script avec Blender, et non le Python Windows. Le mode --audit fonctionne sans Blender.')
 from modules import blender_pipeline as bp
 out=(args.output or ROOT/cfg['output_folder']).resolve(); out.mkdir(parents=True,exist_ok=True)
 (out/'GLB').mkdir(exist_ok=True); (out/'LOD').mkdir(exist_ok=True)
 # The background process opens a fresh scene. No user's .blend is modified.
 bpy.ops.object.select_all(action='SELECT'); bpy.ops.object.delete(use_global=False)
 materials={name:bp.material_source(name) for name in bp.PALETTE}
 assets=build_all(cfg['seed']); roots=[]; meshes=[]
 for index,a in enumerate(assets):
  print('CONSTRUCTION',a.name,a.triangles(),'triangles',flush=True)
  root,objects=bp.materialize(a,materials); bp.unwrap(objects,index,cfg['texture_size']); roots.append(root); meshes.extend(objects)
 # Separate buildings during AO baking: they must never overlap at the origin.
 for index,root in enumerate(roots): root.location.x=index*100.0
 images=bp.bake(meshes,materials,cfg,out)
 for root in roots: root.location=(0,0,0)
 final=bp.export_materials(images); bp.assign_materials(meshes,final)
 manifest={'lot':1,'generator':'build_port_franc.py','blender_version':bpy.app.version_string,'config':cfg,'maps':['BaseColor','Normal','ORM'],'assets':[]}
 layout={'coordinates':'Godot Y-up, metres, façade +Z','lot':1,'objects':[],'camera':{'position':[0,11,21],'target':[0,5,-10],'vertical_fov_degrees':42}}
 for root,a in zip(roots,assets):
  record=bp.export(root,out/'GLB'/(a.name+'.glb'))
  low=bp.lod_copy(root,cfg['lod_ratio']); low_report=bp.export(low,out/'LOD'/(a.name+'_LOD1.glb'))
  assert low_report['triangles']<record['triangles'],(a.name,'LOD non simplifié')
  for o in reversed(bp.descendants(low)): bpy.data.objects.remove(o,do_unlink=True)
  lo,hi=a.bounds(); dim=[round(hi[i]-lo[i],4) for i in range(3)]
  record.update(file='GLB/'+a.name+'.glb',lod1_file='LOD/'+a.name+'_LOD1.glb',lod1_triangles=low_report['triangles'],dimensions=dim,base_footprint=a.footprint,origin=[0,0,0],theme=a.theme)
  manifest['assets'].append(record)
  entry={'name':a.name,'file':record['file'],'lod1_file':record['lod1_file'],'position':a.layout,'rotation_degrees':[0,a.yaw,0],'scale':[1,1,1],'special_nodes':[{'name':p.name,'local_position':p.pivot} for p in a.parts.values() if p.name!='Structure']}
  if len(layout['objects'])<5: entry['click_box']={'space':'local','center':[(lo[i]+hi[i])/2 for i in range(3)],'size':dim,'shape':'BoxShape3D','purpose':'clicking only, not navigation collision'}
  layout['objects'].append(entry)
 total=sum(r['triangles'] for r in manifest['assets']); assert total<=80000
 manifest['total_triangles_lot1']=total; manifest['remaining_visible_budget']=80000-total
 (out/'Manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2),encoding='utf8')
 (out/'Layout_Lot1.json').write_text(json.dumps(layout,ensure_ascii=False,indent=2),encoding='utf8')
 (out/'Validation.json').write_text(json.dumps({'geometry':'passed','glb_structure':'passed','cycles_bake':'completed','game_import':'not_tested','asset_count':len(assets),'triangle_limit':6000,'total':total},indent=2),encoding='utf8')
 if not args.no_previews: bp.previews(roots,assets,cfg,out)
 else: bpy.ops.wm.save_as_mainfile(filepath=str(out/'Port_Franc_Lot1.blend'))
 print('TERMINE :',out,flush=True)

if __name__=='__main__':
 try: main()
 except Exception:
  traceback.print_exc()
  # Non-zero return even when Blender itself would suppress a Python exception.
  sys.stdout.flush(); sys.stderr.flush()
  raise
