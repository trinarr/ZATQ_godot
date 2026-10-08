"""The three ECG masks are geometry, never painted monitor overlays."""
import re
from animation_viewport import geometry_bounds

# Source XFL and normalized John SWF use the same three mask/curve layers.
WRAPPERS=(2335,10282)
def pulse_layer(key):
 for symbol in WRAPPERS:
  match=re.search(rf'(:Symbol {symbol}/)(\d+):',key)
  if match:return key[:match.end(1)],int(match[2])
 return None

def mask_part(record,library,photos):
 layer=pulse_layer(record['key'])
 if not layer or layer[1] not in [1,3,5]:return None
 rect=geometry_bounds(record,library,photos)
 if rect is None:raise ValueError('Pulse mask must have source geometry')
 return {'type':'mask','rect':[0,0,0,0],'mask_rect':list(rect),
         'mask_matrix':list(record['matrix']),'source':record['source']}

def link_masks(entry):
 masks={}
 for key,part in entry['parts'].items():
  layer=pulse_layer(key)
  if layer and part.get('type')=='mask':masks[layer]=key
 for key,part in entry['parts'].items():
  layer=pulse_layer(key)
  if layer and layer[1] in [0,2,4]:
   part['mask_key']=masks[(layer[0],layer[1]+1)]
 # John's monitor is an independent 32-frame looping MovieClip. The export
 # horizon happened to trim to 255 frames; it must not become a one-shot scene.
 if any(':Symbol 10282/' in key for key in masks.values()):entry['intro_loop']=32
