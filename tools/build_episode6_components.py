"""Export VI primitives; kitchen buttons use invisible authored HIT shapes.
They are not red overlays in Flash: do not draw their black HIT-state artwork.
"""
import argparse,json,tempfile,zipfile
from pathlib import Path
from build_episode3_components import build as export
from build_episode1_components import Exporter,shared_texture_references
ROOT=Path(__file__).resolve().parents[1]
def bind(archive):
 catalog_path=ROOT/'data/episode6_components.json';catalog=json.loads(catalog_path.read_text())
 graph_path=ROOT/'data/story_graphs/episode6.json';graph=json.loads(graph_path.read_text())
 with tempfile.TemporaryDirectory() as td:
  temp=Path(td);lib=temp/'LIBRARY';lib.mkdir()
  with zipfile.ZipFile(archive) as z:
   for n in z.namelist():
    if '/ZombieApocalypse/LIBRARY/' in n and n.endswith(('.xml','.png','.jpg')):(lib/Path(n).name).write_bytes(z.read(n))
  r=Exporter(lib,temp,ROOT/'fonts/flash');r.scratch=temp;r.raster_cache={};r.omit_brushes=True
  parts=r.screen('hit',[('Symbol 575',1,0,0,{'But1':4,'But2':4},{'Mov'})],{'omit_root_shapes':True,'omit_symbols':['Symbol 539']})
  for edge in graph['edges']:
   if edge['from']!='e6_boats_2_v1' or not edge['port'].startswith('choice:'):continue
   choice=graph['nodes'][edge['to']]['data'];source=choice.pop('source_button',None)
   if source is None:continue
   hits=[p['rect'] for p in parts if p.get('source','').startswith(source+'/')]
   assert len(hits)==1,(source,hits)
   choice['rect']=hits[0]
 catalog['e6_boats_2_v1_controls']=[]
 catalog_path.write_text(json.dumps(catalog,ensure_ascii=False,indent=2)+'\n')
 graph_path.write_text(json.dumps(graph,ensure_ascii=False,indent=2)+'\n')
 (ROOT/'data/episode6_highlights.json').write_text('{"regions":{},"masks":{}}\n')
 retained=shared_texture_references(ROOT)
 for file in (ROOT/'assets/flash_ui/episode6_components').glob('*.png'):
  if 'episode6_components/'+file.name not in retained:file.unlink();Path(str(file)+'.import').unlink(missing_ok=True)
if __name__=='__main__':
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('archive',type=Path);p.add_argument('--bind-only',action='store_true');a=p.parse_args()
 if not a.bind_only:export(a.archive,ROOT,episode=6)
 bind(a.archive)
