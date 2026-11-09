from pathlib import Path
project=Path(__file__).resolve().parent
path=project/'sheila_walk_preview.glb.import'
if not path.exists():raise RuntimeError('Run Godot --editor --headless --import once before configuring this profile')
s=path.read_text(encoding='utf-8-sig');key='import_script/path=';lines=s.splitlines();assert sum(line.startswith(key) for line in lines)==1
path.write_text('\n'.join(key+'"res://sheila_material_import.gd"' if line.startswith(key) else line for line in lines)+'\n',encoding='utf-8')
print('Configured hair specular profile; run Godot import again')
