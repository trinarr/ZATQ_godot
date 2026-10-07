"""Compare Episode V visual poses/colors to original XFL, including independent controls."""
import argparse,json
from pathlib import Path
from build_episode23_animations import EpisodeTimelines,selected_plans,sequences
from build_localized_ui import combine
ROOT=Path(__file__).resolve().parents[1]
def verify(library):
 actual=json.loads((ROOT/'data/episode5_animations.json').read_text())['art'];tl=EpisodeTimelines(library);checks=0
 for art,(items,spec) in selected_plans(5).items():
  if art not in actual:continue
  entry=actual[art];states,_=sequences(tl,items,spec)
  controls={}
  for variable,control in spec.get('control_tracks',{}).items():
   rows=[]
   for i in range(control['frames']):
    row=[]
    for ri,(symbol,frame,x,y,ov,hide) in enumerate(items):
     override=dict(ov);override[control['path']]=i
     row+=tl.walk(symbol,frame,0,override,set(hide),dict(spec,frozen_paths=[control['path']]),t=(1,0,0,1,x,y),key=str(ri),origin=frame)
    rows.append([r for r in row if r.get('source','').startswith(control['path']+'/') or r.get('source','').startswith(control['path']+'.')])
   controls[variable]=rows
  pool={}
  for frames in [*states.values(),*controls.values()]:
   for row in frames:
    for record in row:pool.setdefault(record['key'],[]).append(record)
  refs={}
  for key in entry['parts']:
   assert key in pool,(art,key)
   ref=max(pool[key],key=lambda r:-abs(r['matrix'][4])-abs(r['matrix'][5])-800*abs(r['matrix'][0]-1)-480*abs(r['matrix'][3]-1))
   refs[key]=ref['matrix'];checks+=1
  for phase,frames in {**{'intro':entry['intro'],'outro':entry['outro']},**entry.get('variables',{})}.items():
   if phase=='outro' and entry['outro_hold']:
    assert frames==[entry['intro'][-1]],art;checks+=1;continue
   for index,frame in enumerate(frames):
    expected=[]
    for rec in (controls if phase in controls else states)[phase][index]:
     k=rec['key']
     if k not in refs:continue
     a,b,c,d,x,y=refs[k];det=a*d-b*c
     if abs(det)<1e-9:continue
     inverse=(d/det,-b/det,-c/det,a/det,(c*y-d*x)/det,(b*x-a*y)/det)
     expected.append([k,[round(v,6) for v in combine(rec['matrix'],inverse)],[round(v,6) for v in rec['color']]])
    assert frame==expected,(art,phase,index);checks+=1
  for part in entry['parts'].values():
   assert 'Symbol 539' not in part.get('source',''),art
   if 'texture' in part:assert (ROOT/'assets/flash_ui'/part['texture']).is_file(),part
 assert len(actual)==103
 lock=actual['e5_plane_15_v1']['variables']['lock'];assert len(lock)==15 and len({str(row[0][1]) for row in lock})==15
 light=actual['e5_upper_12_v1']['variables']['light'];assert len(light)==33 and light[1]!=light[17]
 print(f'PASS: {checks} XFL pose/color checks; {len(actual)} scenes; 15 lock and 33 indicator frames.')
if __name__=='__main__':
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('library',type=Path);verify(p.parse_args().library)
