"""Replace John's moving caption masks with native character reveal."""
def apply(catalog,texts=None):
 for art in ['john2_1','john2_9']:
  spec=catalog['art'][art]
  spec.pop('caption_mask',None)
  spec['typewriter']=True
  masks={key:part for key,part in spec['parts'].items() if part.get('source')=='Mov/Symbol 10183'}
  if not masks:continue
  for phase in ['intro','outro']:
   for row in spec[phase]:
    row[:]=[r for r in row if r[0] not in masks]
  for key in masks:del spec['parts'][key]

 # Frame 3 changes immediately to AddItem in Episode2.MovClickFunc. The
 # independent 19-frame red pulse is not an outro and must never delay input.
 scene=catalog['art']['john2_3']
 scene['outro']=[scene['intro'][-1]]
 scene['outro_hold']=True
 if texts is not None:texts['john2_3']['outro']=[texts['john2_3']['intro'][-1]]
