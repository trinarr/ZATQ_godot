"""Export the original ResultBad panel as transparent UI over one metal background.
Usage: python tools/build_result_ui.py original.zip
"""
import argparse,base64,tempfile,zipfile,io
from pathlib import Path
from PIL import Image
from render_flash_ui import Renderer,NS

class ResultRenderer(Renderer):
 def shape(self,element):
  bitmap=element.find('./x:fills/x:FillStyle/x:BitmapFill',NS)
  if bitmap is not None:
   name=bitmap.get('bitmapPath')
   if name=='Bitmap 29.png':return '' # The metal texture fills the safe area separately.
   if name=='Bitmap 56.png':
    # The original metal body covered the bottom 22px of this header bitmap.
    buffer=io.BytesIO();Image.open(self.library/name).crop((0,0,729,60)).save(buffer,format='PNG')
    data=base64.b64encode(buffer.getvalue()).decode()
    return f'<image x="36" y="0" width="729" height="60" xlink:href="data:image/png;base64,{data}"/>'
   if name=='Bitmap 31.png':
    # Inkscape renders this one-pixel translucent strip incorrectly as an SVG
    # pattern with a 279x vertical transform. Use the identical image directly.
    data=base64.b64encode((self.library/name).read_bytes()).decode()
    return f'<image x="-6" y="0" width="659" height="279" preserveAspectRatio="none" xlink:href="data:image/png;base64,{data}"/>'
  return super().shape(element)

def build(library,output):
 art=output/'assets/flash_ui';r=ResultRenderer(library,art,output/'fonts/flash')
 Image.open(library/'Bitmap 29.png').save(art/'result_background.png')
 for name,alive in [('result_dead',False),('result_alive',True)]:
  r.render(name+'.png',[('Symbol 59',6,0,0,{'Mov.Rezt':0,'Mov.Rezt.Symb':int(alive),'Mov.But1':1,'Mov.But2':1},{'Itog','Mov.Rezt.Txt','Mov.Rezt.Opt','Mov.But3','Mov.StrBut3'})])

def main():
 parser=argparse.ArgumentParser();parser.add_argument('archive',type=Path)
 parser.add_argument('--output',type=Path,default=Path(__file__).resolve().parents[1]);args=parser.parse_args()
 with tempfile.TemporaryDirectory() as tmp:
  library=Path(tmp)
  with zipfile.ZipFile(args.archive) as z:
   for name in z.namelist():
    if '/ZombieApocalypse/LIBRARY/' in name and name.endswith(('.xml','.png','.jpg')):
     (library/Path(name).name).write_bytes(z.read(name))
  build(library,args.output)
if __name__=='__main__':main()
