"""Keep John's rectangular Flash masks as clipping tracks, never visible art."""
def apply(catalog,texts=None):
 for art in ['john2_1','john2_9']:
  spec=catalog['art'][art]
  masks={key:part for key,part in spec['parts'].items() if part.get('source')=='Mov/Symbol 10183'}
  if not masks:continue
  track={}
  for phase in ['intro','outro']:
   areas=[]
   for row in spec[phase]:
    mask=next((r for r in row if r[0] in masks),None)
    if mask:
     x,y,w,h=masks[mask[0]]['rect'];a,b,c,d,tx,ty=mask[1]
     assert b==0 and c==0,'John caption mask is axis aligned'
     areas.append([a*x+tx,d*y+ty,a*w,d*h])
    else:areas.append([0,0,0,0])
    row[:]=[r for r in row if r[0] not in masks]
   track[phase]=areas
  spec['caption_mask']=track
  for key in masks:del spec['parts'][key]

 # Frame 3 changes immediately to AddItem in Episode2.MovClickFunc. The
 # independent 19-frame red pulse is not an outro and must never delay input.
 scene=catalog['art']['john2_3']
 scene['outro']=[scene['intro'][-1]]
 scene['outro_hold']=True
 if texts is not None:texts['john2_3']['outro']=[texts['john2_3']['intro'][-1]]
