import faulthandler
faulthandler.dump_traceback_later(35,repeat=True)
import os,sys
from pathlib import Path
os.environ['ATTN_BACKEND']='xformers';os.environ['SPCONV_ALGO']='native'
import torch
import xformers.ops as xops
import spconv.pytorch as spconv
q=torch.randn(1,256,8,64,device='cuda',dtype=torch.float16);result=xops.memory_efficient_attention(q,q,q);print('ATTENTION',result.shape,torch.isfinite(result).all().item())
indices=torch.tensor([[0,x,y,z] for x in range(3) for y in range(3) for z in range(3)],device='cuda',dtype=torch.int32);tensor=spconv.SparseConvTensor(torch.randn(27,4,device='cuda'),indices,[3,3,3],1);conv=spconv.SubMConv3d(4,8,3,algo=spconv.ConvAlgo.Native).cuda();result=conv(tensor);print('SPCONV',result.features.shape,torch.isfinite(result.features).all().item())
sys.path.insert(0,str(Path.home()/'Tools/TRELLIS'));from trellis.pipelines import TrellisImageTo3DPipeline;print('PIPELINE_IMPORTED')
