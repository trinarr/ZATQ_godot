"""Export authored Episode I MovieClip display lists at the document's 19 fps.
Usage: python tools/build_episode1_animations.py ORIGINAL.zip
No ActionScript is executed. MovieClip stop keys and named semantic frame
variants select playback segments. Text, controls and red masks stay native.
"""
import argparse,base64,copy,json,math,subprocess,tempfile,zipfile
from pathlib import Path
import xml.etree.ElementTree as ET
from PIL import Image
from build_episode1_components import Exporter,plans
from episode1_blur import blur_spec
from build_localized_ui import matrix,combine
from render_flash_ui import NS
ROOT=Path(__file__).resolve().parents[1]
IDENTITY=(1,0,0,1,0,0)

class Timelines:
 def __init__(self,library):self.library=library;self.cache={};self.audit={};self.period=1
 def root(self,name):
  if name not in self.cache:self.cache[name]=ET.parse(self.library/(name+'.xml')).getroot()
  return self.cache[name]
 def info(self,name):
  r=self.root(name);fs=r.findall('.//x:DOMFrame',NS)
  length=max([int(f.get('index',0))+int(f.get('duration',1)) for f in fs] or [1])
  stops=sorted({int(f.get('index',0)) for f in fs if any('stop();' in (s.text or '') for s in f.findall('x:Actionscript/x:script',NS))})
  return length,stops
 def segment(self,name,target=None,outro=False):
  length,stops=self.info(name)
  if target is not None:
   start=max([s+1 for s in stops if s<target] or [0]);end=target
   if target==0:start=end=0
  else:start=0;end=stops[0] if stops else length-1
  if outro:
   start=end+1
   end=next((s for s in stops if s>=start),length-1)
   start=min(start,end)
  return start,end,not stops
 def walk(self,name,frame,tick,ov,hide,spec,path='',t=IDENTITY,color=(1,1,1,1,0,0,0),key='',depth=0,outro=False,origin=None,text_only=False):
  if depth>35 or name=='Symbol 88':return []
  root=self.root(name);records=[]
  if origin is None:origin=frame
  active_scripts=[v.text or '' for f in root.findall('.//x:DOMFrame',NS) if int(f.get('index',0))<=frame for v in f.findall('x:Actionscript/x:script',NS)]
  if active_scripts and 'visible = false;' in active_scripts[-1]:return []
  # AS-loaded photographs are a child of this exact named MovieClip.
  if not text_only and spec.get('photo') and path==spec.get('photo_path','Mov.Mov'):
   records.append({'key':key+'/photo','source':path+'/external:'+spec['photo'],'photo':spec['photo'],'matrix':t,'color':color})
  # Static text and pointer/pulse wrappers are represented by native UI.
  layers=root.findall('./x:timeline/x:DOMTimeline/x:layers/x:DOMLayer',NS)
  for li,layer in enumerate(reversed(layers)):
   fs=layer.findall('x:frames/x:DOMFrame',NS)
   active=[f for f in fs if int(f.get('index',0))<=frame<int(f.get('index',0))+int(f.get('duration',1))]
   if not active:continue
   f=active[-1]
   for ei,e in enumerate(f.findall('x:elements/*',NS)):
    tag=e.tag.split('}')[-1];part=e.get('name','');p=(path+'.'+part).strip('.') if part else path
    if part and ((not text_only and (p in hide or part in hide)) or (part.startswith('But') and not spec.get('scene_button_art')) or part=='Vikl'):continue
    if tag in ['DOMStaticText','DOMDynamicText'] and not text_only:continue
    m=combine(t,matrix(e));c=e.find('x:color/x:Color',NS)
    vals=tuple(float(c.get(ch+'Multiplier','1')) if c is not None else 1 for ch in ['red','green','blue','alpha'])
    offset=tuple(float(c.get(ch+'Offset','0'))/255 if c is not None else 0 for ch in ['red','green','blue'])
    co=tuple(color[i]*vals[i] for i in range(4))+tuple(color[4+i]+color[i]*offset[i] for i in range(3));k=key+'/'+str(li)+':'+str(ei)
    if tag in ['DOMStaticText','DOMDynamicText']:
     text='@tv_channel' if part=='Can' else ''.join(v.text or '' for v in e.findall('.//x:characters',NS))
     records.append({'key':k+':text','text':text,'matrix':m,'color':co})
    elif tag=='DOMSymbolInstance':
     child=e.get('libraryItemName');k+=':'+child
     # A SimpleButton's state timeline must not auto-play.
     if child=='Symbol 27' and spec.get('native_qte') and not text_only:
      records.append({'key':k+':prompt','prompt':True,'matrix':m,'color':co})
      continue
     if e.get('symbolType')=='button' or child=='Symbol 27':continue
     start,end,loop=self.segment(child,ov.get(p) if part else None,outro and bool(part) and (p in ['Mov','Canals'] or p.endswith('.Knop')))
     # Frame overrides for text variants and TV channels are selected states.
     if part and (p.endswith('Hist') or p=='Canals.Mov'):start=end=ov.get(p,int(e.get('firstFrame',0)))
     # A newly placed child starts its own timeline on its birth frame.
     signature=(e.get('name'),child,ei)
     birth=int(f.get('index',0))
     for previous in reversed([v for v in fs if int(v.get('index',0))<birth]):
      elements=previous.findall('x:elements/*',NS)
      if ei>=len(elements) or (elements[ei].get('name'),elements[ei].get('libraryItemName'),ei)!=signature:break
      birth=int(previous.get('index',0))
     age=max(0,tick-max(0,birth-origin))
     if e.get('symbolType')=='graphic':age=0
     cf=start+(age%(end-start+1) if loop and end>=start else min(age,max(0,end-start)))
     if loop and self.info(child)[0]>1 and e.get('symbolType')!='graphic':self.period=math.lcm(self.period,self.info(child)[0])
     if spec.get('script_cycle') and child=='Symbol 2537':cf=0 if tick<20 else 1
     if self.info(child)[0]>1:
      self.audit[child]={'frames':self.info(child)[0],'stops':self.info(child)[1]}
     records+=self.walk(child,cf,age,ov,hide,spec,p,m,co,k,depth+1,outro,start,text_only)
    elif not text_only and tag in ['DOMShape','DOMBitmapInstance','DOMGroup']:
     records.append({'key':k+':'+tag,'source':p+'/'+name,'element':e,'matrix':m,'color':co})
  return records

