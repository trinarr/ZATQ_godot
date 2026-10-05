"""Audit translation keys, episode ownership, and missing player-facing text."""
import csv,json,re
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
def run():
 tables={};count=0
 for p in sorted((ROOT/'locales').glob('*.csv')):
  with p.open(newline='',encoding='utf-8-sig') as f:
   reader=csv.DictReader(f);assert reader.fieldnames[:2]==['key','ru'],p
   rows=list(reader)
  keys=[r['key'] for r in rows]
  assert len(keys)==len(set(keys)),f'Duplicate keys: {p}'
  assert all(k.startswith(p.stem+'.') for k in keys),p
  assert all(r['ru'] for r in rows),f'Missing source: {p}'
  tables.update({r['key']:r for r in rows});count+=len(rows)
 def audit(v,prefix=None):
  if isinstance(v,str) and v.startswith('@loc:'):
   key=v[5:];assert key in tables,f'Missing key: {key}'
   if prefix:assert key.startswith(prefix+'.'),(prefix,key)
  elif isinstance(v,dict):
   for k,x in v.items():
    if k in ['text','speaker','title','description','text_on_foot'] and isinstance(x,str) and x:assert x.startswith('@loc:'),(k,x)
    audit(x,prefix)
  elif isinstance(v,list):
   for x in v:audit(x,prefix)
 for n in [1,2,3]:audit(json.loads((ROOT/f'data/story_graphs/episode{n}.json').read_text()),f'episode{n}')
 audit(json.loads((ROOT/'data/story_graphs/examples/activity_demo.json').read_text()),'episode3')
 for entry in json.loads((ROOT/'data/selectors.json').read_text()):audit(entry,'episode'+str(entry['episode']) if entry.get('episode') in [1,2,3] else 'ui')
 for name,blocks in json.loads((ROOT/'data/ui_text_layout.json').read_text()).items():audit(blocks,'episode1' if name.startswith('layout_controls_') or name=='adaptive_metro_controls' else 'ui')
 for p in (ROOT/'scripts').rglob('*.gd'):
  for key in re.findall(r'@loc:([a-zA-Z0-9_.]+)',p.read_text()):assert key in tables,(p,key)
  assert not re.search(r'"(?:[^"\\]|\\.)*[А-Яа-яЁё](?:[^"\\]|\\.)*"',p.read_text()),f'Inline Russian: {p}'
 print(f'PASS: {count} translations, unique keys, all runtime references, separate UI and episode tables')
if __name__=='__main__':run()
