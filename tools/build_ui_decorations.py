"""Convert baked UI fills to cached vector contours and Episode III vignettes.
Run after Flash component exporters. Existing definitions permit idempotent builds.
Only explicitly reviewed flat-color decorations are converted, never story art.
"""
import json
from pathlib import Path
import numpy as np
from PIL import Image, ImageFilter
from scipy.optimize import least_squares
from build_episode1_highlights import contours
ROOT=Path(__file__).resolve().parents[1]
TARGETS={
 'episode1_components/part_bc68d77e23a7b55342b7.png':'item_strip',
 'episode1_components/part_58afdc3ae06eddc4790a.png':'result_strip',
 'episode1_components/part_07125d3025f470f6cb73.png':'episode1_answer_a',
 'episode1_components/part_ef6ae3bebd92a017e476.png':'episode1_answer_b',
 'episode101_components/part_f8612bc050a0a146a7ab.png':'john_square',
 'pause_components/part_ae41a76d6f9aa5e5c3b6.png':'pause_shadow_1',
 'pause_components/part_5420528eaf3d74395afd.png':'pause_shadow_2',
 'pause_components/part_78e4100c7aeb0be79791.png':'pause_shadow_3',
 'pause_components/part_6daf34daef9d816ca445.png':'pause_shadow_4',
 'components/part_6d93d9bc30dd57564bda.png':'menu_backplates',
}
VIGNETTES={
 'episode3_components/part_88a3eabde5695b3229a6.png':'e3_opening_8',
 'episode3_components/part_1455429bcb1a3a0fcb97.png':'e3_kill_6',
}
def objects(value):
 if isinstance(value,dict):
  yield value
  for child in value.values():yield from objects(child)
 elif isinstance(value,list):
  for child in value:yield from objects(child)

def vector(image):
 a=np.asarray(image.convert('RGBA'));alpha=a[:,:,3]
 color=np.median(a[alpha>max(1,alpha.max()*.8),:3],axis=0)/255
 # Nested contours retain the original feathered edges, including the four
 # differently shaped pause shadows. Rasterized once, no per-frame blur.
 layers=[];previous=0.;levels=16
 alpha=np.asarray(Image.fromarray(alpha).filter(ImageFilter.GaussianBlur(1.5)).resize((max(1,image.width//3),max(1,image.height//3)),Image.Resampling.LANCZOS))
 sx=image.width/alpha.shape[1];sy=image.height/alpha.shape[0]
 for n in range(1,levels+1):
  threshold=(n-.5)/levels
  rings=contours(alpha/255>=threshold)
  rings=[[round(v*(sx if i%2==0 else sy),1) for i,v in enumerate(ring)] for ring in rings]
  if not rings:break
  target=n/levels
  layers.append({'opacity':round((target-previous)/(1-previous),6),'contours':rings})
  previous=target
 return {'size':list(image.size),'color':[round(float(c),6) for c in color],'layers':layers}

def vignette(image):
 a=np.asarray(image.convert('RGBA'));h,w=a.shape[:2]
 yy,xx=np.mgrid[0:h:8,0:w:8];target=a[::8,::8,3]/255
 def model(p,x=xx,y=yy):
  cx,cy,segment,aspect,width,power,base,amplitude=p
  d=np.hypot(np.maximum(np.abs(x-cx)-segment,0)/aspect,np.abs(y-cy))/width
  return base+amplitude*(1-np.exp(-d**power))
 fit=least_squares(lambda p:(model(p)-target).ravel(),[w/2,h/2,150,1,450,3,0,1],
  bounds=([0,0,0,.2,30,.3,0,0],[w,h,w/2,5,2000,10,.5,1.5]),max_nfev=300)
 error=float(np.mean(abs(model(fit.x)-target)))
 assert error<.03,(image.filename,error)
 p=fit.x;color=np.median(a[a[:,:,3]>128,:3],axis=0)/255
 print('vignette alpha MAE',image.filename,error)
 return dict(size=[w,h],center=list(p[:2]),half_segment=p[2],aspect=p[3],falloff_width=p[4],falloff_power=p[5],base_alpha=p[6],amplitude=p[7],color=[float(c) for c in color])

def migrate(root=ROOT):
 output=root/'data/ui_decorations.json'
 seed=output if output.exists() else ROOT/'data/ui_decorations.json'
 data=json.loads(seed.read_text()) if seed.exists() else {}
 replacements={}
 for texture,key in TARGETS.items():
  image=root/'assets/flash_ui'/texture
  if not image.exists():image=next((root/'assets/flash_ui').rglob(Path(texture).name),image)
  if image.exists():data[key]=vector(Image.open(image))
  assert key in data,key
  replacements[texture]={'type':'decoration','decoration':key}
 for texture,key in VIGNETTES.items():
  image=root/'assets/flash_ui'/texture
  if not image.exists():image=next((root/'assets/flash_ui').rglob(Path(texture).name),image)
  if image.exists():data[key]=vignette(Image.open(image))
  assert key in data,key
  replacements[texture]={'type':'soft_vignette','vignette':data[key]}
 # Episode VI still referenced the already retired Episode V red vignette.
 old='episode5_animation_parts/part_5d4e9a3361999c561f30.png'
 source5=root/'data/episode5_animations.json'
 if not source5.exists():source5=ROOT/'data/episode5_animations.json'
 episode5=json.loads(source5.read_text())
 shared=next(p['vignette'] for art in episode5['art'].values() for p in art['parts'].values() if p.get('source')=='Mov/Symbol 373' and p.get('type')=='soft_vignette')
 replacements[old]={'type':'soft_vignette','vignette':shared}
 output.write_text(json.dumps(data,separators=(',',':'))+'\n')
 for path in (root/'data').glob('*.json'):
  if not (path.name.endswith('_components.json') or path.name.endswith('_animations.json')):continue
  document=json.loads(path.read_text());changed=False
  for part in objects(document):
   texture=part.get('texture','')
   matched=next((key for key in replacements if Path(key).name==Path(texture).name),None) if texture else None
   if matched:
    part.pop('texture');part.update(replacements[matched]);changed=True
  if changed:
   original=path.read_text()
   compact='\n' not in original.rstrip('\n')
   path.write_text(json.dumps(document,ensure_ascii=False,separators=(',',':'))+'\n' if compact else json.dumps(document,ensure_ascii=False,indent=2)+'\n')
 for texture in replacements:
  for image in (root/'assets/flash_ui').rglob(Path(texture).name):
   image.unlink();Path(str(image)+'.import').unlink(missing_ok=True)
 return replacements
if __name__=='__main__':migrate()
