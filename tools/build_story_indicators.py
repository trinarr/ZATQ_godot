"""Remove remaining Episode I lift indicator and Episode V QTE edge-tint PNGs."""
import hashlib,json
from pathlib import Path
import numpy as np
from PIL import Image
from build_episode1_highlights import contours
from build_episode1_components import shared_texture_references
ROOT=Path(__file__).resolve().parents[1]
LIFT='episode1_animation_parts/part_5284b316d789800144f7.png'
FRAME='episode5_animation_parts/part_5d4e9a3361999c561f30.png'
# Smooth capsule gradient fitted to Symbol 373's original alpha, mean error <.01.
VIGNETTE={'size':[1600,960],'center':[795.527185,485.011216],
          'half_segment':296.471938,'aspect':.997405351,'falloff_width':518.130627,
          'falloff_power':2.3098787,'base_alpha':.0448660112,'amplitude':.908445273,
          'color':[157/255,22/255,20/255]}
def migrate(root=ROOT,episodes=(1,5)):
 removed=set()
 for ep in episodes:
  path=root/f'data/episode{ep}_animations.json'
  if not path.exists():continue
  animations=json.loads(path.read_text())
  for art,spec in animations['art'].items():
   for part in spec['parts'].values():
    filename=part.get('texture')
    if ep==1 and filename==LIFT:
     with Image.open(root/'assets/flash_ui'/filename) as im:pixels=np.asarray(im.convert('RGBA'))
     alpha=pixels[:,:,3];peak=int(alpha.max());visible=pixels[alpha>=peak*.95]
     region={'size':[pixels.shape[1],pixels.shape[0]],'contours':contours(alpha>=peak*.2),
             'color':[round(float(c)/255,6) for c in np.median(visible[:,:3],axis=0)],
             'alpha_min':1.0,'alpha_max':1.0}
     rid='lift_indicator_'+hashlib.sha256(json.dumps(region,sort_keys=True).encode()).hexdigest()[:16]
     region_path=root/'data/episode1_highlights.json';regions=json.loads(region_path.read_text())
     regions['regions'][rid]=region;region_path.write_text(json.dumps(regions,separators=(',',':'))+'\n')
     part.update(type='highlight',region=rid,timeline_alpha=True,opacity=peak/255)
    elif ep==5 and filename==FRAME:
     part.update(type='soft_vignette',vignette=VIGNETTE)
    else:continue
    part.pop('texture');removed.add(filename)
  path.write_text(json.dumps(animations,separators=(',',':'))+'\n')
 live=shared_texture_references(root)
 for filename in removed-live:
  file=root/'assets/flash_ui'/filename;file.unlink();Path(str(file)+'.import').unlink(missing_ok=True)
 print('Dynamic story indicators:',len(removed),'PNG dependencies replaced')
if __name__=='__main__':migrate()
