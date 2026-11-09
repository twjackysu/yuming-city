from huggingface_hub import snapshot_download
print(snapshot_download('microsoft/TRELLIS-image-large',revision='25e0d31ffbebe4b5a97464dd851910efc3002d96',allow_patterns=['LICENSE','README.md','pipeline.json','ckpts/*.json','ckpts/*.safetensors'],local_dir=str(__import__('pathlib').Path.home()/'Tools/trellis-weights'),max_workers=3))
