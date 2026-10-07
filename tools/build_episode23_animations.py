"""Export Episode II/III/IV MovieClip layers and native caption/QTE tracks.
Usage: python tools/build_episode23_animations.py ORIGINAL.zip
The frame budget follows the source timelines (including the 126-frame roof).
"""
import argparse,base64,copy,hashlib,json,tempfile,zipfile
from pathlib import Path
from PIL import Image
from build_episode1_animations import Timelines
from build_episode1_components import Exporter
from build_episode2_components import plans as plans2
from build_episode3_components import plans as plans3
from build_localized_ui import combine
from render_flash_ui import NS
from episode1_blur import blur_spec
from story_graph_format import load_all
from eye_closure_parts import eye_part,export_texture,annotate
ROOT=Path(__file__).resolve().parents[1]

class EpisodeTimelines(Timelines):
 def segment(self,name,target=None,outro=False):
  if target is not None:target=min(target,self.info(name)[0]-1)
  if name in getattr(self,"continuous_symbols",set()) and not outro:
   length,stops=self.info(name)
   return 0,target if target is not None else length-1,False
  return super().segment(name,target,outro)
 def walk(self,*args,**kwargs):
  spec=kwargs.get("spec",args[5] if len(args)>5 else {})
  name=kwargs.get("name",args[0] if args else "")
  if name in spec.get("omit_symbols",[]):return []
  result=super().walk(*args,**kwargs)
  depth=kwargs.get('depth',args[10] if len(args)>10 else 0)
  if depth==0:
   for record in result:
    if 'element' not in record:continue
    element=copy.deepcopy(record['element'])
    for child in list(element):
     if child.tag.split('}')[-1] in ['matrix','color']:element.remove(child)
    import xml.etree.ElementTree as ET
    # Replacement shapes at the same display-list slot are separate primitives.
    record['key']+=':'+hashlib.sha256(ET.tostring(element)).hexdigest()[:12]
  return result

def selected_plans(ep):
 plans=plans2(ROOT) if ep==2 else plans3(ROOT,ep)
 result={}
 cutscene_art={n.get('art') for n in load_all(ROOT).values() if n.get('episode')==ep and n.get('kind')=='city_cutscene'}
 for art,(items,spec) in sorted(plans.items()):
  if any(z in art for z in ['controls','item','continue_button','dialogue']):continue
  if '_anim_' in art and not art.endswith('_anim_0'):continue
  spec=dict(spec,native_qte=True,scene_button_art=True,continuous=art in cutscene_art)
  if '_anim_' in art:
   prefix=art.rsplit('_anim_',1)[0]+'_anim_'
   last=max(int(k[len(prefix):]) for k in plans if k.startswith(prefix))
   final_overrides=plans[prefix+str(last)][0][0][4]
   items=[(s,f,x,y,dict(final_overrides),hide) for s,f,x,y,ov,hide in items]
   spec['qte']=True
  result[art]=(items,spec)
 return result

def sequences(tl,items,spec,text_only=False):
 # A child cannot outlive the sum of its source frame spans without looping.
 # 256 covers all selected source tracks; no silent 81-frame truncation.
 horizon=max(256,max((tl.info(s)[0] for s,*_ in items),default=1)+1)
 result={};periods={}
 tl.continuous_symbols=set()
 durations={}
 for symbol,index,x,y,ov,hide in items:
  for layer in tl.root(symbol).findall('./x:timeline/x:DOMTimeline/x:layers/x:DOMLayer',NS):
   for f in layer.findall('x:frames/x:DOMFrame',NS):
    if not int(f.get('index',0))<=index<int(f.get('index',0))+int(f.get('duration',1)):continue
    for e in f.findall('x:elements/x:DOMSymbolInstance',NS):
     if e.get('name')!='Mov':continue
     child=e.get('libraryItemName')
     if spec.get('continuous') or spec.get('qte'):tl.continuous_symbols.add(child)
     for phase in ['intro','outro']:
      start,end,_=tl.segment(child,ov.get('Mov'),phase=='outro')
      durations[phase]=max(durations.get(phase,1),end-start+1)
 for phase in ['intro','outro']:
  states=[];tl.period=1
  for tick in range(horizon):
   row=[]
   for ri,(symbol,index,x,y,ov,hide) in enumerate(items):
    row+=tl.walk(symbol,index,tick,ov,set(hide),spec,t=(1,0,0,1,x,y),key=str(ri),outro=phase=='outro',origin=index,text_only=text_only)
   states.append(row)
  result[phase]=states;periods[phase]=tl.period
 spec['durations']=durations
 return result,periods

