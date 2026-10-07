"""Export native caption motion/alpha; never bake letters into textures."""
import argparse,json
from pathlib import Path
from build_episode1_components import plans
from build_episode1_animations import Timelines
ROOT=Path(__file__).resolve().parents[1]
def build(library):
 tl=Timelines(library);result={}
 for art,(items,spec) in plans(ROOT).items():
  if 'controls' in art or art.startswith(('item','result','decision','ep2_','city_decision')):continue
  phases={};anchors={}
  if art=='ep1_mainstreet_run':spec=dict(spec,script_cycle=True)
  for phase in ['intro','outro']:
   frames=[]
   for tick in range(40 if spec.get('script_cycle') else 81):
    row=[]
    for ri,(symbol,index,x,y,ov,hide) in enumerate(items):
     frame=index;origin=index
     if symbol=='Symbol 2545' and index==11:
      frame=min(tick,11) if phase=='intro' else min(12+tick,15);origin=0 if phase=='intro' else 12
     for r in tl.walk(symbol,frame,tick,ov,set(hide),spec,t=(1,0,0,1,x,y),key=str(ri),outro=phase=='outro',origin=origin,text_only=True):
      text=' '.join(r['text'].split())
      row.append([text,list(r['matrix']),list(r['color'])]);anchors[text]=list(r['matrix'])
    frames.append(row)
   while len(frames)>1 and frames[-1]==frames[-2]:frames.pop()
   phases[phase]=frames
  if any(len(f)>1 for f in phases.values()):result[art]={'anchors':anchors,**phases}
 (ROOT/'data/episode1_text_animations.json').write_text(json.dumps(result,separators=(',',':'),ensure_ascii=False)+'\n')
 print(len(result),'native caption timelines')
if __name__=='__main__':
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('library',type=Path);build(p.parse_args().library)
