"""Rebuild Episode I backgrounds/controls from the original Flash ZIP.
Usage: python tools/build_episode1_art.py original.zip
Requires Pillow, fontTools, and Inkscape. Generated PNGs ship with the patch.
"""
import argparse,json,tempfile,zipfile,os
from pathlib import Path
from PIL import Image
from build_city_art import CityRenderer

class BackgroundRenderer(CityRenderer):
 def symbol(self,name,*args,**kwargs):
  if name in getattr(self,'omit_symbols',set()):return ''
  previous=getattr(self,'active_depth',0);self.active_depth=args[4] if len(args)>4 else kwargs.get('depth',0)
  try:return super().symbol(name,*args,**kwargs)
  finally:self.active_depth=previous
 def shape(self,element):
  if getattr(self,'omit_root_shapes',False) and self.active_depth==0:return ''
  return super().shape(element)
 def text(self,element):
  return super().text(element) if self.retain_text else ''

def main():
 parser=argparse.ArgumentParser();parser.add_argument('archive',type=Path)
 parser.add_argument('--output',type=Path,default=Path(__file__).resolve().parents[1]);args=parser.parse_args()
 output=args.output;manifest=json.loads((output/'data/episode1_visuals.json').read_text())
 with tempfile.TemporaryDirectory() as tmp:
  library=Path(tmp)/'LIBRARY';photos=Path(tmp)/'Images';library.mkdir();photos.mkdir()
  with zipfile.ZipFile(args.archive) as z:
   for name in z.namelist():
    if '/ZombieApocalypse/LIBRARY/' in name and name.endswith(('.xml','.png','.jpg')):
     (library/Path(name).name).write_bytes(z.read(name))
    elif name.startswith('assets/Images/') and not name.endswith('/'):
     (photos/Path(name).name).write_bytes(z.read(name))
  r=BackgroundRenderer(library,output/'assets/flash_ui',output/'fonts/flash');r.photos=photos
  for key,item in manifest.items():
   r.omit_root_shapes=item.get('omit_root_shapes',False);r.omit_symbols=set(item.get('omit_symbols',[]));r.photo=item.get('photo','');r.photo_path=item.get('photo_path','Mov.Mov');r.retain_text=item.get('retain_text',False)
   r.render(key+'.png',[(f'Symbol {item["symbol"]}',item['frame'],0,0,item.get('overrides',{}),set(item.get('hide',[])))])
   if item.get('crop'):
    file=output/'assets/flash_ui'/(key+'.png')
    with Image.open(file) as im:cropped=im.crop(item['crop']);cropped.save(file.with_suffix('.tmp'),format='PNG')
    os.replace(file.with_suffix('.tmp'),file)
   if not item.get('transparent',False) and not key.endswith('_controls') and key != 'ep1_result_alive':
    file=output/'assets/flash_ui'/(key+'.png')
    with Image.open(file) as im:
     opaque=Image.new('RGBA',im.size,'black');opaque.alpha_composite(im.convert('RGBA'));temporary=file.with_suffix('.tmp');opaque.save(temporary,format='PNG')
    os.replace(temporary,file)
    with file.open('rb') as complete:os.fsync(complete.fileno())
if __name__=='__main__':main()
