"""Check the actual exported pixels of the Flash UI, not just clickable regions."""
from pathlib import Path
from PIL import Image
ART=Path(__file__).resolve().parents[1]/'assets/flash_ui'
def red_pixels(image,box):
 return sum(a>100 and r>g*1.4 and r>b*1.3 for r,g,b,a in image.crop(box).get_flattened_data())
def visible_pixels(image,box):
 return sum(a>100 for r,g,b,a in image.crop(box).get_flattened_data())
for name in ['adaptive_menu','adaptive_menu_off']:
 with Image.open(ART/(name+'.png')) as im:
  im=im.convert('RGBA')
  for y in [51,110,168,226]:assert red_pixels(im,(308,y*2,688,(y+43)*2))>10000,(name,y)
  for x in [441,511]:assert red_pixels(im,(x*2,398,(x+60)*2,518))>2000,(name,x)
for i in range(12):
 with Image.open(ART/f'adaptive_selector_{i}.png') as im:
  assert visible_pixels(im.convert('RGBA'),(620,702,1030,798))>10000,('selector',i)
with Image.open(ART/'adaptive_help.png') as im:
 assert visible_pixels(im.convert('RGBA'),(126,746,770,878))>10000,'help button'
print('PASS: menu red buttons, sound/achievements, all selector Start brushes and help button')
