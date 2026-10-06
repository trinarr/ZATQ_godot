"""Recover Episode III XFL display lists, reusing identical earlier-episode textures.
Usage: python tools/build_episode3_components.py original.zip
"""
import argparse,json,tempfile,zipfile
from pathlib import Path
from build_episode1_components import Exporter
from build_localized_ui import brushes
from story_graph_format import load_all

ROOT=Path(__file__).resolve().parents[1]
def plans(root):
 nodes=[n for n in load_all(root).values() if n.get('episode',1)==3]
 live={n[k] for n in nodes for k in ['art','background_art','controls_art','decision_art'] if k in n}
 live.update(frame for n in nodes for frame in n.get('animation_frames',[]))
 visuals=json.loads((root/'data/episode3_visuals.json').read_text())
 return {name:([(f"Symbol {v['symbol']}",v['frame'],0,v.get('offset_y',0),v.get('overrides',{}),v.get('hide',[]))],v) for name,v in visuals.items() if name in live}

def retired(root):
 components=json.loads((root/'data/episode3_components.json').read_text())
 nodes=load_all(root)
 masks={c['mask'] for n in nodes.values() for c in n.get('choices',[]) if 'mask' in c}
 live={n[k] for n in nodes.values() for k in ['art','art_on_foot','controls_art','decision_art','background_art'] if k in n}
 live.update(frame for n in nodes.values() for frame in n.get('animation_frames',[]))
 return [p for p in (root/'assets/flash_ui').iterdir() if p.suffix in ['.png'] and p.stem not in masks and
         (p.stem in components or p.stem.removesuffix('_icons') in components or
          (p.stem.startswith(('e3_',)) and p.stem not in live))]

def build(archive,root,only=None):
 destination=root/'assets/flash_ui/episode3_components';destination.mkdir(exist_ok=True)
 with tempfile.TemporaryDirectory() as tmp:
  tmp=Path(tmp);lib=tmp/'LIBRARY';lib.mkdir();photos=tmp/'Images';photos.mkdir()
  with zipfile.ZipFile(archive) as z:
   for n in z.namelist():
    if '/ZombieApocalypse/LIBRARY/' in n and n.endswith(('.xml','.png','.jpg')):(lib/Path(n).name).write_bytes(z.read(n))
    elif n.startswith('assets/Images/') and not n.endswith('/'):(photos/Path(n).name).write_bytes(z.read(n))
  r=Exporter(lib,destination,root/'fonts/flash');r.photos=photos;r.scratch=tmp;r.raster_cache={};r.omit_brushes=True
  result=json.loads((root/'data/episode3_components.json').read_text()) if only else {}
  for name,(items,spec) in sorted(plans(root).items()):
   if only and name not in only:continue
   result[name]=r.screen(name,items,spec)
   print(name,len(result[name]),flush=True)
  brush_sets={}
  for name,(items,spec) in plans(root).items():
   records=[]
   for symbol,frame,x,y,ov,hide in items:records+=brushes(r,symbol,frame,ov,set(hide),transform=(1,0,0,1,x,y))
   if records:brush_sets[name]=records
  for name,parts in result.items():
   for part in parts:
    part['layer']='background'
    x,y,w,h=part['rect']
    for b in brush_sets.get(name,[]):
     bx,by,bw,bh=b['rect']
     if bx<=x+w/2<=bx+bw and by<=y+h/2<=by+bh and w<=bw*1.4 and h<=bh*1.4:part['layer']='foreground';break
    if part['type']=='texture':
     for directory in ['episode1_components','episode2_components']:
      shared=root/'assets/flash_ui'/directory/Path(part['texture']).name
      if shared.exists():part['texture']=directory+'/'+shared.name;break
  (root/'data/episode3_brushes.json').write_text(json.dumps(brush_sets,ensure_ascii=False,indent=2)+'\n')
  (root/'data/episode3_components.json').write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n')
  used={Path(p['texture']).name for ps in result.values() for p in ps if p['type']=='texture' and p['texture'].startswith('episode3_components/')}
  for f in destination.glob('*.png'):
   if f.name not in used:f.unlink();Path(str(f)+'.import').unlink(missing_ok=True)
 for f in retired(root):f.unlink();Path(str(f)+'.import').unlink(missing_ok=True)

if __name__=='__main__':
 p=argparse.ArgumentParser();p.add_argument('archive',type=Path);p.add_argument('--output',type=Path,default=ROOT);p.add_argument('--only',nargs='+');a=p.parse_args();build(a.archive,a.output,a.only)
