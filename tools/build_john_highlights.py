"""Replace John's interactive red bitmaps with cached vector glow contours.
Called after merging the two web timelines; rebuilds are safe and idempotent.
"""
import hashlib,json
from pathlib import Path
import numpy as np
from PIL import Image
from build_episode1_highlights import contours
from build_episode1_components import shared_texture_references
ROOT=Path(__file__).resolve().parents[1]
def migrate(root=ROOT):
 animation_path=root/'data/episode101_animations.json'
 tracks=json.loads(animation_path.read_text())
 region_path=root/'data/episode101_highlights.json'
 regions=json.loads(region_path.read_text())
 replacements={}
 for art,spec in tracks['art'].items():
  if any(tag in art for tag in ['item','dialogue','selector']):continue
  for key,part in spec['parts'].items():
   if part.get('type')!='texture':continue
   filename=part['texture']
   with Image.open(root/'assets/flash_ui'/filename) as image:pixels=np.asarray(image.convert('RGBA'))
   visible=pixels[pixels[:,:,3]>5].astype(float)
   if not len(visible):continue
   red=(visible[:,0]>visible[:,1]*1.7)&(visible[:,0]>visible[:,2]*1.7)&(visible[:,0]>70)
   if np.mean(red)<.95:continue
   peak=float(visible[:,3].max())
   colors=[record[2] for phase in ['intro','outro'] for row in spec[phase] for record in row if record[0]==key]
   assert all(c[:3]==[1.,1.,1.] and c[4:]==[0.,0.,0.] for c in colors),(art,key,'unexpected color transform')
   rgb=np.median(visible[red & (visible[:,3]>=peak*.95),:3],axis=0)
   region={'size':[pixels.shape[1],pixels.shape[0]],'contours':contours(pixels[:,:,3]>=peak*.2),
           'color':[round(float(c)/255,6) for c in rgb],
           'alpha_min':min(c[3] for c in colors)*peak/255,
           'alpha_max':max(c[3] for c in colors)*peak/255}
   assert region['contours'],filename
   id='john_region_'+hashlib.sha256(json.dumps(region,sort_keys=True).encode()).hexdigest()[:16]
   regions['regions'][id]=region
   replacements[filename]=id
   part.update(type='highlight',region=id,timeline_alpha=True);part.pop('texture')
 # The static exporter may retain a final-pose copy of the same primitive.
 component_path=root/'data/episode101_components.json'
 components=json.loads(component_path.read_text())
 for parts in components.values():
  for part in parts:
   filename=part.get('texture')
   if filename not in replacements:continue
   part.update(type='highlight',region=replacements[filename]);part.pop('texture')
 animation_path.write_text(json.dumps(tracks,separators=(',',':'),ensure_ascii=False)+'\n')
 component_path.write_text(json.dumps(components,ensure_ascii=False,indent=2)+'\n')
 region_path.write_text(json.dumps(regions,separators=(',',':'))+'\n')
 live=shared_texture_references(root)
 removed=[]
 for filename in replacements.keys()-live:
  file=root/'assets/flash_ui'/filename
  file.unlink(missing_ok=True);Path(str(file)+'.import').unlink(missing_ok=True);removed.append(filename)
 print('John dynamic highlights:',len(replacements),'bitmaps converted;',len(removed),'unused PNGs removed')
 return replacements
if __name__=='__main__':migrate()
