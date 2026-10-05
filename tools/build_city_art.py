"""Rebuild city-route art from the original ZIP using Pillow, fontTools, Inkscape.
Usage: python tools/build_city_art.py /path/to/original.zip
The runtime needs only the generated PNGs; no Flash player is used.
"""
import argparse,base64,json,tempfile,zipfile,os
from pathlib import Path
from PIL import Image
from render_flash_ui import Renderer, FONT_IDS, NS

class CityRenderer(Renderer):
 def text(self,e):
  body=super().text(e)
  # Several decompiled narrative boxes are 824px wide on an 800px stage.
  # Fit glyph advances into the visible stage without changing line breaks.
  longest=0.0
  for run in e.findall('./x:textRuns/x:DOMTextRun',NS):
   attrs=run.find('./x:textAttrs/x:DOMTextAttrs',NS);chars=run.findtext('x:characters','',NS)
   if attrs is None:continue
   font=self.fonts[FONT_IDS.get(attrs.get('face'),2)];scale=float(attrs.get('size','24'))/font['head'].unitsPerEm;cmap=font.getBestCmap()
   for line in chars.replace('\r','\n').split('\n'):
    longest=max(longest,sum(font['hmtx'][cmap.get(ord(char),'.notdef')][0]*scale for char in line))
  available=min(float(e.get('width','800'))-4,775.0)
  ratio=min(1.0,available/max(1.0,longest))
  return f'<g transform="scale({ratio:g} 1)">{body}</g>'
 def symbol(self,name,frame=0,overrides=None,hide=None,path='',depth=0):
  body=super().symbol(name,frame,overrides,hide,path,depth)
  if self.photo and path==self.photo_path:
   file=self.photos/self.photo
   with Image.open(file) as im:width,height=im.size
   mime='image/png' if file.suffix.lower()=='.png' else 'image/jpeg'
   url='data:'+mime+';base64,'+base64.b64encode(file.read_bytes()).decode()
   body=f'<image width="{width}" height="{height}" xlink:href="{url}"/>'+body
  return body

def main():
 from build_episode1_components import build
 parser=argparse.ArgumentParser();parser.add_argument('archive',type=Path)
 parser.add_argument('--output',type=Path,default=Path(__file__).resolve().parents[1])
 args=parser.parse_args();build(args.archive,args.output)
if __name__=='__main__':main()
