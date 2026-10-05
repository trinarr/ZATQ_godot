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
 from build_episode1_components import build
 parser=argparse.ArgumentParser();parser.add_argument('archive',type=Path)
 parser.add_argument('--output',type=Path,default=Path(__file__).resolve().parents[1])
 args=parser.parse_args();build(args.archive,args.output)
if __name__=='__main__':main()
