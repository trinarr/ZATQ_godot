"""Validate converted references and enumerate all opening branches."""
import json
from pathlib import Path
root=Path(__file__).resolve().parents[1]
content=json.loads((root/'data/opening.json').read_text())
nodes=content['nodes']
nodes.update(json.loads((root/'data/city_routes.json').read_text())['nodes'])
for key,node in nodes.items():
    assert node.get('source'),key
    assert (root/'assets/images'/node['image']).is_file(),key
    for choice in node.get('choices',[]):
        for target in ('next','with_keys','by_car'):
            if target in choice: assert choice[target] in nodes,(key,choice[target])
    for key in ('art','art_on_foot'):
        if key in node: assert (root/'assets/flash_ui'/(node[key]+'.png')).is_file(),(node,key)
    for choice in node.get('choices',[]):
        if 'sound' in choice: assert (root/'assets/audio'/(choice['sound']+'.mp3')).is_file()
    if 'back' in node: assert node['back'] in nodes
    if 'sound' in node: assert (root/'assets/audio'/(node['sound']+'.mp3')).is_file()
assert 'transport_choice' == nodes['transport']['choices'][0]['with_keys']
assert nodes['transport_choice']['choices'][0]['set']['Auto']==1
assert nodes['keys']['set']['TakenKey'] is True
assert nodes['lift_button']['choices'][0]['by_car']=='city_car'
catalog=json.loads((root/'data/flash_catalog.json').read_text())
assert len(catalog['symbols'])==1543
assert len(catalog['actionscript'])==514
assert 'Поехать на машине' in catalog['actionscript']['NewItem.as']
assert 'Дойти пешком' in catalog['actionscript']['NewItem.as']
print('PASS: assets, sound references, extended city routes, provenance; 1543 symbols / 514 AS files.')
