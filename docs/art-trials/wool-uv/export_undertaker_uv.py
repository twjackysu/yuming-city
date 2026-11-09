import bpy,numpy as np
from pathlib import Path
root=Path.home()/'Documents/undertaker-wool-pbr';bpy.ops.wm.open_mainfile(filepath=str(Path.home()/'Documents/undertaker-production/triposg/body_baked/undertaker_body.blend'));obj=bpy.data.objects['Undertaker_Robes'];v=np.array([p.co[:] for p in obj.data.vertices],dtype=np.float32);f=np.array([list(p.vertices) for p in obj.data.polygons],dtype=np.uint32);assert f.shape[1]==3;np.savez(root/'uv_input.npz',vertices=v,faces=f);print(v.shape,f.shape)
