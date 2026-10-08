"""Resolve the panorama patch's JSON conflicts while retaining local tracks.

Run from the repository root after applying zombie_panorama_viewport_fix.patch:
    python tools/resolve_panorama_conflicts.py

Reads Git's stage 2 (the local version) for conflicted catalogs, changes only
the audited texture paths/rects, then stages those catalogs as resolved.
"""
import argparse
import json
import os
import subprocess
import tempfile
from pathlib import Path

def git(root,*args):
 return subprocess.check_output(['git',*args],cwd=root)

def resolve(root,episodes=(3,6)):
 report=json.loads((root/'docs/animation_viewport_audit.json').read_text())
 pending=[]
 for episode in episodes:
  name=f'data/episode{episode}_animations.json'
  unmerged=bool(git(root,'ls-files','--unmerged','--',name))
  raw=git(root,'show',f':2:{name}') if unmerged else (root/name).read_bytes()
  catalog=json.loads(raw)
  changes=[c for c in report['changes'] if c['episode']==episode]
  if not changes:raise ValueError(f'No audited replacements for episode {episode}')
  for change in changes:
   art,key=change['art'],change['key']
   part=catalog['art'][art]['parts'][key]
   before,after=change['before'],change['after']
   # Do not silently replace an unrelated/newly authored primitive.
   if part.get('texture') not in [before['texture'],after['texture']]:
    raise ValueError(f'{art}: unexpected local texture {part.get("texture")}')
   if part.get('rect') not in [before['rect'],after['rect']]:
    raise ValueError(f'{art}: unexpected local reference rectangle')
   if not (root/'assets/flash_ui'/after['texture']).is_file():
    raise ValueError(f'Missing new texture: {after["texture"]}')
   part['texture']=after['texture'];part['rect']=after['rect']
  pending.append((name,json.dumps(catalog,separators=(',',':'))+'\n',unmerged,len(changes)))
 # Validate both catalogs before changing any files or the index.
 for name,text,unmerged,count in pending:
  path=root/name
  fd,tmp=tempfile.mkstemp(prefix=path.name+'.',dir=path.parent)
  try:
   with os.fdopen(fd,'w') as stream:stream.write(text)
   os.replace(tmp,path)
  finally:
   if os.path.exists(tmp):os.unlink(tmp)
  if unmerged:subprocess.run(['git','add','--',name],cwd=root,check=True)
  print(f'{name}: {count} replacements; '+('conflict resolved and staged' if unmerged else 'catalog updated'))

def main():
 parser=argparse.ArgumentParser(description=__doc__)
 parser.add_argument('--episodes',nargs='+',type=int,default=[3,6])
 args=parser.parse_args()
 root=Path(subprocess.check_output(['git','rev-parse','--show-toplevel'],text=True).strip())
 resolve(root,args.episodes)

if __name__=='__main__':main()
