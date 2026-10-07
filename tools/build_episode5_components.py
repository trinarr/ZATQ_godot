"""Episode V primitives, dynamic contours and exact authored activity hit bounds."""
import argparse,json,tempfile,zipfile
from pathlib import Path
from build_episode4_components import build as export
from build_episode1_components import Exporter
ROOT=Path(__file__).resolve().parents[1]
def build(archive):
 export(archive,ROOT,episode=5)
 graph_path=ROOT/'data/story_graphs/episode5.json';graph=json.loads(graph_path.read_text())
 with tempfile.TemporaryDirectory() as td:
  temp=Path(td);lib=temp/'LIBRARY';lib.mkdir()
  with zipfile.ZipFile(archive) as z:
   for n in z.namelist():
    if '/ZombieApocalypse/LIBRARY/' in n and n.endswith(('.xml','.png','.jpg')):(lib/Path(n).name).write_bytes(z.read(n))
  r=Exporter(lib,temp,ROOT/'fonts/flash');r.scratch=temp;r.raster_cache={};r.omit_brushes=True
  keys=[]
  for i in range(12):
   hide={'Mov','Light',*[f'ButL{j}' for j in range(12) if j!=i]}
   parts=r.screen('hit', [('Symbol 804',11,0,0,{f'ButL{i}':3},hide)],{'omit_root_shapes':True})
   parts=[p for p in parts if p.get('source','').startswith(f'ButL{i}/')]
   if not parts:raise ValueError(f'Missing keypad hit state {i}')
   rect=union([p['rect'] for p in parts]);keys.append({'text':str(i) if i<10 else '*' if i==10 else '#','rect':rect})
  import csv
  locale=ROOT/'locales/episode5.csv'
  with locale.open(newline='') as f:rows=list(csv.DictReader(f))
  known={row['key'] for row in rows}
  for key in keys:
   text=key['text'];id='episode5.keypad.'+({'*':'star','#':'hash'}.get(text,text));key['text']='@loc:'+id
   if id not in known:rows.append({'key':id,'ru':text,'en':''})
  with locale.open('w',newline='') as f:
   w=csv.DictWriter(f,fieldnames=['key','ru','en'],lineterminator='\n');w.writeheader();w.writerows(rows)
  graph['nodes']['e5_upper_12_v1']['data']['keys']=keys
  parts=[]
  for i in range(19):
   row=r.screen('hit',[('Symbol 907',2,0,0,{'But':i},{'Mov','MvMg'})],{'omit_root_shapes':True})
   parts.extend(p for p in row if p.get('source','').startswith('But/'))
  if not parts:raise ValueError('Missing stewardess QTE hit shape')
  for node in graph['nodes'].values():
   if node['type']=='qte' and node.get('data',{}).get('art','').startswith('e5_hide_3_'):node['data']['target_rect']=union([p['rect'] for p in parts])
 graph_path.write_text(json.dumps(graph,ensure_ascii=False,indent=2)+'\n')
def union(rects):
 x=min(r[0] for r in rects);y=min(r[1] for r in rects);right=max(r[0]+r[2] for r in rects);bottom=max(r[1]+r[3] for r in rects)
 return [x,y,right-x,bottom-y]
if __name__=='__main__':
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('archive',type=Path);a=p.parse_args();build(a.archive)
