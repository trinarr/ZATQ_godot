"""Migrate existing authored catalogs without changing any MovieClip keyframes.
Usage: python tools/migrate_eye_closure.py extracted/LIBRARY
"""
import argparse,json
from pathlib import Path
from build_episode23_animations import EpisodeTimelines,selected_plans,sequences
from eye_closure_parts import eye_part,export_texture,annotate
ROOT=Path(__file__).resolve().parents[1]
def migrate(lib):
 export_texture(lib,ROOT)
 for ep in [1,3]:
  path=ROOT/f'data/episode{ep}_animations.json';data=json.loads(path.read_text())
  plans=selected_plans(ep) if ep==3 else {}
  tl=EpisodeTimelines(lib)
  for art,spec in data['art'].items():
   eyes={k:p for k,p in spec['parts'].items() if p.get('source','').endswith(('/Symbol 325','/Symbol 327'))}
   if not eyes:continue
   if ep==1:
    # The preceding eye-closure fix retains the full source bounds already.
    for p in eyes.values():
     if 'eye_lid' in p:continue
     side='upper' if p['source'].endswith('/Symbol 327') else 'lower'
     x,y=p['rect'][:2]
     p.update(eye_part(p['source'],(1,0,0,1,x,y+259.95 if side=='upper' else y)))
   else:
    items,plan=plans[art];states,_=sequences(tl,items,plan);pool={}
    for fs in states.values():
     for row in fs:
      for rec in row:pool.setdefault(rec['key'],[]).append(rec)
    for key,p in eyes.items():
     ref=max(pool[key],key=lambda r:-abs(r['matrix'][4])-abs(r['matrix'][5])-800*abs(r['matrix'][0]-1)-480*abs(r['matrix'][3]-1))
     p.update(eye_part(p['source'],ref['matrix']))
   if art in ['e3_north_11','e3_opening_4']:
    blurry=1776 if art=='e3_north_11' else 1891
    sharp=1781 if art=='e3_north_11' else 1893
    bg=[p for p in spec['parts'].values() if p.get('type')=='texture' and 'eye_lid' not in p]
    bg[0].update(texture=bg[1]['texture'],blur={'sigma':[2.5,2.5],'angle':0,'source_bitmap':f'Bitmap {sharp}.png','replaces_bitmap':f'Bitmap {blurry}.png'})
   annotate(spec)
   print(ep,art,len(eyes),'shared eyelids',spec.get('eye_blur','no blur pair'))
  path.write_text(json.dumps(data,separators=(',',':'))+'\n')
if __name__=='__main__':
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('library',type=Path);a=p.parse_args();migrate(a.library)
