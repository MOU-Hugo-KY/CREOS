"""Adaptateur Blender : matériaux procéduraux, UV, cuisson Cycles, GLB, rendus.
À importer uniquement dans Blender. Pas d'addon tiers.
"""
import bpy, math, json, struct, array
from pathlib import Path
from mathutils import Vector
from .buildings import PALETTE

def game_to_blender(v): return (v[0],-v[2],v[1])
def select(objects):
 bpy.ops.object.select_all(action='DESELECT')
 for o in objects: o.select_set(True)
 if objects: bpy.context.view_layer.objects.active=objects[0]

def material_source(name):
 m=bpy.data.materials.new('Source_'+name); m.use_nodes=True
 n=m.node_tree.nodes; l=m.node_tree.links; bs=n.get('Principled BSDF')
 color=PALETTE[name]; bs.inputs['Roughness'].default_value=.84
 bs.inputs['Metallic'].default_value=.65 if name=='iron' else 0
 tex=n.new('ShaderNodeTexNoise'); tex.inputs['Scale'].default_value=3.5; tex.inputs['Detail'].default_value=2.3; tex.inputs['Roughness'].default_value=.7
 coord=n.new('ShaderNodeNewGeometry'); l.new(coord.outputs['Position'],tex.inputs['Vector'])
 ramp=n.new('ShaderNodeValToRGB'); ramp.color_ramp.elements[0].position=.12; ramp.color_ramp.elements[1].position=.88
 ramp.color_ramp.elements[0].color=tuple(c*.80 for c in color)+(1,)
 ramp.color_ramp.elements[1].color=tuple(min(c*1.12,1) for c in color)+(1,)
 l.new(tex.outputs['Fac'],ramp.inputs['Fac']); l.new(ramp.outputs['Color'],bs.inputs['Base Color'])
 if name in ['blue','red','green','orange']:
  tiles=n.new('ShaderNodeTexBrick'); tiles.inputs['Scale'].default_value=2.7; tiles.inputs['Mortar Size'].default_value=.018; tiles.inputs['Brick Width'].default_value=.54; tiles.inputs['Row Height'].default_value=.26
  tiles.inputs['Color1'].default_value=tuple(c*.88 for c in color)+(1,); tiles.inputs['Color2'].default_value=tuple(min(c*1.1,1) for c in color)+(1,); tiles.inputs['Mortar'].default_value=tuple(c*.55 for c in color)+(1,)
  l.new(coord.outputs['Position'],tiles.inputs['Vector']); l.new(tiles.outputs['Color'],bs.inputs['Base Color'])
 if name in ['wood','wood_light','blue','red','green','orange','stone','plaster']:
  detail=n.new('ShaderNodeTexNoise'); detail.inputs['Scale'].default_value=22; detail.inputs['Detail'].default_value=1.8
  scale=n.new('ShaderNodeVectorMath'); scale.operation='MULTIPLY'; scale.inputs[1].default_value=(1,10,10) if name.startswith('wood') else (1,1,1)
  l.new(coord.outputs['Position'],scale.inputs[0]); l.new(scale.outputs['Vector'],detail.inputs['Vector'])
  bump=n.new('ShaderNodeBump'); bump.inputs['Strength'].default_value=.18; bump.inputs['Distance'].default_value=.018
  l.new(detail.outputs['Fac'],bump.inputs['Height']); l.new(bump.outputs['Normal'],bs.inputs['Normal'])
 return m

def materialize(asset,materials):
 root=bpy.data.objects.new(asset.name,None); bpy.context.collection.objects.link(root)
 root['front_axis']='+Z'; root['up_axis']='+Y'; root['meters_per_unit']=1.; root['theme']=asset.theme
 objects=[]
 for part in asset.parts.values():
  if not part.vertices:
   o=bpy.data.objects.new(part.name,None); bpy.context.collection.objects.link(o); o.empty_display_size=.18
  else:
   mesh=bpy.data.meshes.new(asset.name+'_'+part.name+'_Mesh')
   mesh.from_pydata([game_to_blender(tuple(v[i]-part.pivot[i] for i in range(3))) for v in part.vertices],[],part.faces); mesh.update()
   o=bpy.data.objects.new(part.name,mesh); bpy.context.collection.objects.link(o)
   keys=list(dict.fromkeys(part.materials))
   for k in keys: mesh.materials.append(materials[k])
   for poly,k,smooth in zip(mesh.polygons,part.materials,part.smooth): poly.material_index=keys.index(k); poly.use_smooth=smooth
   if part.wind:
    attr=mesh.color_attributes.new(name='Wind',type='FLOAT_COLOR',domain='POINT')
    ys=[v[1] for v in part.vertices]; lo,hi=min(ys),max(ys)
    for data,y in zip(attr.data,ys): data.color=(1-(y-lo)/max(hi-lo,.001),0,0,1)
   objects.append(o)
  o.parent=root; o.location=game_to_blender(part.pivot)
  o['source_name']=part.name
 return root,objects

