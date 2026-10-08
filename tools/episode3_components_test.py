"""Audit Episode III primitives, cross-episode reuse, graph coverage and masks."""
import hashlib,json,math
from pathlib import Path
from PIL import Image
from story_graph_format import load_all
from build_episode3_components import retired,plans
ROOT=Path(__file__).resolve().parents[1]
first=json.loads((ROOT/'data/episode1_components.json').read_text())
highlights=json.loads((ROOT/'data/episode3_highlights.json').read_text())
parts=json.loads((ROOT/'data/episode3_components.json').read_text())
assert parts.keys()==plans(ROOT).keys()
textures={p['texture'] for ps in parts.values() for p in ps if p['type']=='texture'}
for name in textures:
 with Image.open(ROOT/'assets/flash_ui'/name) as image:
  image.load();image=image.convert('RGBA')
  assert image.getchannel('A').getbbox()==(0,0,image.width,image.height),name
  digest=hashlib.sha256(str(image.size).encode()+image.tobytes()).hexdigest()[:20]
  assert name.endswith('part_'+digest+'.png'),name
for name,ps in parts.items():
 for extension in ['png']:assert not (ROOT/'assets/flash_ui'/(name+'.'+extension)).exists(),name
 for p in ps:
  assert p['type'] in ['texture','panel','qte_prompt','highlight'] and all(math.isfinite(v) for v in p['rect'])
  assert p['rect'][2]>=0 and p['rect'][3]>=0 and p.get('source')
  if p['type']=='panel':assert len(p['color'])==4 and all(0<=v<=1 for v in p['color'])
  elif p['type']=='qte_prompt':
   assert p['text']=='@loc:ui.qte.press' and len(p['transform'])==6
   assert all(math.isfinite(v) for v in p['transform'])
   assert abs(p['transform'][0]*p['transform'][2]+p['transform'][1]*p['transform'][3])<0.0001
  elif p['type']=='highlight':
   region=highlights['regions'][p['region']]
   assert not p.get('texture') and region['contours']
   assert tuple(region['size'])==tuple(round(v*2) for v in p['rect'][2:])
  else:
   with Image.open(ROOT/'assets/flash_ui'/p['texture']) as im:assert im.size==tuple(round(v*2) for v in p['rect'][2:])
second=json.loads((ROOT/'data/episode2_components.json').read_text())
combined={**first,**second,**parts}
nodes=load_all(ROOT)
episode={id:n for id,n in nodes.items() if n.get('episode',1)==3}
assert len(episode)==131
for id,n in episode.items():
 for key in ['art','art_on_foot','controls_art','decision_art','background_art']:
  if key in n:assert n[key] in combined,(id,key,n[key])
 for frame in n.get('animation_frames',[]):assert frame in parts,(id,frame)
 for c in n.get('choices',[]):
  if 'mask' in c and c['mask'] not in highlights.get('masks',{}):
   with Image.open(ROOT/'assets/flash_ui'/(c['mask']+'.png')) as im:im.load();assert im.getbbox()
assert not retired(ROOT)
assert {t for t in textures if t.startswith('episode3_components/')}=={'episode3_components/'+p.name for p in (ROOT/'assets/flash_ui/episode3_components').glob('*.png')}
assert any(t.startswith('episode1_components/') for t in textures),'shared first-episode textures'
print(f'PASS: {len(episode)} screens, {len(parts)} component sets, {len(textures)} textures, reuse, masks, cleanup')
