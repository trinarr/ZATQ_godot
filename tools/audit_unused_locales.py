"""Report/remove locale rows with no references in runtime or editable source data.
Archived migration manifests remain roots because exporters resolve their markers.
"""
import argparse,csv,re
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
def audit(root=ROOT,remove=False):
 references=set()
 for directory in ['data','scripts','addons/story_graph']:
  for path in (root/directory).rglob('*'):
   if path.suffix in ['.json','.gd']:
    references.update(re.findall(r'@loc:([a-zA-Z0-9_.]+)',path.read_text()))
 unused=[]
 for path in sorted((root/'locales').glob('*.csv')):
  with path.open(newline='',encoding='utf-8-sig') as file:
   reader=csv.DictReader(file);headers=reader.fieldnames;rows=list(reader)
  kept=[]
  for row in rows:
   if row['key'] in references:kept.append(row)
   else:unused.append(row['key'])
  if remove and len(kept)!=len(rows):
   with path.open('w',newline='',encoding='utf-8') as file:
    writer=csv.DictWriter(file,fieldnames=headers,lineterminator='\n');writer.writeheader();writer.writerows(kept)
 return unused
if __name__=='__main__':
 parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--remove',action='store_true');args=parser.parse_args()
 unused=audit(remove=args.remove)
 for key in unused:print(key)
 print(f'{len(unused)} unused locale rows'+(' removed' if args.remove else ''))
