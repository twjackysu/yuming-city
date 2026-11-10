import os
from pathlib import Path
import json,struct,io,numpy as np
from PIL import Image
h=Path.home();root=Path(os.environ.get('YUMING_SHEILA_SWORD_WORK',str(h/'Documents/sheila-sword-35cm')));raw=(root/'sheila_walk_normal_fitted.glb').read_bytes();n=struct.unpack_from('<I',raw,12)[0];g=json.loads(raw[20:20+n]);b=raw[28+n:];m=next(m for m in g['materials'] if m['name']=='M_Sheila_Clothes');report=[]
for name,index in [('BaseColor',m['pbrMetallicRoughness']['baseColorTexture']['index']),('Normal',m['normalTexture']['index']),('ORM',m['pbrMetallicRoughness']['metallicRoughnessTexture']['index'])]:
 im=g['images'][g['textures'][index]['source']];v=g['bufferViews'][im['bufferView']];data=b[v.get('byteOffset',0):v.get('byteOffset',0)+v['byteLength']];a=np.array(Image.open(io.BytesIO(data)).convert('RGBA'));z=np.array(Image.open(root/('Sheila_Clothes_'+name+'.png')).convert('RGBA'));error=int(np.abs(a.astype(int)-z.astype(int)).max());report.append({'map':name,'dimensions':[a.shape[1],a.shape[0]],'maximum_embedded_vs_baked_pixel_error':error});assert error==0
(root/'embedded_texture_check.json').write_text(json.dumps({'passed':True,'maps':report},indent=2));print(report)