def render_part(renderer,record,lib,photos):
 native_eye=eye_part(record.get('source',''),record['matrix'])
 if native_eye:
  export_texture(lib,ROOT)
  return native_eye
 if record.get('prompt'):
  return {'type':'qte_prompt','rect':[0,0,112,112],'text':'@loc:ui.qte.press','source':'Symbol 27'}
 renderer.parts=[];renderer.defs=[];renderer.uid=0
 e=record.get('element');body=''
 if 'photo' in record:
  file=photos/record['photo']
  with Image.open(file) as im:w,h=im.size
  body=f'<image width="{w}" height="{h}" xlink:href="data:image/png;base64,{base64.b64encode(file.read_bytes()).decode()}"/>'
 elif e.tag.endswith('DOMShape'):body=renderer.shape(e)
 elif e.tag.endswith('DOMGroup'):body=''.join(renderer.shape(ch) for ch in e.findall('x:members/*',NS) if ch.tag.endswith('DOMShape'))
 else:
  file=lib/e.get('libraryItemName')
  with Image.open(file) as im:w,h=im.size
  body=f'<image width="{w}" height="{h}" xlink:href="data:image/png;base64,{base64.b64encode(file.read_bytes()).decode()}"/>'
 if e is not None and e.tag.endswith('DOMShape') and renderer.panel(e,record['matrix'],1,record['source']):pass
 else:renderer.emit(body,record['matrix'],1,record['source'],blur_spec(e) if e is not None else None)
 return renderer.parts[0] if renderer.parts else None

def build(archive,episodes=(2,3)):
 with tempfile.TemporaryDirectory() as td:
  temp=Path(td);lib=temp/'LIBRARY';lib.mkdir();photos=temp/'Images';photos.mkdir()
  with zipfile.ZipFile(archive) as z:
   for n in z.namelist():
    if '/ZombieApocalypse/LIBRARY/' in n and n.endswith(('.xml','.png','.jpg')):(lib/Path(n).name).write_bytes(z.read(n))
    elif n.startswith('assets/Images/') and not n.endswith('/'):(photos/Path(n).name).write_bytes(z.read(n))
  for ep in episodes:
   tl=EpisodeTimelines(lib);out=ROOT/f'assets/flash_ui/episode{ep}_animation_parts';out.mkdir(exist_ok=True)
   renderer=Exporter(lib,out,ROOT/'fonts/flash');renderer.scratch=temp;renderer.raster_cache={};renderer.result_mode=False
   result={'fps':19,'art':{},'audit':{}};text_result={}
   for art,(items,spec) in selected_plans(ep).items():
    states,periods=sequences(tl,items,spec)
    pool={}
    for fs in states.values():
     for row in fs:
      for rec in row:pool.setdefault(rec['key'],[]).append(rec)
    primitives={};refs={}
    for key,records in pool.items():
     ref=max(records,key=lambda r:-abs(r['matrix'][4])-abs(r['matrix'][5])-800*abs(r['matrix'][0]-1)-480*abs(r['matrix'][3]-1))
     if ref.get('prompt'):ref=dict(ref,matrix=(1,0,0,1,0,0))
     part=render_part(renderer,ref,lib,photos)
     if not part:continue
     if part.get('texture') and 'eye_lid' not in part:
      filename=Path(part['texture']).name
      for directory in [f'episode{i}_components' for i in range(1,ep+1)]+[f'episode{i}_animation_parts' for i in range(1,ep)]:
       old=ROOT/'assets/flash_ui'/directory/filename
       if old.exists() and old!=ROOT/'assets/flash_ui'/part['texture']:
        (ROOT/'assets/flash_ui'/part['texture']).unlink(missing_ok=True)
        part['texture']=directory+'/'+filename;break
     primitives[key]=part;refs[key]=ref['matrix']
    tracks={}
    for phase,fs in states.items():
     frames=[]
     for row in fs:
      frame=[]
      for r in row:
       k=r['key']
       if k not in primitives:continue
       a,b,c,d,x,y=refs[k];det=a*d-b*c
       if abs(det)<1e-9:continue
       inv=(d/det,-b/det,-c/det,a/det,(c*y-d*x)/det,(b*x-a*y)/det)
       frame.append([k,[round(v,6) for v in combine(r['matrix'],inv)],[round(v,6) for v in r['color']]])
      frames.append(frame)
     minimum=spec.get('durations',{}).get(phase,1)
     while len(frames)>minimum and frames[-1]==frames[-2]:frames.pop()
     tracks[phase]=frames
    if spec.get('qte'):
     tracks['intro']=tracks['intro'][:spec['durations']['intro']]
     tracks['outro']=[copy.deepcopy(tracks['intro'][-1])]
    # Static scenes still get tracks when their native caption animates.
    text_states,_=sequences(tl,items,spec,True);anchors={};texts={}
    for phase,fs in text_states.items():
     rows=[]
     for row in fs:
      outrow=[]
      for r in row:
       text=' '.join(r['text'].split());outrow.append([text,list(r['matrix']),list(r['color'])]);anchors[text]=list(r['matrix'])
      rows.append(outrow)
     minimum=spec.get('durations',{}).get(phase,1)
     while len(rows)>minimum and rows[-1]==rows[-2]:rows.pop()
     texts[phase]=rows
    if spec.get('qte'):
     texts['intro']=texts['intro'][:spec['durations']['intro']]
     texts['outro']=[copy.deepcopy(texts['intro'][-1])]
    animated=any(len(v)>1 for v in tracks.values()) or any(len(v)>1 for v in texts.values()) or spec.get('qte')
    if animated:
     hold_outro=spec.get('qte') or spec.get('durations',{}).get('outro',1)<=1
     if hold_outro:
      tracks['outro']=[copy.deepcopy(tracks['intro'][-1])]
      texts['outro']=[copy.deepcopy(texts['intro'][-1])]
     for phase in ['intro','outro']:
      while len(tracks[phase])<len(texts[phase]):tracks[phase].append(copy.deepcopy(tracks[phase][-1]))
     used_keys={r[0] for fs in tracks.values() for row in fs for r in row}
     primitives={k:v for k,v in primitives.items() if k in used_keys}
     used_text={r[0] for fs in texts.values() for row in fs for r in row}
     anchors={k:v for k,v in anchors.items() if k in used_text}
     result['art'][art]={'parts':primitives,'clip':str(items[0][0])+':'+str(items[0][1]),'intro_loop':periods['intro'] if len(tracks['intro'])==len(states['intro']) else 0,'qte':bool(spec.get('qte')),'outro_hold':bool(hold_outro),**tracks}
     annotate(result['art'][art])
     text_result[art]={'anchors':anchors,**texts}
     print(ep,art,len(primitives),len(tracks['intro']),len(tracks['outro']),flush=True)
   result['audit']=tl.audit
   (ROOT/f'data/episode{ep}_animations.json').write_text(json.dumps(result,separators=(',',':'))+'\n')
   (ROOT/f'data/episode{ep}_text_animations.json').write_text(json.dumps(text_result,separators=(',',':'),ensure_ascii=False)+'\n')
   used={Path(p['texture']).name for v in result['art'].values() for p in v['parts'].values() if p.get('texture','').startswith(out.name+'/')}
   for f in out.glob('*.png'):
    if f.name not in used:f.unlink();Path(str(f)+'.import').unlink(missing_ok=True)
   if ep>=4:deduplicate_episode(ep)
   print('Episode',ep,'animated scenes',len(result['art']),'new unique textures',len(used),flush=True)
