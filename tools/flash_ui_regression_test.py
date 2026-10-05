"""Check shader brush coverage and confirm texture brushes were removed."""
import json
from pathlib import Path
from PIL import Image
ROOT=Path(__file__).resolve().parents[1]
ART=ROOT/'assets/flash_ui'
layout=json.loads((ROOT/'data/ui_brush_layout.json').read_text())
for name in ['adaptive_menu','adaptive_menu_off']:
 assert len(layout[name])==6,name
 assert all(b['color'][0]>b['color'][1]*1.4 for b in layout[name]),name
 with Image.open(ART/(name+'.png')) as image:
  for y in [51,110,168,226]:
   r,g,b,a=image.convert('RGBA').getpixel((500,y*2+25));assert r<=g*1.3+5,(name,y)
for i in range(12):
 assert len(layout[f'adaptive_selector_{i}'])==2,('selector',i)
 with Image.open(ART/f'adaptive_selector_{i}.png') as image:assert max(image.convert('RGBA').getpixel((830,760))[:3])<5,i
assert len(layout['layout_pause'])==4
assert len(layout['decision'])==2 and len(layout['city_decision_3'])==3
assert len(layout['ep2_decision_4'])==4
assert len(layout['e3_dialogue_john'])==3
for name in ['item_keys','ep2_item_glock','ep2_item_mark23','e3_item_knife','e3_item_glock16','e3_item_glock7','ep2_continue_button']:assert layout[name],name
assert not (ART/'brush.png').exists() and not (ART/'choice.png').exists()
print('PASS: all brush button layouts; raster fills removed; icons/panels retained')
