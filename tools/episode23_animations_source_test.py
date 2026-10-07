"""Compare every exported layer pose/color with the original XFL records.
Usage: python tools/episode23_animations_source_test.py /path/to/LIBRARY
"""
import argparse,json,math
from pathlib import Path
from PIL import Image
from build_episode23_animations import EpisodeTimelines,selected_plans,sequences,ROOT
from build_localized_ui import combine

def inverse(m):
 a,b,c,d,x,y=m;det=a*d-b*c
 assert abs(det)>1e-9
 return d/det,-b/det,-c/det,a/det,(c*y-d*x)/det,(b*x-a*y)/det

def verify(library):
 checks=0
 for ep in [2,3]:
  data=json.loads((ROOT/f'data/episode{ep}_animations.json').read_text())
  captions=json.loads((ROOT/f'data/episode{ep}_text_animations.json').read_text())
  plans=selected_plans(ep);tl=EpisodeTimelines(library)
  assert data['fps']==19
  for art,spec in data['art'].items():
   items,source_spec=plans[art];source,_=sequences(tl,items,source_spec)
   assert len(spec['intro'])>=source_spec['durations'].get('intro',1)
   if source_spec.get('qte'):assert len(spec['intro'])==source_spec['durations']['intro']
   references={}
   for phase in ['intro','outro']:
    # QTE exits are not played: the final visual is retained for the outcome.
    if phase=='outro' and spec.get('outro_hold'):
     assert spec['outro']==[spec['intro'][-1]]
     continue
    for i,row in enumerate(spec[phase]):
     records={r['key']:r for r in source[phase][i]}
     assert [r[0] for r in row]==[r['key'] for r in source[phase][i] if r['key'] in spec['parts']],(art,phase,i,'display list order')
     for key,pose,color in row:
      record=records[key]
      assert all(abs(a-b)<1e-6 for a,b in zip(color,record['color'])),(art,phase,i,'color')
      reference=combine(inverse(pose),record['matrix'])
      if key in references:assert all(abs(a-b)<0.002 for a,b in zip(reference,references[key])),(art,phase,i,'matrix')
      else:references[key]=reference
      checks+=1
   for part in spec['parts'].values():
    if part.get('texture'):
     path=ROOT/'assets/flash_ui'/part['texture'];assert path.exists(),path
     with Image.open(path) as im:im.verify()
    assert all(math.isfinite(x) for x in part['rect'])
   texts,_=sequences(tl,items,source_spec,True)
   for phase in ['intro','outro']:
    if phase=='outro' and spec.get('outro_hold'):
     assert captions[art]['outro']==[captions[art]['intro'][-1]]
     continue
    for i,row in enumerate(captions[art][phase]):
     expected=[[' '.join(r['text'].split()),list(r['matrix']),list(r['color'])] for r in texts[phase][i]]
     assert row==expected,(art,phase,i,'native caption')
     checks+=1
  print('Episode',ep,':',len(data['art']),'XFL scene tracks verified')
 print('PASS:',checks,'source pose/color/caption comparisons; PNG resources readable')
if __name__=='__main__':
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('library',type=Path);verify(p.parse_args().library)
