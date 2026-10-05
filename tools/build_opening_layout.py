"""Rebuild opening display-list components and shared episode UI.
Usage: python tools/build_opening_layout.py original.zip
"""
import argparse,tempfile,zipfile,os
from pathlib import Path
from PIL import Image,ImageOps
from render_flash_ui import Renderer
class CleanBackground(Renderer):
 def text(self,element):return ''
def main():
 from build_episode1_components import build
 parser=argparse.ArgumentParser();parser.add_argument('archive',type=Path)
 parser.add_argument('--output',type=Path,default=Path(__file__).resolve().parents[1])
 args=parser.parse_args();build(args.archive,args.output)
if __name__=='__main__':main()
