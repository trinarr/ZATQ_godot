"""Export native caption motion/alpha; never bake letters into textures."""
import argparse,json
from pathlib import Path
from build_episode1_components import plans
from build_episode1_animations import Timelines,native_caption_track
ROOT=Path(__file__).resolve().parents[1]
def build(library):
 tl=Timelines(library);result={}
 for art,(items,spec) in plans(ROOT).items():
  if 'controls' in art or art.startswith(('item','result','decision','ep2_','city_decision')):continue
  if art=='ep1_mainstreet_run':spec=dict(spec,script_cycle=True)
  track=native_caption_track(tl,items,spec)
  if track:result[art]=track
 (ROOT/'data/episode1_text_animations.json').write_text(json.dumps(result,separators=(',',':'),ensure_ascii=False)+'\n')
 print(len(result),'native caption timelines')
if __name__=='__main__':
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('library',type=Path);build(p.parse_args().library)
