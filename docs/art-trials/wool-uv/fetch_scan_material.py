from pathlib import Path
import requests,hashlib,json,os
root=Path(os.environ.get('CC0_WOOL_ASSETS',str(Path.home()/'Tools/cc0-materials/poly_wool_herringbone')));root.mkdir(parents=True,exist_ok=True)
for item in json.loads((Path(__file__).parent/'scan_manifest.json').read_text()):
 name=item['file']
 if Path(name).name!=name or not item['url'].startswith('https://dl.polyhaven.org/'):raise ValueError('Unexpected scan source')
 target=root/name
 if target.exists() and hashlib.sha256(target.read_bytes()).hexdigest()==item['sha256']:continue
 response=requests.get(item['url'],headers={'User-Agent':'YumingCity-ArtProduction/1.0'},timeout=60);response.raise_for_status()
 if len(response.content)!=item['bytes'] or hashlib.sha256(response.content).hexdigest()!=item['sha256']:raise ValueError('Scan integrity mismatch: '+name)
 target.write_bytes(response.content);print(name)
