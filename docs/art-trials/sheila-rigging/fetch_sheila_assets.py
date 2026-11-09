import os
import io, requests, zipfile, argparse
from pathlib import Path
p=argparse.ArgumentParser();p.add_argument('--pack',choices=['system','winter'],default='system');p.add_argument('--wardrobe',action='store_true');args=p.parse_args()
class RemoteFile(io.RawIOBase):
    def __init__(self):
        self.url='https://files.makehumancommunity.org/asset_packs/makehuman_system_assets/makehuman_system_assets_cc0.zip'
        self.size=280737770; self.pos=0; self.s=requests.Session()
        if args.pack=='winter':
            self.url='https://files.makehumancommunity.org/asset_packs/dress03/dress03_cc-by.zip';self.size=486395821
    def seekable(self): return True
    def seek(self,offset,whence=0):
        self.pos=offset if whence==0 else self.pos+offset if whence==1 else self.size+offset
        return self.pos
    def tell(self): return self.pos
    def read(self,n=-1):
        n=self.size-self.pos if n<0 else min(n,self.size-self.pos)
        if not n:return b''
        end=self.pos+n-1
        r=self.s.get(self.url,headers={'Range':f'bytes={self.pos}-{end}'},timeout=60)
        r.raise_for_status()
        if r.status_code!=206 or len(r.content)!=n:raise ValueError('Unexpected range response')
        self.pos+=n
        return r.content
root=Path(os.environ.get('YUMING_MPFB_ASSETS', str(Path.home()/'Tools'/'mpfb-user'/'data'))).resolve()
with zipfile.ZipFile(RemoteFile()) as z:
    names=z.namelist()
    Path(str(Path.home()/'mh_')+args.pack+'_asset_index.txt').write_text('\n'.join(names))
    keys=['skins/young_caucasian_female/','hair/ponytail01/','license']
    for name in names:
        if name.endswith('/'):continue
        if not any(key in name.lower() for key in keys):continue
        dest=(root/name).resolve()
        if not dest.is_relative_to(root):raise ValueError('Unsafe archive path')
        if dest.exists():continue
        dest.parent.mkdir(parents=True,exist_ok=True)
        dest.write_bytes(z.read(name))
        print(name,flush=True)
