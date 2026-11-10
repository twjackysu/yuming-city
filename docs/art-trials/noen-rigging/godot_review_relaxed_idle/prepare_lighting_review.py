from pathlib import Path
import os,shutil,json,hashlib
project=Path(__file__).resolve().parent
candidates=[Path(os.environ['YUMING_REPO'])] if 'YUMING_REPO' in os.environ else list(project.parents)
repo=next((p for p in candidates if (p/'game/src/world/frostbridge_look.gd').exists()),None)
if repo is None:raise RuntimeError('Set YUMING_REPO to the game repository root')
world=project/'src/world';world.mkdir(parents=True,exist_ok=True);records=[]
for name in ['frostbridge_look.gd','night_sky.gdshader','wet_cobble.gdshader']:
 source=repo/'game/src/world'/name;shutil.copy2(source,world/name);records.append({'file':name,'sha256':hashlib.sha256(source.read_bytes()).hexdigest()})
(project/'night_source_snapshot.json').write_text(json.dumps(records,indent=2))
print('Prepared project lighting snapshot from',repo)
