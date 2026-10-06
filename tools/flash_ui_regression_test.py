"""Check shader brush coverage and confirm texture brushes were removed."""
import json
from pathlib import Path
from PIL import Image
ROOT=Path(__file__).resolve().parents[1]
ART=ROOT/'assets/flash_ui'
layout=json.loads((ROOT/'data/ui_brush_layout.json').read_text())
components=json.loads((ROOT/'data/ui_components.json').read_text())
for name in ['adaptive_menu','adaptive_menu_off']:
 assert len(layout[name])==6,name
 assert all(b['color'][0]>b['color'][1]*1.4 for b in layout[name]),name
 assert components[name],name
 assert not (ART/(name+'.png')).exists(),name
for i in range(12):
 assert len(layout[f'adaptive_selector_{i}'])==2,('selector',i)
 assert components[f'adaptive_selector_{i}']
 assert not (ART/f'adaptive_selector_{i}.png').exists(),i
assert 'layout_pause' not in layout
pause=json.loads((ROOT/'data/pause_components.json').read_text())
assert len(pause)==8 and all(pause.values())
for name in ['decision','city_decision_3','ep2_decision_4']:assert name not in layout
answers=json.loads((ROOT/'data/dialog_components.json').read_text())
assert answers['decision_plate'][0]['rect']==[0,0,347,64]
assert answers['decision_disabled_mark'][0]['rect']==[154,15,29,29]
assert len(layout['e3_dialogue_john'])==3
for name in ['item_keys','ep2_item_glock','ep2_item_mark23','e3_item_knife','e3_item_glock16','e3_item_glock7','ep2_continue_button']:assert layout[name],name
assert not (ART/'brush.png').exists() and not (ART/'choice.png').exists()
print('PASS: all brush button layouts; raster fills removed; icons/panels retained')
