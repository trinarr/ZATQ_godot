"""Validate converted references and enumerate all opening branches."""
import json
from pathlib import Path
root=Path(__file__).resolve().parents[1]
from story_graph_format import load_all
nodes=load_all(root)
components={}
regions=set()
for path in (root/'data').glob('episode*_components.json'):components.update(json.loads(path.read_text()))
for path in (root/'data').glob('episode*_animations.json'):
    if path.name.endswith(('_text_animations.json','_ui_animations.json')):continue
    components.update(json.loads(path.read_text()).get('art',{}))
for path in (root/'data').glob('episode*_highlights.json'):
    highlights=json.loads(path.read_text());regions.update(highlights['regions']);regions.update(highlights.get('masks',{}))
assert all(n.get('kind','story') != 'boundary' for n in nodes.values())
assert sum(n.get('kind','story') == 'city_ending' for n in nodes.values()) == 13
for key,node in nodes.items():
    assert node.get('source'),key
    if 'image' in node: assert (root/'assets/images'/node['image']).is_file(),key
    for choice in node.get('choices',[]):
        if 'mask' in choice and choice['mask'] not in regions: assert (root/'assets/flash_ui'/(choice['mask']+'.png')).is_file()
        for case in choice.get('next_cases',[]): assert case['next'] in nodes,(key,case['next'])
        for target in ('next','with_keys','by_car'):
            if target in choice: assert choice[target] in nodes,(key,choice[target])
    for key in ('art','art_on_foot','controls_art'):
        if key in node and node[key] not in components: assert (root/'assets/flash_ui'/(node[key]+'.'+(node.get('art_extension','png') if key in ['art','art_on_foot'] else 'png'))).is_file(),(node,key)
    for choice in node.get('choices',[]):
        if 'sound' in choice: assert (root/'assets/audio'/(choice['sound']+'.mp3')).is_file()
    if 'back' in node: assert node['back'] in nodes
    if node.get('sound'): assert (root/'assets/audio'/(node['sound']+'.mp3')).is_file()
    if 'pickup_if' in node: assert node['pickup_if']['next'] in nodes
    for variant in node.get('variants',[]):
        if variant.get('sound'): assert (root/'assets/audio'/(variant['sound']+'.mp3')).is_file()
assert 'transport_choice' == nodes['transport']['choices'][0]['with_keys']
assert nodes['transport_choice']['choices'][0]['set']['Auto']==1
assert nodes['keys']['set']['TakenKey'] is True
assert nodes['lift_button']['choices'][0]['by_car']=='city_car'
catalog=json.loads((root/'data/flash_catalog.json').read_text())
assert len(catalog['symbols'])==1543
assert len(catalog['actionscript'])==514
assert 'Поехать на машине' in catalog['actionscript']['NewItem.as']
assert 'Дойти пешком' in catalog['actionscript']['NewItem.as']
assert {int(n['result_id']) for n in nodes.values() if n.get('episode')==2 and n.get('alive')} == {38,43,47}
assert len([n for n in nodes.values() if n.get('episode')==2 and n.get('kind')=='city_death'])==14
assert {int(n['result_id']) for n in nodes.values() if n.get('episode')==3 and n.get('alive')} == {64,67,68,73}
assert len({int(n.get('ending_id',n['result_id'])) for n in nodes.values() if n.get('episode')==3 and n.get('alive')})==3
assert {int(n['result_id']) for n in nodes.values() if n.get('episode')==4 and n.get('alive')} == {96,98,112}
assert len([n for n in nodes.values() if n.get('episode')==4 and n.get('kind')=='city_death'])==31
print('PASS: assets, sounds, complete Episodes I–IV routes, original XFL/AS provenance.')
