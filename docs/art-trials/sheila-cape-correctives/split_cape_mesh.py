import os
import bpy,json,os
from pathlib import Path
h=Path.home();root=Path(os.environ.get('YUMING_SHEILA_CAPE_WORK',str(h/'Documents/sheila-cloth-walk')));bpy.ops.wm.open_mainfile(filepath=str(root/'tailored_noen.blend'));s=bpy.context.scene;obj=bpy.data.objects['Sheila_Clothes'];attr=obj.data.attributes['CapeVertex'];indices={v.index for v in obj.data.vertices if attr.data[v.index].value>.5};assert len(indices)==1280;print('CLOTH_SHAPES_BEFORE_SPLIT',len(obj.data.shape_keys.key_blocks));before=set(s.objects);bpy.ops.object.select_all(action='DESELECT');obj.select_set(True);bpy.context.view_layer.objects.active=obj;obj.active_shape_key_index=0;s.tool_settings.mesh_select_mode=(True,False,False);bpy.ops.object.mode_set(mode='EDIT');bpy.ops.mesh.select_all(action='DESELECT');bpy.ops.object.mode_set(mode='OBJECT')
for v in obj.data.vertices:v.select=v.index in indices
bpy.ops.object.mode_set(mode='EDIT');bpy.ops.mesh.separate(type='SELECTED');bpy.ops.object.mode_set(mode='OBJECT');new=list(set(s.objects)-before);assert len(new)==1;cape=new[0];cape.name='Sheila_Cape';cape.data.name='Sheila_Cape';print('CAPE_SHAPES',len(cape.data.shape_keys.key_blocks))
for o in s.objects:
 if o.type=='MESH' and o!=cape and o.data.shape_keys:
  basis=o.data.shape_keys.key_blocks[0];error=max((v.co-basis.data[i].co).length for key in list(o.data.shape_keys.key_blocks)[1:] for i,v in enumerate(key.data));print('CLEAR_ZERO_SHAPES',o.name,error);assert error<1e-7;o.shape_key_clear()
bpy.ops.wm.save_as_mainfile(filepath=str(root/'tailored_noen.blend'))
