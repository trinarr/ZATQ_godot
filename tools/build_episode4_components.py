"""Export Episode IV primitives and shader-based interactive contours.
Usage: python tools/build_episode4_components.py ORIGINAL.zip
Shares the preceding episode exporter; textures are deduplicated across episodes.
"""
import argparse,hashlib,json
from pathlib import Path
import numpy as np
from PIL import Image
from build_episode3_components import build as export
from build_episode1_highlights import contours
ROOT=Path(__file__).resolve().parents[1]
def build(archive,root=ROOT,episode=4):
 export(archive,root,episode=episode)
 path=root/f'data/episode{episode}_components.json';catalog=json.loads(path.read_text())
 regions={};removed=set()
 for name,parts in catalog.items():
  if not name.endswith('_controls'):continue
  for part in parts:
   color=None;size=None;rings=None
   if part['type']=='panel' and part['color'][0]>.3 and max(part['color'][1:3])<.1:
    w,h=[round(v*2) for v in part['rect'][2:]];size=[w,h];rings=[[0,0,w,0,w,h,0,h]];color=part['color'][:3]
   elif part['type']=='texture':
    with Image.open(root/'assets/flash_ui'/part['texture']) as im:a=np.asarray(im.convert('RGBA'))
    visible=a[a[:,:,3]>5].astype(float)
    if not len(visible):continue
    red=(visible[:,0]>visible[:,1]*1.7)&(visible[:,0]>visible[:,2]*1.7)&(visible[:,0]>70)
    if np.mean(red)<.95:continue
    peak=visible[:,3].max();rgb=np.median(visible[red & (visible[:,3]>=peak*.95),:3],axis=0)
    rings=contours(a[:,:,3]>=peak*.2);size=[a.shape[1],a.shape[0]];color=[round(float(c)/255,6) for c in rgb]
    removed.add(part['texture'])
   if rings is None:continue
   region={'size':size,'contours':rings,'color':color,'alpha_min':.30078125,'alpha_max':.80078125}
   key=f'e{episode}_region_'+hashlib.sha256(json.dumps(region,sort_keys=True).encode()).hexdigest()[:16]
   regions[key]=region;part['type']='highlight';part['region']=key;part.pop('texture',None);part.pop('color',None)
 (root/f'data/episode{episode}_highlights.json').write_text(json.dumps({'regions':regions,'masks':{}},separators=(',',':'))+'\n')
 path.write_text(json.dumps(catalog,ensure_ascii=False,indent=2)+'\n')
 # Bind each authored button to the same contour and bounds used by its glow.
 graph_path=root/f'data/story_graphs/episode{episode}.json';graph=json.loads(graph_path.read_text())
 for id,record in graph['nodes'].items():
  if record['type']!='scene' or not record['data'].get('controls_art'):continue
  art=record['data']['controls_art']
  for edge in graph['edges']:
   if edge['from']!=id or not edge['port'].startswith('choice:'):continue
   choice=graph['nodes'][edge['to']]['data'];source=choice.pop('source_button')
   matches=[p for p in catalog[art] if p['type']=='highlight' and p.get('source','').startswith(source+'/')]
   if len(matches)!=1:raise ValueError(f'{art}/{source}: expected one authored contour, got {len(matches)}')
   choice['rect']=matches[0]['rect'];choice['mask']=matches[0]['region']
 graph_path.write_text(json.dumps(graph,ensure_ascii=False,indent=2)+'\n')
 retained=set()
 for manifest in (root/'data').glob('episode*_components.json'):
  retained.update(p.get('texture') for parts in json.loads(manifest.read_text()).values() for p in parts)
 for filename in removed-retained:
  file=root/'assets/flash_ui'/filename;file.unlink(missing_ok=True);Path(str(file)+'.import').unlink(missing_ok=True)
 print('Episode',episode,'dynamic contours:',len(regions),flush=True)
if __name__=='__main__':
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('archive',type=Path);a=p.parse_args();build(a.archive)
