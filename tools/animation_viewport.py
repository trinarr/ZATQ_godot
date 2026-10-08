"""Keep pixels that enter the Flash stage later in an animated display list.

The raster's rect stays in the reference pose's coordinates; playback matrices
remain unchanged. Only the stage clips a panorama, never its exported texture.
"""
import math
import re
from PIL import Image
from render_flash_ui import NS, path_data
from build_localized_ui import combine

STAGE = (0, 0, 800, 480)

def inverse(m):
 a,b,c,d,x,y=m;det=a*d-b*c
 if abs(det)<1e-9:return None
 return d/det,-b/det,-c/det,a/det,(c*y-d*x)/det,(b*x-a*y)/det

def transformed_bounds(bounds,m):
 x,y,w,h=bounds;a,b,c,d,tx,ty=m
 points=[(a*X+c*Y+tx,b*X+d*Y+ty) for X,Y in [(x,y),(x+w,y),(x,y+h),(x+w,y+h)]]
 xs,ys=zip(*points)
 return min(xs),min(ys),max(xs)-min(xs),max(ys)-min(ys)

def geometry_bounds(record,library,photos):
 e=record.get('element')
 if 'photo' in record or (e is not None and e.tag.endswith('DOMBitmapInstance')):
  file=photos/record['photo'] if 'photo' in record else library/e.get('libraryItemName')
  with Image.open(file) as im:return 0,0,*im.size
 if e is None:return None
 # Quadratic control points bound the curve conservatively. Alpha trimming
 # removes any excess transparent margin after the complete shape is rendered.
 edges=e.findall('.//x:Edge',NS)
 points=[]
 for edge in edges:
  values=[float(v) for v in re.findall(r'-?\d+(?:\.\d+)?',path_data(edge.get('edges','')))]
  points.extend(zip(values[::2],values[1::2]))
 if not points:return None
 xs,ys=zip(*points)
 return min(xs),min(ys),max(xs)-min(xs),max(ys)-min(ys)

def animation_viewport(reference,records,library,photos):
 bounds=geometry_bounds(reference,library,photos)
 inv_ref=inverse(reference['matrix'])
 if bounds is None or inv_ref is None:return STAGE
 x,y,w,h=transformed_bounds(bounds,reference['matrix'])
 left,top,right,bottom=0,0,800,480
 for pose in records:
  if pose['color'][3]<=0:continue
  inv_delta=inverse(combine(pose['matrix'],inv_ref))
  if inv_delta is None:continue
  sx,sy,sw,sh=transformed_bounds(STAGE,inv_delta)
  l,t,r,b=max(x,sx),max(y,sy),min(x+w,sx+sw),min(y+h,sy+sh)
  if r<=l or b<=t:continue
  left=min(left,math.floor(l+1e-6));top=min(top,math.floor(t+1e-6))
  right=max(right,math.ceil(r-1e-6));bottom=max(bottom,math.ceil(b-1e-6))
 return left,top,right-left,bottom-top
