"""Recover metal answer plates from NewItem / Symbol 99 and its button 97.
Run with the original ZIP. Native controls own captions and input in Godot.
"""
import argparse,json,tempfile,zipfile
from pathlib import Path
from build_episode1_components import Exporter
ROOT=Path(__file__).resolve().parents[1]
def build(archive,root=ROOT):
 destination=root/'assets/flash_ui/dialog_components'
 destination.mkdir(exist_ok=True)
 with tempfile.TemporaryDirectory() as tmp:
  tmp=Path(tmp);library=tmp/'LIBRARY';library.mkdir()
  with zipfile.ZipFile(archive) as z:
   for name in z.namelist():
    if '/ZombieApocalypse/LIBRARY/' in name and name.endswith(('.xml','.png','.jpg')):
     (library/Path(name).name).write_bytes(z.read(name))
  r=Exporter(library,destination,root/'fonts/flash')
  r.scratch=tmp;r.photos=tmp;r.raster_cache={};r.omit_brushes=False
  def symbol(n,frame=0):return r.screen('dialog',[(f'Symbol {n}',frame,0,0,{},[])])
  plate=symbol(93)
  disabled=symbol(97,5)
  assert len(plate)==1 and len(disabled)==2
  # Keep one plate texture. Disabled/hover/pressed states use original tint.
  parts={'decision_plate':plate,'decision_disabled_mark':[disabled[-1]],'speaker_plate':symbol(215)}
  for records in parts.values():
   for p in records:p['layer']='background'
  (root/'data/dialog_components.json').write_text(json.dumps(parts,indent=2)+'\n')
  used={p['texture'].split('/')[-1] for records in parts.values() for p in records}
  for path in destination.glob('*.png'):
   if path.name not in used:
    path.unlink();Path(str(path)+'.import').unlink(missing_ok=True)
 for filename in ['ui_brush_layout','episode1_brushes']:
  path=root/f'data/{filename}.json';data=json.loads(path.read_text())
  for name in ['decision','city_decision_3','ep2_decision_4']:data.pop(name,None)
  path.write_text(json.dumps(data,indent=2)+'\n')
 print('PASS: original metal plate and unavailable-answer mark; shader impostors removed')
if __name__=='__main__':
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('archive',type=Path);a=p.parse_args();build(a.archive)
