"""Export a single decorative background plus transparent opening controls.
Usage: python tools/build_opening_layout.py original.zip
"""
import argparse,tempfile,zipfile,os
from pathlib import Path
from PIL import Image,ImageOps
from render_flash_ui import Renderer
class CleanBackground(Renderer):
 def text(self,element):return ''
def build(lib,output):
 fonts=output/'fonts/flash';art=output/'assets/flash_ui'
 bg=CleanBackground(lib,art,fonts);fg=Renderer(lib,art,fonts)
 def export(renderer,name,frame,ov,hide):renderer.render(name+'.png',[('Symbol 2882',frame,0,0,ov,set(hide))])
 for name,frame in [('wake',0),('screams',1),('morning_choice',2),('transport',4),('lift',5),('lift_button',6)]:
  ov={'Mov':14 if name=='wake' else 4 if name=='lift_button' else 0}
  export(bg,'layout_bg_'+name,frame,ov,['Hist','But1','But2'])
  export(fg,'layout_controls_'+name,frame,ov,['Mov'])
 for ch in range(7):
  export(bg,'layout_bg_tv_'+str(ch),3,{'Canals':4,'Canals.Mov':ch},['Pult','Vikl'])
  # Pult and Vikl are the original remote/TV-off controls. The room and TV
  # remain part of the single decorative background.
  fg.render('layout_controls_tv.png',[('Symbol 2844',0,0,272,{},set()),('Symbol 2820',0,379.95,382.4,{},set())]) if ch==0 else None
 export(fg,'layout_controls_transport_no_keys',4,{},['Mov','But2'])
 fg.render('layout_pause.png',[('Symbol 83',5,0,61,{'Butns.But2':1,'Butns.But3':1,'Butns.But4':1,'Butns.But5':1},{'ForSound','Grey'})])
 for file in art.glob('layout_bg_*.png'):
  with Image.open(file) as im:
   source={'layout_bg_wake':'Fon1_1.png','layout_bg_lift_button':'LiftKnop.jpg'}.get(file.stem)
   opaque=ImageOps.fit(Image.open(output/'assets/images'/source).convert('RGBA'),im.size) if source else Image.new('RGBA',im.size,'black')
   opaque.alpha_composite(im.convert('RGBA'));opaque.save(file.with_suffix('.tmp'),format='PNG')
  os.replace(file.with_suffix('.tmp'),file)
def main():
 a=argparse.ArgumentParser();a.add_argument('archive',type=Path);a.add_argument('--output',type=Path,default=Path(__file__).resolve().parents[1]);args=a.parse_args()
 with tempfile.TemporaryDirectory() as tmp:
  lib=Path(tmp)
  with zipfile.ZipFile(args.archive) as z:
   for n in z.namelist():
    if '/ZombieApocalypse/LIBRARY/' in n and n.endswith(('.xml','.png','.jpg')):(lib/Path(n).name).write_bytes(z.read(n))
  build(lib,args.output)
if __name__=='__main__':main()
