"""Local TripoSR trial using a reviewed, patched upstream checkout.

No cloud inference, background-removal model, remote Python code, or paid API.
Output is a static reconstruction study, not a production character.
"""
import argparse
import hashlib
import json
from pathlib import Path
import sys
import time
import subprocess

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--source', type=Path, required=True)
parser.add_argument('--input', type=Path, required=True)
parser.add_argument('--output', type=Path, required=True)
parser.add_argument('--resolution', type=int, choices=(128, 192, 256), default=192)
parser.add_argument('--chunk-size', type=int, default=2048)
parser.add_argument('--model-revision', default='5b521936b01fbe1890f6f9baed0254ab6351c04a')
args = parser.parse_args()
source_commit = subprocess.run(['git', '-C', str(args.source), 'rev-parse', 'HEAD'],
    capture_output=True, text=True, check=True).stdout.strip()
if source_commit != '107cefdc244c39106fa830359024f6a2f1c78871':
    raise SystemExit('Source revision differs from the reviewed trial checkout')
sys.path.insert(0, str(args.source.resolve()))

import numpy as np
import torch
from huggingface_hub import hf_hub_download
from omegaconf import OmegaConf
from PIL import Image
from tsr.system import TSR

if not torch.cuda.is_available():
    raise SystemExit('CUDA unavailable; do not silently run a long CPU inference')
torch.manual_seed(81)
np.random.seed(81)
args.output.mkdir(parents=True, exist_ok=True)
start = time.monotonic()
revision = args.model_revision
print('Downloading model revision', revision, flush=True)
paths = {}
for filename in ('config.yaml', 'model.ckpt'):
    paths[filename] = Path(hf_hub_download('stabilityai/TripoSR', filename, revision=revision))
config = OmegaConf.load(paths['config.yaml'])
OmegaConf.resolve(config)
for key, value in config.items():
    if key.endswith('_cls') and not str(value).startswith('tsr.models.'):
        raise SystemExit('Unexpected model class in downloaded configuration')
model = TSR(config)
state = torch.load(paths['model.ckpt'], map_location='cpu', weights_only=True)
model.load_state_dict(state)
del state
model.eval().to('cuda:0')
model.renderer.set_chunk_size(args.chunk_size)
loaded = time.monotonic()
print('CUDA:', torch.cuda.get_device_name(0), 'model ready', flush=True)
original = Image.open(args.input).convert('RGB')
# Letterbox the ML input: upstream directly resizes to a square and otherwise
# distorts portrait references. This does not redesign the source artwork.
side = round(max(original.size) / .9)
prepared = Image.new('RGB', (side, side), (128, 128, 128))
prepared.paste(original, ((side-original.width)//2, (side-original.height)//2))
prepared.save(args.output/'model_input.png')
torch.cuda.reset_peak_memory_stats()
with torch.inference_mode():
    codes = model([prepared], device='cuda:0')
    torch.cuda.synchronize()
    inferred = time.monotonic()
    print('Image encoded; extracting grid', args.resolution, flush=True)
    mesh = model.extract_mesh(codes, has_vertex_color=True, resolution=args.resolution)[0]
    torch.cuda.synchronize()
extracted = time.monotonic()
if not len(mesh.vertices) or not len(mesh.faces) or not np.isfinite(mesh.vertices).all():
    raise SystemExit('Empty or non-finite generated mesh')
mesh.fix_normals()
model_path = args.output / 'noen_triposr.glb'
mesh.export(model_path)
checkpoint_hash = hashlib.sha256()
with paths['model.ckpt'].open('rb') as checkpoint:
    for block in iter(lambda: checkpoint.read(1024*1024), b''):
        checkpoint_hash.update(block)
report = {
    'status': 'static_reconstruction_study_not_accepted',
    'source_repo': 'https://github.com/VAST-AI-Research/TripoSR',
    'source_commit': source_commit,
    'model_repo': 'stabilityai/TripoSR', 'model_revision': revision,
    'checkpoint_sha256': checkpoint_hash.hexdigest(),
    'input_sha256': hashlib.sha256(args.input.read_bytes()).hexdigest(),
    'seed': 81, 'grid_resolution': args.resolution, 'chunk_size': args.chunk_size,
    'input_preprocessing': 'Aspect-preserving grey square letterbox, 10% margin',
    'torch': torch.__version__, 'cuda': torch.version.cuda,
    'gpu': torch.cuda.get_device_name(0),
    'peak_allocated_vram_mib': round(torch.cuda.max_memory_allocated()/1024**2, 1),
    'vertices': len(mesh.vertices), 'triangles': len(mesh.faces),
    'bounds_model_units': mesh.bounds.tolist(), 'watertight': bool(mesh.is_watertight),
    'timing_seconds': {'download_and_load': round(loaded-start, 2),
        'image_encoding': round(inferred-loaded, 2), 'mesh_extraction': round(extracted-inferred, 2)},
    'output_sha256': hashlib.sha256(model_path.read_bytes()).hexdigest(),
    'limitations': ['Vertex colors only; no PBR textures, UV, skeleton, skin, or animation.',
        'Back/occluded geometry inferred from one front image.',
        'No body-height or Godot orientation normalization yet.',
        'Visual and deformation acceptance has not passed.'],
    'compatibility_changes': ['CPU skimage marching cubes instead of compiled torchmcubes',
        'Lazy optional rembg import; no background-removal model used',
        'Explicit weights_only=True checkpoint loading']}
(args.output/'trial.json').write_text(json.dumps(report, indent=2), encoding='utf-8')
print(json.dumps(report, indent=2), flush=True)
