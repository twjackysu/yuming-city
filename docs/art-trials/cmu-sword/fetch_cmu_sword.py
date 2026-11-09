"""Fetch the pinned CMU numeric motion inputs; never execute downloaded content."""
from pathlib import Path
from urllib.request import urlopen
import hashlib,os
FILES = {'02.asf': 'c9f5ff45b4437b279f58b95dacf017afd3135373096274df69436a9354d796cf', '02_07.amc': '6171216b0bd691843096798431a5f201b9d1340503cf89ce20180b6143597cd8'}
root=Path(os.environ.get('CMU_MOCAP',str(Path.home()/'Tools/cmu-mocap')));root.mkdir(parents=True,exist_ok=True)
for name,expected in FILES.items():
 data=None
 for protocol in ['https','http']:
  try:
   with urlopen(protocol+'://mocap.cs.cmu.edu/subjects/02/'+name,timeout=45) as response:blob=response.read(20_000_001)
   if len(blob)>20_000_000 or hashlib.sha256(blob).hexdigest()!=expected:raise ValueError('Pinned motion hash mismatch')
   data=blob;break
  except Exception as error:print(protocol,name,type(error).__name__)
 if data is None:raise RuntimeError('No verified motion input for '+name)
 (root/name).write_bytes(data)
 print(name,len(data),expected)
