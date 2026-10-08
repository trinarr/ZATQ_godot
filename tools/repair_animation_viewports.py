"""Audit/repair off-stage animation pixels without regenerating story tracks.

python tools/repair_animation_viewports.py ORIGINAL.zip --episodes 1 2 3 4 5 6
For John, supply the normalized archive from build_john_episode.prepare and 101.
--check renders candidate parts but does not change catalogs or project assets.
"""
import argparse
import json
import tempfile
import zipfile
from pathlib import Path
from build_episode1_animations import Timelines
from build_episode1_components import Exporter,plans
from build_episode23_animations import EpisodeTimelines,selected_plans,sequences,render_part
from animation_viewport import animation_viewport,STAGE

ROOT=Path(__file__).resolve().parents[1]

def episode1_sequences(tl,items,spec):
 result={}
 for phase in ['intro','outro']:
  rows=[]
  for tick in range(40 if spec.get('script_cycle') else 81):
   row=[]
   for ri,(symbol,index,x,y,ov,hide) in enumerate(items):
    frame=index;origin=index
    if symbol=='Symbol 2545' and index==11:
     frame=min(tick,11) if phase=='intro' else min(12+tick,15)
     origin=0 if phase=='intro' else 12
    row+=tl.walk(symbol,frame,tick,ov,set(hide),spec,t=(1,0,0,1,x,y),key=str(ri),outro=phase=='outro',origin=origin)
   rows.append(row)
  result[phase]=rows
 return result

def record_pool(tl,items,spec,ep):
 states=episode1_sequences(tl,items,spec) if ep==1 else sequences(tl,items,spec)[0]
 for variable,control in spec.get('control_tracks',{}).items():
  rows=[]
  for index in range(control['frames']):
   row=[]
   for ri,(symbol,frame,x,y,ov,hide) in enumerate(items):
    override=dict(ov);override[control['path']]=index
    row+=tl.walk(symbol,frame,0,override,set(hide),dict(spec,frozen_paths=[control['path']]),t=(1,0,0,1,x,y),key=str(ri),origin=frame)
   rows.append([r for r in row if r.get('source','').startswith(control['path']+'/') or r.get('source','').startswith(control['path']+'.')])
  states[variable]=rows
 pool={}
 for rows in states.values():
  for row in rows:
   for r in row:pool.setdefault(r['key'],[]).append(r)
 return pool

def repair(library,photos,episodes,check=False):
 changes=[];stats={}
 with tempfile.TemporaryDirectory() as td:
  scratch=Path(td)
  for ep in episodes:
   path=ROOT/f'data/episode{ep}_animations.json';catalog=json.loads(path.read_text())
   tl=Timelines(library) if ep==1 else EpisodeTimelines(library)
   selected=plans(ROOT) if ep==1 else selected_plans(ep)
   out=(scratch if check else ROOT/'assets/flash_ui')/f'episode{ep}_animation_parts'
   out.mkdir(parents=True,exist_ok=True)
   renderer=Exporter(library,out,ROOT/'fonts/flash');renderer.scratch=scratch;renderer.raster_cache={};renderer.result_mode=False
   stats[ep]={'scenes':len(catalog['art']),'parts':0,'repaired':0}
   for art,entry in catalog['art'].items():
    if art not in selected:raise ValueError(f'No source plan for {art}')
    items,spec=selected[art];spec=dict(spec)
    if art=='ep1_mainstreet_run':spec['script_cycle']=True
    if art in ['layout_bg_wake','layout_bg_lift_button']:
     spec.update(photo='Fon1_1.png' if art=='layout_bg_wake' else 'LiftKnop.jpg',photo_path='Mov.Mov')
    pool=record_pool(tl,items,spec,ep)
    for key,part in list(entry['parts'].items()):
     if part.get('type')!='texture' or 'eye_lid' in part:continue
     stats[ep]['parts']+=1
     if key not in pool:raise ValueError(f'No source primitive for {art}: {key}')
     records=pool[key]
     ref=max(records,key=lambda r:-abs(r['matrix'][4])-abs(r['matrix'][5])-800*abs(r['matrix'][0]-1)-480*abs(r['matrix'][3]-1))
     viewport=animation_viewport(ref,records,library,photos)
     if viewport==STAGE:continue
     rendered=render_part(renderer,ref,library,photos,viewport)
     if not rendered:continue
     if Path(rendered['texture']).name==Path(part['texture']).name and rendered['rect']==part['rect']:continue
     # Keep layer, blur and other metadata added by subsequent migration fixes.
     replacement={**part,'texture':rendered['texture'],'rect':rendered['rect']}
     change={'episode':ep,'art':art,'key':key,'source':ref['source'],'viewport':list(viewport),'before':part,'after':replacement}
     changes.append(change);stats[ep]['repaired']+=1
     if not check:entry['parts'][key]=replacement
     print(('NEEDS REPAIR' if check else 'REPAIRED'),ep,art,part['rect'],'->',replacement['rect'],flush=True)
   if not check:path.write_text(json.dumps(catalog,separators=(',',':'))+'\n')
   print(ep,stats[ep],flush=True)
 return changes,stats

def main():
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('archive',type=Path)
 p.add_argument('--episodes',nargs='+',type=int,default=list(range(1,7)))
 p.add_argument('--check',action='store_true');p.add_argument('--report',type=Path)
 args=p.parse_args()
 with tempfile.TemporaryDirectory() as td:
  root=Path(td);lib=root/'LIBRARY';photos=root/'Images';lib.mkdir();photos.mkdir()
  with zipfile.ZipFile(args.archive) as z:
   for n in z.namelist():
    if '/ZombieApocalypse/LIBRARY/' in n and n.endswith(('.xml','.png','.jpg')):(lib/Path(n).name).write_bytes(z.read(n))
    elif n.startswith('assets/Images/') and not n.endswith('/'):(photos/Path(n).name).write_bytes(z.read(n))
  changes,stats=repair(lib,photos,args.episodes,args.check)
 if args.report:args.report.write_text(json.dumps({'stats':stats,'changes':changes},ensure_ascii=False,indent=2)+'\n')
 return int(args.check and bool(changes))

if __name__=='__main__':raise SystemExit(main())
