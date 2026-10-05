"""One-time migration to separate UI and episode CSV tables. Refuses a second run."""
import csv,json,re
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
TABLES={};P='@loc:'
def text(table,key,value):
 if value.startswith(P):return value
 TABLES.setdefault(table,{})[key]=value
 return P+key
def extract(value,prefix,table):
 if isinstance(value,dict):
  return {k:text(table,prefix+'.'+k,v) if k in ['text','speaker','title','description','text_on_foot'] and isinstance(v,str) and v else extract(v,prefix+'.'+k,table) for k,v in value.items()}
 if isinstance(value,list):return [extract(v,prefix+'.'+str(i),table) for i,v in enumerate(value)]
 return value
def main():
 if (ROOT/'locales/ui.csv').exists():raise SystemExit('Tables already exist; do not overwrite authored translations')
 for n in [1,2,3]:
  p=ROOT/f'data/story_graphs/episode{n}.json';g=json.loads(p.read_text());g=extract(g,f'episode{n}',f'episode{n}');p.write_text(json.dumps(g,ensure_ascii=False,indent=2)+'\n')
 p=ROOT/'data/story_graphs/examples/activity_demo.json'
 p.write_text(json.dumps(extract(json.loads(p.read_text()),'episode3.examples.activity_demo','episode3'),ensure_ascii=False,indent=2)+'\n')
 for filename,ep in [('opening',1),('city_routes',1),('episode1_routes',1),('episode2_routes',2)]:
  p=ROOT/f'data/{filename}.json';g=extract(json.loads(p.read_text()),f'episode{ep}.archive.{filename}',f'episode{ep}');p.write_text(json.dumps(g,ensure_ascii=False,indent=2)+'\n')
 p=ROOT/'data/selectors.json';entries=json.loads(p.read_text());number=0
 for i,e in enumerate(entries):
  if e['kind']=='episodes':e['episode']={0:1,2:2,4:3,5:0,7:4,9:5,11:6}[e['frame']]
  for k in ['title','description']:
   table=f'episode{e["episode"]}' if i<3 else 'ui'
   key=f'{table}.selector.{k}' if i<3 else f'ui.selectors.{i}.{k}'
   e[k]=text(table,key,e[k])
 p.write_text(json.dumps(entries,ensure_ascii=False,indent=2)+'\n')
 # Only player-facing literals; editor labels and vendor SDKs remain editor UI.
 for p in list((ROOT/'scripts').rglob('*.gd')):
  if p.name=='localization.gd':continue
  s=p.read_text();counter=0
  def repl(m):
   nonlocal counter
   literal=m[0]
   if not re.search('[А-Яа-яЁё]',literal):return literal
   counter+=1;value=json.loads(literal);key='ui.'+p.stem+'.'+str(counter)
   marker=text('ui',key,value)
   # GDScript default arguments must remain constant. Helpers resolve markers.
   if p.name=='main.gd' and value=='Начать' and s[max(0,m.start()-40):m.start()].endswith('confirm_label: String = '):return json.dumps(marker)
   return 'LOC.text('+json.dumps(marker)+')'
  s=re.sub(r'"(?:[^"\\]|\\.)*"',repl,s)
  if p.name=='main.gd':
   s=s.replace('"CH %d"','LOC.text("@loc:ui.main.channel_format")')
   text('ui','ui.main.channel_format','CH %d')
  if counter:
   lines=s.splitlines();index=next(i for i,l in enumerate(lines) if l.startswith('extends '))+1
   lines.insert(index,'const LOC := preload("res://scripts/core/localization.gd")');p.write_text('\n'.join(lines)+'\n')
 for table,rows in TABLES.items():
  with (ROOT/f'locales/{table}.csv').open('w',newline='',encoding='utf-8') as f:
   w=csv.writer(f,lineterminator='\n');w.writerow(['key','ru','en']);w.writerows((k,v,'') for k,v in sorted(rows.items()))
  print(table,len(rows),'strings')
if __name__=='__main__':main()