def build(archive,only=None):
 with tempfile.TemporaryDirectory() as td:
  temp=Path(td);lib=temp/'LIBRARY';lib.mkdir();photos=temp/'Images';photos.mkdir()
  with zipfile.ZipFile(archive) as z:
   for n in z.namelist():
    if '/ZombieApocalypse/LIBRARY/' in n and n.endswith(('.xml','.png','.jpg')):(lib/Path(n).name).write_bytes(z.read(n))
    elif n.startswith('assets/Images/') and not n.endswith('/'):(photos/Path(n).name).write_bytes(z.read(n))
  tl=Timelines(lib);out=ROOT/'assets/flash_ui/episode1_animation_parts';out.mkdir(exist_ok=True)
  renderer=Exporter(lib,out,ROOT/'fonts/flash');renderer.scratch=temp;renderer.raster_cache={};renderer.parts=[];renderer.result_mode=False
  result=json.loads((ROOT/'data/episode1_animations.json').read_text()) if only else {'fps':19,'art':{},'audit':{}}
  components=json.loads((ROOT/'data/episode1_components.json').read_text())
  for art,(items,spec) in sorted(plans(ROOT).items()):
   if only and art not in only:continue
   if art.startswith(('item','result','decision','ep2_','city_decision')) or 'controls' in art:continue
   # Use the selected route's stop key, not an arbitrary playback duration.
   sequences=[];periods=[]
   if art=="ep1_mainstreet_run":spec=dict(spec,script_cycle=True)
   if art in ['layout_bg_wake','layout_bg_lift_button']:
    spec=dict(spec,photo='Fon1_1.png' if art=='layout_bg_wake' else 'LiftKnop.jpg',photo_path='Mov.Mov')
   for phase in ['intro','outro']:
    states=[];tl.period=1
    for tick in range(40 if spec.get("script_cycle") else 81):
     frame=[]
     for ri,(symbol,index,x,y,ov,hide) in enumerate(items):
      root_index=index
      if symbol=='Symbol 2545' and index==11:
       root_index=min(tick,11) if phase=='intro' else min(12+tick,15)
      frame+=tl.walk(symbol,root_index,tick,ov,set(hide),spec,t=(1,0,0,1,x,y),key=str(ri),outro=phase=='outro',origin=(0 if phase=='intro' else 12) if symbol=='Symbol 2545' and index==11 else index)
     states.append(frame)
    sequences.append(states);periods.append(tl.period)
   pool={}
   for states in sequences:
    for f in states:
     for record in f:pool.setdefault(record['key'],[]).append(record)
   primitives={};refs={}
   for key,records in pool.items():
    # Anchor on a visible, neutral-color frame; animated matrices remain data.
    ref=max(records,key=lambda r:-abs(r['matrix'][4])-abs(r['matrix'][5])-800*abs(r['matrix'][0]-1)-480*abs(r['matrix'][3]-1))
    renderer.parts=[]
    if 'existing' in ref:part=dict(ref['existing'])
    else:
     e=ref.get('element');renderer.defs=[];renderer.uid=0
     if 'photo' in ref:
      file=photos/ref['photo']
      with Image.open(file) as im:w,h=im.size
      body=f'<image width="{w}" height="{h}" xlink:href="data:image/png;base64,{base64.b64encode(file.read_bytes()).decode()}"/>'
     elif e.tag.endswith('DOMShape'):body=renderer.shape(e)
     elif e.tag.endswith('DOMGroup'):body=''.join(renderer.shape(ch) for ch in e.findall('x:members/*',NS) if ch.tag.endswith('DOMShape'))
     else:
      file=lib/e.get('libraryItemName')
      with Image.open(file) as im:w,h=im.size
      body=f'<image width="{w}" height="{h}" xlink:href="data:image/png;base64,{base64.b64encode(file.read_bytes()).decode()}"/>'
     if e is not None and e.tag.endswith('DOMShape') and renderer.panel(e,ref['matrix'],1,ref['source']):pass
     else:renderer.emit(body,ref['matrix'],1,ref['source'],blur_spec(e) if e is not None else None)
     if not renderer.parts:continue
     part=renderer.parts[0]
    # Existing art is reused when the unmodified pixels already exist.
    if part.get('texture'):
     filename=Path(part['texture']).name
     old=ROOT/'assets/flash_ui/episode1_components'/filename
     if old.exists():
      generated=ROOT/'assets/flash_ui'/part['texture']
      if generated!=old:generated.unlink(missing_ok=True)
      part['texture']='episode1_components/'+filename
    primitives[key]=part;refs[key]=ref['matrix']
   phase_records={}
   for phase,states in zip(['intro','outro'],sequences):
    frames=[]
    for f in states:
     row=[]
     for r in f:
      k=r['key']
      if k not in primitives:continue
      a,b,c,d,x,y=refs[k];det=a*d-b*c
      if abs(det)<1e-9:continue
      inv=(d/det,-b/det,-c/det,a/det,(c*y-d*x)/det,(b*x-a*y)/det)
      delta=combine(r['matrix'],inv)
      row.append([k,[round(v,6) for v in delta],[round(v,6) for v in r['color']]])
     frames.append(row)
    while len(frames)>1 and frames[-1]==frames[-2]:frames.pop()
    phase_records[phase]=frames
   if len(phase_records['intro'])>1 or len(phase_records['outro'])>1:
    result['art'][art]={'parts':primitives,'clip':str(items[0][0])+':'+str(items[0][1]),'intro_loop':periods[0] if len(phase_records['intro'])==81 else 0,**phase_records}
    print(art,len(primitives),'intro',len(phase_records['intro']),'outro',len(phase_records['outro']),flush=True)
  result.setdefault('audit',{}).update(tl.audit)
  (ROOT/'data/episode1_animations.json').write_text(json.dumps(result,separators=(',',':'))+'\n')
  used={Path(p['texture']).name for v in result['art'].values() for p in v['parts'].values() if p.get('texture','').startswith(out.name+'/')}
  for file in out.glob('*.png'):
   if file.name not in used:
    file.unlink();Path(str(file)+".import").unlink(missing_ok=True)
  print('Exported',len(result['art']),'animated art sets,',len(used),'unique new component textures')
if __name__=='__main__':
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('archive',type=Path);p.add_argument('--only',nargs='+');a=p.parse_args();build(a.archive,set(a.only) if a.only else None)