def deduplicate_episode(ep):
 """Keep one primitive asset across static and animated versions of a scene."""
 components_path=ROOT/f'data/episode{ep}_components.json'
 animations_path=ROOT/f'data/episode{ep}_animations.json'
 components=json.loads(components_path.read_text());animations=json.loads(animations_path.read_text())
 for spec in animations['art'].values():
  for part in spec['parts'].values():
   if 'texture' not in part:continue
   name=Path(part['texture']).name
   candidate=ROOT/f'assets/flash_ui/episode{ep}_components'/name
   if candidate.exists():part['texture']=f'episode{ep}_components/'+name
 # Runtime selects EpisodeTimeline for these names; the final-frame static
 # copies are unreachable. Retain controls, portraits, items and static scenes.
 components={k:v for k,v in components.items() if k not in animations['art']}
 components_path.write_text(json.dumps(components,ensure_ascii=False,indent=2)+'\n')
 animations_path.write_text(json.dumps(animations,separators=(',',':'))+'\n')
 referenced={p.get('texture') for parts in components.values() for p in parts}
 referenced.update(p.get('texture') for spec in animations['art'].values() for p in spec['parts'].values())
 for directory in [f'episode{ep}_components',f'episode{ep}_animation_parts']:
  for file in (ROOT/'assets/flash_ui'/directory).glob('*.png'):
   if directory+'/'+file.name not in referenced:file.unlink();Path(str(file)+'.import').unlink(missing_ok=True)

if __name__=='__main__':
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('archive',type=Path);p.add_argument('--episode',type=int,choices=[2,3,4]);a=p.parse_args();build(a.archive,(a.episode,) if a.episode else (2,3))
