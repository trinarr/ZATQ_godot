"""Rebuild adaptive UI from the original Flash archive.
Usage: python tools/build_adaptive_ui.py original.zip
Requires the same dependencies as render_flash_ui.py.
"""
import argparse, tempfile, zipfile
from pathlib import Path
from render_flash_ui import Renderer

def main():
 parser=argparse.ArgumentParser()
 parser.add_argument('archive',type=Path)
 parser.add_argument('--output',type=Path,default=Path(__file__).resolve().parents[1])
 args=parser.parse_args()
 with tempfile.TemporaryDirectory() as tmp:
  lib=Path(tmp)/'LIBRARY';lib.mkdir()
  with zipfile.ZipFile(args.archive) as z:
   for name in z.namelist():
    if '/ZombieApocalypse/LIBRARY/' in name and name.endswith(('.xml','.png','.jpg')):
     (lib/Path(name).name).write_bytes(z.read(name))
  r=Renderer(lib,args.output/'assets/flash_ui',args.output/'fonts/flash')
  def s(n,f=0,x=0,y=0,o=None,h=None):return(f'Symbol {n}',f,x,y,o or {},h or set())
  r.render('adaptive_menu.png',[s(118),s(132,8,415,70)])
  r.render('adaptive_menu_off.png',[s(118,o={'SndCheck':1}),s(132,8,415,70)])
  for i in range(12):
   r.render(f'adaptive_selector_{i}.png',[s(211,o={'EpImg':i,'LeftOpt':2 if i in [1,3,6,8,10] else 0,'RightOpt':1 if i in [1,3,6,8,10] else 0,'But3':1,'But4':1,'But1':1,'But2':1},h={'NameTxt','EpOptions','InfoOpt','AnsNumb','txtWins','txtLoses'})])
  r.render('adaptive_help.png',[s(147,6)])
  r.render('adaptive_metro_background.png',[s(2925,2,h={'Hist','But1','But2'})])
  r.render('adaptive_metro_controls.png',[s(2925,2,h={'Mov'})])

if __name__=='__main__':main()
