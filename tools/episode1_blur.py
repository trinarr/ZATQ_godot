"""Sharp bitmap replacements and source-pixel sigma for authored Episode I blur."""
import copy
from render_flash_ui import NS
BLUR_BITMAPS = {
 'Bitmap 2454.png': ('Bitmap 2460.png',10.1,.6,0.),
 'Bitmap 2457.png': ('Bitmap 2460.png',5.1,.2,0.),
 'Bitmap 2462.png': ('Bitmap 2468.png',9.8,.4,0.),
 'Bitmap 2465.png': ('Bitmap 2468.png',5.,.1,0.),
 'Bitmap 2516.png': ('Bitmap 2522.png',6.2,.35,0.),
 'Bitmap 2542.png': ('Bitmap 2539.png',2.5,2.5,0.),
 'Bitmap 2686.png': ('Bitmap 2694.png',6.1,.1,-.961),
 'Bitmap 2691.png': ('Bitmap 2694.png',4.3,.1,-.946),
}
def sharp_element(element):
 result=copy.deepcopy(element)
 for fill in result.findall('.//x:BitmapFill',NS):
  if fill.get('bitmapPath') in BLUR_BITMAPS:fill.set('bitmapPath',BLUR_BITMAPS[fill.get('bitmapPath')][0])
 return result

def blur_spec(element):
 for fill in element.findall('.//x:BitmapFill',NS):
  name=fill.get('bitmapPath')
  if name in BLUR_BITMAPS:
   sharp,sx,sy,angle=BLUR_BITMAPS[name]
   return {'sigma':[sx,sy],'angle':angle,'source_bitmap':sharp,'replaces_bitmap':name}
 return None
