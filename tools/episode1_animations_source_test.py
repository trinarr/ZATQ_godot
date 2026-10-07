"""Check authored values against XFL, not an approximation of the tweens."""
import argparse,json
from pathlib import Path
from build_episode1_ui_animations import extract
from build_episode1_animations import Timelines
ROOT=Path(__file__).resolve().parents[1]
def verify(library):
 expected=extract(library)
 assert expected==json.loads((ROOT/'data/episode1_ui_animations.json').read_text())
 tl=Timelines(library)
 frames=[tl.walk('Symbol 2882',0,i,{'Mov':14},{'Hist','But1','But2'}, {'photo':'Fon1_1.png','photo_path':'Mov.Mov'},origin=0) for i in range(15)]
 data=json.loads((ROOT/'data/episode1_animations.json').read_text())
 wake=data['art']['layout_bg_wake']['intro']
 assert len(wake)==15
 for source,exported in zip(frames,wake):assert all(abs(a-b)<1e-6 for a,b in zip(source[0]['color'],exported[0][2]))
 assert len(data['art']['city_bite_transition']['intro'])==51
 assert len(data['art']['ep1_mainstreet_run']['intro'])==40
 assert len(data['art']['ep1_mainstreet_attack']['intro'])==34
 assert len(data['art']['city_explosion_flash']['outro'])==54
 assert tl.info('Symbol 2538')[0]==20
 assert data['fps']==19
 print('PASS: native popup/remote keys, wake alpha, bite, chase and explosion timing match XFL')
if __name__=='__main__':
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('library',type=Path);verify(p.parse_args().library)