def unwrap(objects,index,resolution):
 # 4 x 3 cells. Each object's charts are disjoint within its building's cell.
 col,row=index%4,index//4; cellw,cellh=1/4,1/3; pad=8/resolution
 extras=[o for o in objects if o.name.split('.')[0]!='Structure']; structure=objects[0]
 for o in objects:
  select([o]); bpy.ops.object.mode_set(mode='EDIT'); bpy.ops.mesh.select_all(action='SELECT')
  if not o.data.uv_layers: o.data.uv_layers.new(name='UVMap')
  o.data.uv_layers.active_index=0
  bpy.ops.uv.smart_project(angle_limit=math.radians(66),island_margin=.018,area_weight=.3,correct_aspect=True,scale_to_bounds=True)
  bpy.ops.object.mode_set(mode='OBJECT')
  uv=o.data.uv_layers.active; uv.name='UVMap'
  if o==structure: x,y,w,h=col*cellw,row*cellh,cellw*.83,cellh
  else:
   j=extras.index(o); x,y,w,h=col*cellw+cellw*.85,row*cellh+j*cellh/max(len(extras),1),cellw*.15,cellh/max(len(extras),1)
  for d in uv.data: d.uv=(x+pad+d.uv.x*(w-2*pad),y+pad+d.uv.y*(h-2*pad))
  # A second independent chart pack over the entire mesh, for Godot lightmaps.
  o.data.uv_layers.new(name='UV2'); o.data.uv_layers.active_index=1
  select([o]); bpy.ops.object.mode_set(mode='EDIT'); bpy.ops.mesh.select_all(action='SELECT')
  bpy.ops.uv.smart_project(angle_limit=math.radians(66),island_margin=.035,area_weight=.3,correct_aspect=True,scale_to_bounds=True)
  bpy.ops.object.mode_set(mode='OBJECT')
  o.data.uv_layers.active_index=0; o.data.uv_layers[0].active_render=True

def image(name,size,color,noncolor=False):
 img=bpy.data.images.new(name,width=size,height=size,alpha=False); img.generated_color=(*color,1)
 img.colorspace_settings.name='Non-Color' if noncolor else 'sRGB'; return img

