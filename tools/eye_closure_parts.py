"""Shared native eyelids and blur metadata for the original Flash eye clips."""
from PIL import Image
SHARED_TEXTURE='shared_components/eye_lid.png'
def eye_part(source,transform):
 side='upper' if source.endswith(('/Symbol 327','/Symbol 10373')) else 'lower' if source.endswith(('/Symbol 325','/Symbol 10371')) else None
 if side is None:return None
 a,b,c,d,x,y=transform
 if (a,b,c,d)!=(1,0,0,1):raise ValueError('Eyelid needs translation-only source matrix')
 return {'type':'texture','texture':SHARED_TEXTURE,'rect':[x-1,y-260.95 if side=='upper' else y,802,433],'source':source,'eye_lid':side}
def export_texture(library,root):
 dest=root/'assets/flash_ui'/SHARED_TEXTURE;dest.parent.mkdir(parents=True,exist_ok=True)
 bitmap='Bitmap 323.png' if (library/'Bitmap 323.png').exists() else 'Bitmap 10369.png'
 with Image.open(library/bitmap) as source:
  im=source.convert('RGBA')
  # One opaque row beyond the source bounds covers the 0.05 px Flash offset
  # at the fully closed pose; keep the soft edge pixels unchanged.
  padded=Image.new('RGBA',(802,433));padded.paste(im,(1,1))
  padded.paste(im.crop((0,0,800,1)),(1,0))
  padded.paste(padded.crop((1,0,2,433)),(0,0))
  padded.paste(padded.crop((800,0,801,433)),(801,0))
  padded.save(dest,compress_level=6)
def annotate(spec):
 if not any('eye_lid' in p for p in spec['parts'].values()):return
 rows=spec['intro']
 for key,part in spec['parts'].items():
  if 'blur' not in part:continue
  active=[i for i,row in enumerate(rows) if any(r[0]==key for r in row)]
  lids=[i for i,row in enumerate(rows) if any('eye_lid' in spec['parts'][r[0]] for r in row)]
  if not active or not lids:continue
  spec['eye_blur']={'frames':[min(lids),max(lids)],'closing':part['blur']['replaces_bitmap']=='Bitmap 2542.png'}
  for other in spec['parts'].values():
   if other.get('texture')==part['texture'] and other.get('rect')==part['rect']:other['blur']=dict(part['blur'])
  # Both background slots sample the same cache so their authored replacement
  # cannot interrupt the blend while the lids are still opening.
