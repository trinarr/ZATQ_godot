"""Convert source textures atomically, preserving decoded RGBA and import UIDs.

Usage: python tools/convert_webp_to_png.py [project-directory]
"""
import argparse,hashlib,json,os
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path
from PIL import Image

def convert_one(source,root):
 target=source.with_suffix('.png')
 with Image.open(source) as image:
  image=image.convert('RGBA');pixels=image.tobytes()
  if target.exists():
   with Image.open(target) as existing:
    assert existing.size==image.size and existing.convert('RGBA').tobytes()==pixels, f'PNG collision: {target}'
  else:
   temporary=target.with_suffix('.png.tmp')
   encoded=image.convert('RGB') if image.getchannel('A').getextrema()==(255,255) else image
   encoded.save(temporary,format='PNG',compress_level=6)
   with temporary.open('rb') as complete:os.fsync(complete.fileno())
   os.replace(temporary,target)
  with Image.open(target) as result:
   assert result.size==image.size and result.convert('RGBA').tobytes()==pixels,f'Pixel mismatch: {target}'
  record={'png':str(target.relative_to(root)),'size':list(image.size),'rgba_sha256':hashlib.sha256(pixels).hexdigest()}
 old_import=Path(str(source)+'.import')
 if old_import.exists():
  Path(str(target)+'.import').write_text(old_import.read_text().replace('.webp','.png'))
 source.unlink()
 return record

def convert(root):
 sources=[p for p in sorted(root.rglob('*.webp')) if not any(part in ['.git','.godot'] for part in p.parts)]
 with ThreadPoolExecutor(max_workers=4) as pool:
  records=list(pool.map(lambda p:convert_one(p,root),sources))
 folders={p.parent for p in sources}
 # Also retire metadata left over from removed composites.
 for metadata in root.rglob('*.webp.import'):
  if '.git' not in metadata.parts and '.godot' not in metadata.parts:folders.add(metadata.parent);metadata.unlink()
 if hasattr(os,"O_DIRECTORY"):
  for folder in folders:
   fd=os.open(folder,os.O_DIRECTORY)
   try:os.fsync(fd)
   finally:os.close(fd)
 return records

if __name__=='__main__':
 parser=argparse.ArgumentParser();parser.add_argument('project',nargs='?',type=Path,default=Path(__file__).resolve().parents[1]);args=parser.parse_args()
 records=convert(args.project)
 print(json.dumps({'converted':len(records),'pixels_verified':True}))
