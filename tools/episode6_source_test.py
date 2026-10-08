"""Check exported Episode VI transforms/colors against original XFL timelines.
Usage: python tools/episode4_source_test.py ORIGINAL_LIBRARY_DIRECTORY
"""
import argparse,json,csv,re,zipfile
from pathlib import Path
from build_episode23_animations import EpisodeTimelines,selected_plans,sequences
from build_localized_ui import combine
ROOT=Path(__file__).resolve().parents[1]
def verify(library):
    actual=json.loads((ROOT/'data/episode6_animations.json').read_text())['art']
    tl=EpisodeTimelines(library);checks=0
    for art,(items,spec) in selected_plans(6).items():
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
    static=json.loads((ROOT/"data/episode6_components.json").read_text())
    assert set(actual)<=set(selected_plans(6))
    assert set(selected_plans(6))<=set(actual)|set(static)
    opening=actual["e6_wake_1_v1"]
    assert opening.get("eye_blur",{}).get("closing")==False
    assert {p.get("eye_lid") for p in opening["parts"].values() if p.get("eye_lid")}=={"upper","lower"}
    assert any(p.get("blur",{}).get("source_bitmap")=="Bitmap 328.png" for p in opening["parts"].values())
    print(f'PASS: {checks} original XFL layer/frame checks across {len(actual)} animated scenes.')
def verify_routes(archive):
    from story_graph_format import compile_graph
    from build_episode4_content import source_array
    from build_episode6_content import CLASSES
    from build_episode1_art import BackgroundRenderer
    from build_episode2_content import text_blocks
    import tempfile
    with zipfile.ZipFile(archive) as z:
        sources={Path(n).stem:z.read(n).decode('utf-8-sig') for n in z.namelist() if n.endswith('.as')}
    graph=json.loads((ROOT/'data/story_graphs/episode6.json').read_text());nodes=compile_graph(graph)
    with (ROOT/'locales/episode6.csv').open(newline='') as f:locale={r['key']:r['ru'] for r in csv.DictReader(f)}
    def text(value):return locale[value.removeprefix('@loc:')] if value.startswith('@loc:') else value
    results=source_array(sources['ResultBad'],'ResultArr')
    for node in nodes.values():
        if node.get('result_id'):assert text(node['text'])==results[node['result_id']-1]
    terminal_count=0
    for n,key in [(6,'hernandez'),(7,'pete'),(8,'dave')]:
        fn=sources['DialogMov'].split(f'public function PersonSwitcher{n+1}(')[1].split('public function ')[0]
        for match in re.finditer(r'((?:\s*case \d+:)+)(.*?)break;',fn,re.S):
            dest=re.search(r'new (AfterDialog|WithoutLeg|TwoDaysPrison)\((\d*)\)',match[2])
            if not dest:continue
            cls={'AfterDialog':'after','WithoutLeg':'noleg','TwoDaysPrison':'prison'}[dest[1]];variant=int(dest[2] or 1)
            frame=variant//2+1 if cls=='after' else variant
            expected=f'e6_{cls}_{frame}_v{variant if cls!="noleg" else 1}'
            for index in re.findall(r'case (\d+):',match[1]):
                previous=(int(index)-1)//3;answer=(int(index)-1)%3
                id=f'e6_dialogue_{key}_{previous}'
                if id not in nodes:continue
                assert nodes[id]['choices'][answer]['next']==expected,(id,answer,expected)
                terminal_count+=1
    # Compare every narrative block to its actual XFL text variant, including
    # the three blood-on-floor outcomes and laboratory/prison branch overrides.
    visuals=json.loads((ROOT/'data/episode6_visuals.json').read_text())
    with tempfile.TemporaryDirectory() as td:
        lib=Path(td)/'LIBRARY';lib.mkdir()
        with zipfile.ZipFile(archive) as z:
            for n in z.namelist():
                if '/ZombieApocalypse/LIBRARY/' in n and n.endswith('.xml'):(lib/Path(n).name).write_bytes(z.read(n))
        renderer=BackgroundRenderer(lib,ROOT/'assets/flash_ui',ROOT/'fonts/flash');captions=0
        for id,node in nodes.items():
            if not node.get('blocks'):continue
            visual=visuals[node['art']]
            original=text_blocks(renderer,f"Symbol {visual['symbol']}",visual['frame'],visual['overrides'])
            assert [text(b['text']) for b in node['blocks']]==[b['text'] for b in original],id
            captions+=len(original)
    assert {n['result_id'] for n in nodes.values() if n.get('alive')}=={151,160}
    assert 'e6_result_150' not in nodes # the weapons quiz, not Episode VI.
    print(f'PASS: {terminal_count} original dialogue exits, {captions} native caption blocks, all 24 result texts.')
if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('library',type=Path);parser.add_argument('--archive',type=Path)
    args=parser.parse_args();verify(args.library)
    if args.archive:verify_routes(args.archive)
