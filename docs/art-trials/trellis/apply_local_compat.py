"""Apply the narrow local compatibility changes used by this Windows study."""
from pathlib import Path
import os,hashlib,shutil
root=Path(os.environ.get('YUMING_TOOLS',str(Path.home()/'Tools')))
def replace(path,old,new):
 data=path.read_text(encoding='utf-8')
 if new in data:return
 if old not in data:raise RuntimeError('Unexpected source revision: '+str(path))
 path.write_text(data.replace(old,new),encoding='utf-8')
pyd=root/'trellis-env/Lib/site-packages/xformers/pyd';expected='f270fe25a583dc50ab1b69c582ca4b94ed8e5262284638ea3d5334ce001fed30'
if not pyd.exists() or hashlib.sha256(pyd.read_bytes()).hexdigest()!=expected:raise RuntimeError('Unexpected xFormers wheel binary')
target=pyd.with_name('_C.pyd')
if target.exists() and hashlib.sha256(target.read_bytes()).hexdigest()!=expected:raise RuntimeError('Existing _C.pyd differs')
if not target.exists():shutil.copy2(pyd,target)
replace(root/'TRELLIS/trellis/pipelines/__init__.py','from .trellis_text_to_3d import TrellisTextTo3DPipeline','# Image-only study: do not eagerly import the unused Open3D text pipeline.')
replace(root/'TRELLIS/trellis/pipelines/trellis_image_to_3d.py',"torch.hub.load('facebookresearch/dinov2', name, pretrained=True)","torch.hub.load(str(__import__('pathlib').Path.home()/'Tools/dinov2'), name, source='local', pretrained=True)")
replace(root/'TRELLIS/trellis/representations/mesh/flexicubes/flexicubes.py','from kaolin.utils.testing import check_tensor',"def check_tensor(tensor, shape, throw=False):\n    valid=torch.is_tensor(tensor) and tensor.ndim==len(shape) and all(expected is None or actual==expected for actual,expected in zip(tensor.shape,shape))\n    if throw and not valid:raise ValueError('Invalid tensor shape')\n    return valid".replace('\\n','\n'))
print('Applied verified image-only Windows compatibility changes')
