"""Check exported Episode IV transforms/colors against original XFL timelines.
Usage: python tools/episode4_source_test.py ORIGINAL_LIBRARY_DIRECTORY
"""
import argparse,json
from pathlib import Path
from build_episode23_animations import EpisodeTimelines,selected_plans,sequences
from build_localized_ui import combine
ROOT=Path(__file__).resolve().parents[1]
def verify(library):
    actual=json.loads((ROOT/'data/episode4_animations.json').read_text())['art']
    tl=EpisodeTimelines(library);checks=0
    for art,(items,spec) in selected_plans(4).items():
        if art not in actual:continue
        entry=actual[art];states,_=sequences(tl,items,spec)
        pool={}
        for frames in states.values():
            for row in frames:
                for record in row:pool.setdefault(record['key'],[]).append(record)
        refs={}
        for key in entry['parts']:
            assert key in pool,(art,key)
            ref=max(pool[key],key=lambda r:-abs(r['matrix'][4])-abs(r['matrix'][5])-800*abs(r['matrix'][0]-1)-480*abs(r['matrix'][3]-1))
            refs[key]=ref['matrix'];checks+=1
        for phase in ['intro','outro']:
            if phase=='outro' and entry['outro_hold']:
                assert entry[phase]==[entry['intro'][-1]],art;checks+=1;continue
            for index,frame in enumerate(entry[phase]):
                source=states[phase][index];expected=[]
                for rec in source:
                    key=rec['key']
                    if key not in refs:continue
                    a,b,c,d,x,y=refs[key];det=a*d-b*c
                    if abs(det)<1e-9:continue
                    inverse=(d/det,-b/det,-c/det,a/det,(c*y-d*x)/det,(b*x-a*y)/det)
                    expected.append([key,[round(v,6) for v in combine(rec['matrix'],inverse)],[round(v,6) for v in rec['color']]])
                assert frame==expected,(art,phase,index);checks+=1
        for part in entry['parts'].values():
            assert 'Symbol 539' not in part.get('source',''),art
            if 'texture' in part:assert (ROOT/'assets/flash_ui'/part['texture']).is_file(),part
    assert len(actual)==93
    print(f'PASS: {checks} original XFL layer/frame checks across {len(actual)} animated scenes.')
if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('library',type=Path)
    verify(parser.parse_args().library)
