"""Usage: python3 tools/build_flash_ui.py /path/to/original.zip
Requires Pillow, fontTools and Inkscape for rebuilding only.
The Godot project itself requires no Flash tooling.
"""
import argparse,tempfile,zipfile
from pathlib import Path
from extract_flash_fonts import extract
from render_flash_ui import Renderer
parser=argparse.ArgumentParser()
parser.add_argument('archive',type=Path)
parser.add_argument('--output',type=Path,default=Path(__file__).resolve().parents[1])
args=parser.parse_args()
output=args.output
with tempfile.TemporaryDirectory() as workspace:
 with zipfile.ZipFile(args.archive) as z:
  doc=next(n for n in z.namelist() if n.endswith('/ZombieApocalypse/DOMDocument.xml'))
  library_prefix=doc.removesuffix('DOMDocument.xml')+'LIBRARY/'
  library=Path(workspace)/'LIBRARY';library.mkdir()
  for name in z.namelist():
   if name.startswith(library_prefix) and name.endswith(('.xml','.png','.jpg')):
    (library/Path(name).name).write_bytes(z.read(name))
  swf=Path(workspace)/'original.swf';swf.write_bytes(z.read('assets/ZombieApocalypse.swf'))
  extract(swf,output/'fonts/flash')
  r=Renderer(library,output/'assets/flash_ui',output/'fonts/flash')
  from build_localized_ui import CleanRenderer
  from ui_components import export_components, menu_plans
  components=CleanRenderer(library,args.output/'assets/flash_ui',args.output/'fonts/flash')
  components.omit_brushes=True
  export_components(components,menu_plans(),args.output)
  def s(n,f=0,x=0,y=0,o=None,h=None):return(f'Symbol {n}',f,x,y,o or {},h or set())
  r.render('background.png',[s(150)])
  r.render('pause.png',[s(83,5,0,61,o={'Butns.But2':1,'Butns.But3':1,'Butns.But4':1,'Butns.But5':1},h={'ForSound'})])
  r.render('item_keys.png',[s(274,x=0,y=30,o={'Weapons':1,'ButExit':1},h={'Txt'})])
  r.render('decision.png',[s(99,y=-18,h={'Txt','But3','But4','But1.Txt','But2.Txt'})])
  r.render('help.png',[s(150),s(147,6)])
  r.render('pause_button.png',[s(88,o={'But':1})])
  for name,num in [('brush',106),('choice',97),('close',156),('arrow',185)]:
   r.render(name+'.png',[s(num,1)],width=400 if name in ['brush','choice'] else 90,height=100)
  for name,fr in [('wake',0),('screams',1),('morning_choice',2),('transport',4),('lift',5),('lift_button',6)]:
   r.render(f'story_{name}.png',[s(2882,fr,o={'Mov':14 if name=='wake' else 4 if name=='lift_button' else 0}),s(88,o={'But':1})])
  for ch in range(7):
   r.render(f'tv_{ch}.png',[s(2882,3,o={'Canals':4,'Canals.Mov':ch}),s(88,o={'But':1})])

  r.render('story_transport_no_keys.png',[s(2882,4,h={'But2'}),s(88,o={'But':1})])
  from PIL import Image
  p=output/'assets/flash_ui/brush.png'
  im=Image.open(p).convert('RGBA');im.crop(im.getbbox()).save(p)
