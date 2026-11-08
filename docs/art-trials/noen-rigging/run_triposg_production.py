import os
import argparse, functools, json, sys, time
from pathlib import Path
import numpy as np
import torch
from PIL import Image
from huggingface_hub import snapshot_download

p = argparse.ArgumentParser()
p.add_argument('--input', required=True)
p.add_argument('--output', required=True)
p.add_argument('--seed', type=int, default=81)
p.add_argument('--steps', type=int, default=50)
p.add_argument('--depth', type=int, default=8)
a = p.parse_args()
sys.path.insert(0, os.environ.get('YUMING_TRIPOSG_SOURCE', str(Path.home()/'Tools'/'TripoSG')))
from triposg.pipelines.pipeline_triposg import TripoSGPipeline

out = Path(a.output)
out.mkdir(parents=True, exist_ok=True)
im = Image.open(a.input).convert('RGBA')
alpha = np.asarray(im.getchannel('A'))
if (alpha < 128).mean() < .01:
    raise ValueError('Expected a transparent cutout')
bbox = im.getchannel('A').point(lambda x: 255 if x > 200 else 0).getbbox()
im = im.crop(bbox)
side = round(max(im.size) / .9)
prepared = Image.new('RGBA', (side,side), 'white')
prepared.alpha_composite(im, ((side-im.width)//2,(side-im.height)//2))
prepared = prepared.convert('RGB')
prepared.save(out/'model_input.png')
revision='2c1c516d22d58db486a058d98d31bb6177344e06'
weights=snapshot_download('VAST-AI/TripoSG',revision=revision,local_files_only=True,allow_patterns=['*.json','*.safetensors'])
print('Loading safe tensor weights',flush=True)
pipe=TripoSGPipeline.from_pretrained(weights,torch_dtype=torch.float16,use_safetensors=True,local_files_only=True)
pipe.model_cpu_offload_seq='image_encoder_dinov2->transformer->vae'
pipe.enable_model_cpu_offload()
pipe.vae.decode=functools.partial(pipe.vae.decode,num_chunks=1024)
torch.cuda.reset_peak_memory_stats()
t=time.monotonic()
with torch.inference_mode():
    result=pipe(image=prepared,generator=torch.Generator(device='cuda').manual_seed(a.seed),num_inference_steps=a.steps,use_flash_decoder=False,dense_octree_depth=7,hierarchical_octree_depth=a.depth)
mesh=result.meshes[0]
if not np.isfinite(mesh.vertices).all() or len(mesh.faces)==0:
    raise ValueError('Invalid mesh')
mesh.export(out/'noen_triposg.glb')
report=dict(model_revision=revision,seed=a.seed,steps=a.steps,depth=a.depth,seconds=time.monotonic()-t,triangles=len(mesh.faces),vertices=len(mesh.vertices),watertight=bool(mesh.is_watertight),bounds=mesh.bounds.tolist(),peak_allocated_mib=torch.cuda.max_memory_allocated()/2**20,status='geometry_candidate_pending_visual_review')
(out/'trial.json').write_text(json.dumps(report,indent=2),encoding='utf-8')
print(report,flush=True)
