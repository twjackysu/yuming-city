import os,sys,json,time,gc,traceback
from pathlib import Path
os.environ['ATTN_BACKEND']='xformers';os.environ['SPARSE_ATTN_BACKEND']='xformers';os.environ['SPCONV_ALGO']='native';os.environ['HF_HUB_OFFLINE']='1'
import torch,numpy as np,trimesh
from PIL import Image
sys.path.insert(0,str(Path.home()/'Tools/TRELLIS'))
from trellis.pipelines import TrellisImageTo3DPipeline
class LowVramTrellis(TrellisImageTo3DPipeline):
 @property
 def device(self):return torch.device('cuda')
root=Path.home()/'Documents/undertaker-trellis';root.mkdir(exist_ok=True);start=time.perf_counter()
def offload(*names):
 for name in names:pipe.models[name].cpu()
 gc.collect();torch.cuda.empty_cache()
try:
 print('LOAD_PIPELINE',flush=True);pipe=TrellisImageTo3DPipeline.from_pretrained(str(Path.home()/'Tools/trellis-weights'));pipe.__class__=LowVramTrellis
 image=Image.open(Path(os.environ.get('TRELLIS_INPUT',str(Path(__file__).resolve().parents[1]/'undertaker-rigging/inputs/undertaker_body_input.png'))));image=pipe.preprocess_image(image);image.save(root/'model_input.png');torch.manual_seed(81);torch.cuda.reset_peak_memory_stats()
 with torch.inference_mode():
  print('ENCODE_IMAGE',flush=True);pipe.models['image_cond_model'].half().cuda()
  with torch.autocast('cuda',dtype=torch.float16):cond=pipe.get_cond([image])
  offload('image_cond_model')
  print('SPARSE_STRUCTURE',flush=True);pipe.models['sparse_structure_flow_model'].cuda();pipe.models['sparse_structure_decoder'].cuda();coords=pipe.sample_sparse_structure(cond,1,{'steps':25});offload('sparse_structure_flow_model','sparse_structure_decoder');print('OCCUPIED',coords.shape[0],flush=True)
  print('STRUCTURED_LATENT',flush=True);pipe.models['slat_flow_model'].cuda();slat=pipe.sample_slat(cond,coords,{'steps':25});offload('slat_flow_model');print('DECODE_MESH',flush=True)
  pipe.models['slat_decoder_mesh'].cuda();mesh=pipe.decode_slat(slat,['mesh'])['mesh'][0];vertices=mesh.vertices.float().cpu().numpy();faces=mesh.faces.cpu().numpy();attrs=mesh.vertex_attrs.float().cpu().numpy() if mesh.vertex_attrs is not None else None
  print('MESH',vertices.shape,faces.shape,'ATTR',None if attrs is None else attrs.shape,flush=True)
  # Same canonical Z-up to glTF Y-up transform used by the official exporter.
  vertices=vertices@np.array([[1,0,0],[0,0,-1],[0,1,0]])
  colors=np.c_[np.clip(attrs[:,:3],0,1)*255,np.full(len(vertices),255)].astype(np.uint8) if attrs is not None else None
  output=trimesh.Trimesh(vertices=vertices,faces=faces,vertex_colors=colors,process=False);output.export(root/'undertaker_trellis_raw.glb');output.export(root/'undertaker_trellis_raw.ply')
  if attrs is not None:np.save(root/'vertex_attributes.npy',attrs)
 report={'success':True,'seconds':time.perf_counter()-start,'peak_vram_mib':torch.cuda.max_memory_allocated()/1024**2,'vertices':len(vertices),'triangles':len(faces),'vertex_attributes':None if attrs is None else attrs.shape[1],'seed':81,'steps':25,'model_revision':'25e0d31ffbebe4b5a97464dd851910efc3002d96','status':'unreviewed_geometry_and_vertex_color_study'};(root/'trial.json').write_text(json.dumps(report,indent=2));print(json.dumps(report),flush=True)
except Exception as error:
 (root/'failure.json').write_text(json.dumps({'error':str(error),'seconds':time.perf_counter()-start},indent=2));traceback.print_exc();sys.exit(1)