def bake(objects,materials,cfg,out):
 scene=bpy.context.scene; scene.render.engine='CYCLES'; scene.cycles.device='CPU'; scene.cycles.samples=cfg['bake_samples']
 scene.render.bake.margin=4; scene.render.bake.use_clear=True
 imgs={'BaseColor':image('Atlas_Batiments_BaseColor',cfg['texture_size'],(.5,.5,.5)),
       'Normal':image('Atlas_Batiments_Normal',cfg['texture_size'],(.5,.5,1),True),
       'AO':image('Atlas_Batiments_AO',cfg['texture_size'],(1,1,1),True),
       'Roughness':image('Atlas_Batiments_Roughness',cfg['texture_size'],(.8,.8,.8),True),
       'Metallic':image('Atlas_Batiments_Metallic',cfg['texture_size'],(0,0,0),True)}
 targets={}
 for key,m in materials.items():
  node=m.node_tree.nodes.new('ShaderNodeTexImage'); node.name='Bake_Target'; targets[key]=node
 def run(kind,key,**kwargs):
  for k,m in materials.items():
   targets[k].image=imgs[key]; m.node_tree.nodes.active=targets[k]; targets[k].select=True
  select(objects); print('BAKE',key,flush=True)
  bpy.ops.object.bake(type=kind,use_clear=True,margin=4,**kwargs)
 run('DIFFUSE','BaseColor',pass_filter={'COLOR'})
 run('NORMAL','Normal',normal_space='TANGENT')
 run('AO','AO'); run('ROUGHNESS','Roughness')
 # Metallic is a material scalar, baked as emission to preserve its mask.
 restored=[]
 for k,m in materials.items():
  nodes,links=m.node_tree.nodes,m.node_tree.links; output=nodes.get('Material Output'); old=output.inputs['Surface'].links[0].from_socket
  emit=nodes.new('ShaderNodeEmission'); emit.inputs['Color'].default_value=(.65,.65,.65,1) if k=='iron' else (0,0,0,1)
  links.new(emit.outputs[0],output.inputs['Surface']); restored.append((m,output,old,emit))
 run('EMIT','Metallic')
 for m,output,old,emit in restored: m.node_tree.links.new(old,output.inputs['Surface']); m.node_tree.nodes.remove(emit)
 # Blender ships NumPy. Pack R=AO, G=roughness, B=metallic without colour transform.
 import numpy as np
 count=cfg['texture_size']**2*4; channels=[]
 for key in ['AO','Roughness','Metallic']:
  vals=np.empty(count,dtype=np.float32); imgs[key].pixels.foreach_get(vals); channels.append(vals.reshape(-1,4)[:,0].copy())
 orm=image('Atlas_Batiments_ORM',cfg['texture_size'],(1,.8,0),True)
 packed=np.ones((count//4,4),dtype=np.float32)
 for k,v in enumerate(channels): packed[:,k]=v
 orm.pixels.foreach_set(packed.ravel()); orm.update(); imgs['ORM']=orm
 keep={k:imgs[k] for k in ['BaseColor','Normal','ORM']}
 folder=out/'textures'; folder.mkdir(exist_ok=True)
 for key,img in keep.items():
  img.filepath_raw=str(folder/(img.name+'.png')); img.file_format='PNG'; img.save(); img.pack()
 return keep

def export_materials(images):
 result={}
 for label,emission in [('Atlas_Batiments',None),('Emissif_Fenetres',(1,.57,.16,1)),('Emissif_Cristaux',(.47,.12,.85,1))]:
  m=bpy.data.materials.new(label); m.use_nodes=True; m.use_backface_culling=False
  n,l=m.node_tree.nodes,m.node_tree.links; bs=n.get('Principled BSDF')
  uv=n.new('ShaderNodeUVMap'); uv.uv_map='UVMap'
  tex={}
  for k,img in images.items():
   t=n.new('ShaderNodeTexImage'); t.image=img; t.interpolation='Linear'; l.new(uv.outputs['UV'],t.inputs['Vector']); tex[k]=t
  l.new(tex['BaseColor'].outputs['Color'],bs.inputs['Base Color'])
  normal=n.new('ShaderNodeNormalMap'); normal.uv_map='UVMap'; l.new(tex['Normal'].outputs['Color'],normal.inputs['Color']); l.new(normal.outputs['Normal'],bs.inputs['Normal'])
  sep=n.new('ShaderNodeSeparateColor'); sep.mode='RGB'; l.new(tex['ORM'].outputs['Color'],sep.inputs['Color'])
  l.new(sep.outputs['Green'],bs.inputs['Roughness']); l.new(sep.outputs['Blue'],bs.inputs['Metallic'])
  group=bpy.data.node_groups.get('glTF Material Output')
  if group is None:
   group=bpy.data.node_groups.new('glTF Material Output','ShaderNodeTree'); group.interface.new_socket(name='Occlusion',in_out='INPUT',socket_type='NodeSocketFloat')
  oc=n.new('ShaderNodeGroup'); oc.node_tree=group; l.new(sep.outputs['Red'],oc.inputs['Occlusion'])
  if emission:
   bs.inputs['Emission Color'].default_value=emission; bs.inputs['Emission Strength'].default_value=2.2
  result[label]=m
 return result

def assign_materials(objects,final):
 for o in objects:
  old=[m.name.removeprefix('Source_') for m in o.data.materials]; indices=[p.material_index for p in o.data.polygons]
  o.data.materials.clear()
  labels=['Atlas_Batiments','Emissif_Fenetres','Emissif_Cristaux']
  for label in labels: o.data.materials.append(final[label])
  for p,k in zip(o.data.polygons,indices): p.material_index=1 if old[k]=='window' else 2 if old[k]=='purple' else 0

def descendants(root): return [root]+list(root.children_recursive)

def glb_report(path):
 data=path.read_bytes(); magic,version,total=struct.unpack_from('<4sII',data)
 assert magic==b'glTF' and version==2 and total==len(data)
 n,kind=struct.unpack_from('<II',data,12); doc=json.loads(data[20:20+n]); tri=0
 for mesh in doc.get('meshes',[]):
  for p in mesh['primitives']:
   assert 'TEXCOORD_0' in p['attributes'] and 'TEXCOORD_1' in p['attributes']
   count=doc['accessors'][p['indices']]['count']; assert count%3==0; tri+=count//3
 for img in doc.get('images',[]): assert 'bufferView' in img,'texture externe'
 return {'triangles':tri,'materials':[m['name'] for m in doc.get('materials',[])], 'nodes':[n['name'].split('.')[0] for n in doc.get('nodes',[])], 'embedded_images':len(doc.get('images',[])), 'bytes':len(data)}

def export(root,path):
 select(descendants(root))
 # Filter optional arguments through RNA for Blender minor-version compatibility.
 options=dict(filepath=str(path),export_format='GLB',use_selection=True,export_yup=True,export_texcoords=True,export_normals=True,export_materials='EXPORT',export_extras=True,export_cameras=False,export_lights=False,export_animations=False,export_apply=False,export_image_format='AUTO',export_keep_originals=False)
 allowed=set(bpy.ops.export_scene.gltf.get_rna_type().properties.keys()); options={k:v for k,v in options.items() if k in allowed}
 bpy.ops.export_scene.gltf(**options)
 # Names are repaired from extras because Blender appends .001 to copied nodes.
 raw=path.read_bytes(); length,_=struct.unpack_from('<II',raw,12); doc=json.loads(raw[20:20+length])
 for node in doc.get('nodes',[]):
  original=node.get('extras',{}).get('source_name')
  if original: node['name']=original
 chunk=json.dumps(doc,separators=(',',':'),ensure_ascii=True).encode(); chunk+=b' '*((-len(chunk))%4)
 tail=raw[20+length:]; path.write_bytes(struct.pack('<4sII',b'glTF',2,20+len(chunk)+len(tail))+struct.pack('<II',len(chunk),0x4e4f534a)+chunk+tail)
 report=glb_report(path); assert report['triangles']<=6000,(path,report['triangles'])
 return report

def lod_copy(root,ratio):
 copyroot=root.copy(); copyroot.name=root.name+'_LOD1'; bpy.context.collection.objects.link(copyroot)
 for o in root.children:
  c=o.copy(); c.name=o.name.split('.')[0]; c.parent=copyroot; bpy.context.collection.objects.link(c)
  if o.type=='MESH':
   c.data=o.data.copy()
   if o.name.split('.')[0]=='Structure':
    select([c]); mod=c.modifiers.new('Mobile_LOD','DECIMATE'); mod.ratio=ratio
    bpy.ops.object.modifier_apply(modifier=mod.name)
 return copyroot

def lighting(cfg):
 s=bpy.context.scene; s.render.engine='CYCLES'; s.cycles.samples=cfg['render_samples']; s.cycles.use_denoising=True
 s.render.resolution_percentage=100; s.render.image_settings.file_format='PNG'; s.world.use_nodes=True
 s.world.node_tree.nodes.get('Background').inputs[0].default_value=(.56,.64,.71,1); s.world.node_tree.nodes.get('Background').inputs[1].default_value=.55
 sun=bpy.data.lights.new('Soleil_Controle','SUN'); sun.energy=2.0; sun.color=(1,.77,.52); sun.angle=math.radians(12)
 o=bpy.data.objects.new('Soleil_Controle',sun); bpy.context.collection.objects.link(o); o.rotation_euler=(math.radians(28),math.radians(-25),math.radians(-35))
 camdata=bpy.data.cameras.new('Camera_Controle'); cam=bpy.data.objects.new('Camera_Controle',camdata); bpy.context.collection.objects.link(cam); s.camera=cam
 return cam

def aim(cam,position,target):
 cam.location=position; cam.rotation_euler=(Vector(target)-cam.location).to_track_quat('-Z','Y').to_euler()

def previews(roots,assets,cfg,out):
 folder=out/'previews'; folder.mkdir(exist_ok=True); cam=lighting(cfg); scene=bpy.context.scene
 for root,a in zip(roots,assets):
  for r in roots:
   for o in descendants(r): o.hide_render=r!=root
  lo,hi=a.bounds(); span=max(hi[0]-lo[0],hi[1],hi[2]-lo[2]); cam.data.type='ORTHO'; cam.data.ortho_scale=span*1.55
  aim(cam,game_to_blender((span*1.15,span*.85,span*1.6)),game_to_blender((0,hi[1]*.43,0)))
  scene.render.resolution_x=900; scene.render.resolution_y=900; scene.render.filepath=str(folder/(a.name+'.png')); bpy.ops.render.render(write_still=True)
 for root,a in zip(roots,assets):
  root.location=game_to_blender(a.layout); root.rotation_euler.z=math.radians(a.yaw)
  for o in descendants(root): o.hide_render=False
 # Neutral temporary presentation floor; not part of lot 1 exports.
 bpy.ops.mesh.primitive_plane_add(size=100); floor=bpy.context.object; floor.name='Sol_Controle_Non_Exporte'; floor.location.z=-.025
 m=bpy.data.materials.new('Sol_Controle'); m.diffuse_color=(.38,.34,.27,1); floor.data.materials.append(m)
 cam.data.type='PERSP'; cam.data.sensor_fit='VERTICAL'; cam.data.lens=cam.data.sensor_height/(2*math.tan(math.radians(42)/2))
 aim(cam,game_to_blender((0,11,21)),game_to_blender((0,5,-10)))
 scene.render.resolution_x=1600; scene.render.resolution_y=1000; scene.render.filepath=str(folder/'Port_Franc_Camera_Jeu.png'); bpy.ops.render.render(write_still=True)
 bpy.ops.wm.save_as_mainfile(filepath=str(out/'Port_Franc_Lot1.blend'))
