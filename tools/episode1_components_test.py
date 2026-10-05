"""Audit every component, runtime reference, retained mask and retired export."""
import hashlib,json,math
from pathlib import Path
from PIL import Image
from story_graph_format import load_all
from clean_episode1_art import retired
ROOT=Path(__file__).resolve().parents[1]
parts=json.loads((ROOT/'data/episode1_components.json').read_text())
textures={p['texture'] for ps in parts.values() for p in ps if p['type']=='texture'}
for name in textures:
 with Image.open(ROOT/'assets/flash_ui'/name) as image:
  image.load();image=image.convert('RGBA')
  assert image.getchannel('A').getbbox()==(0,0,image.width,image.height),name
  digest=hashlib.sha256(str(image.size).encode()+image.tobytes()).hexdigest()[:20]
  assert name.endswith('part_'+digest+'.webp'),name
for name,ps in parts.items():
 assert not (ROOT/'assets/flash_ui'/(name+'.png')).exists(),name
 for p in ps:
  assert p['type'] in ['texture','panel'] and all(math.isfinite(v) for v in p['rect'])
  assert p['rect'][2]>=0 and p['rect'][3]>=0
  assert p.get('source')
  if p['type']=='panel':assert len(p['color'])==4 and all(0<=v<=1 for v in p['color'])
  else:
   with Image.open(ROOT/'assets/flash_ui'/p['texture']) as im:assert im.size==tuple(round(v*2) for v in p['rect'][2:])
for n in load_all(ROOT).values():
 if n.get('episode',1)!=1:continue
 for key in ['art','art_on_foot','controls_art','decision_art']:
  if key in n:assert n[key] in parts,(key,n[key])
 for c in n.get('choices',[]):
  if 'mask' in c:assert (ROOT/'assets/flash_ui'/(c['mask']+'.png')).exists()
assert not retired(ROOT),'retired composites were left behind'
assert textures=={'episode1_components/'+p.name for p in (ROOT/'assets/flash_ui/episode1_components').glob('*.webp')}
print(f'PASS: {len(parts)} component sets, {len(textures)} complete shared lossless WebP textures, native panels, masks, cleanup')
