"""Recover Episode I display-list primitives from XFL; never execute AS.
Usage: python tools/build_episode1_components.py original.zip
"""
import argparse,base64,copy,hashlib,json,math,re,subprocess,tempfile,zipfile,os
from pathlib import Path
from PIL import Image,ImageOps
from render_flash_ui import Renderer,NS,path_data
from build_localized_ui import matrix,combine,brushes
from story_graph_format import load_all
from build_result_ui import ResultRenderer

ROOT=Path(__file__).resolve().parents[1]
class Exporter(ResultRenderer):
 def shape(self,e):
  return ResultRenderer.shape(self,e) if self.result_mode else Renderer.shape(self,e)
 def text(self,e):return ''
 def emit(self,body,transform,opacity,path):
  if not body or opacity<=0:return
  m=' '.join(str(v) for v in transform)
  svg=f'<svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" width="800" height="480" viewBox="0 0 800 480"><defs>{"".join(self.defs)}</defs><g transform="matrix({m})" opacity="{opacity}">{body}</g></svg>'
  key=hashlib.sha256(svg.encode()).hexdigest()
  if key not in self.raster_cache:
   source=self.scratch/'part.svg';source.write_text(svg)
   result=self.scratch/'part.png'
   subprocess.run(['inkscape',str(source),'--export-type=png',f'--export-filename={result}','--export-width=1600','--export-height=960'],check=True,stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL)
   with Image.open(result) as im:self.raster_cache[key]=self.store(im.convert('RGBA'))
  part=self.raster_cache[key]
  if part:self.parts.append(dict(part,source=path))
 def store(self,im):
  bounds=im.getchannel('A').getbbox()
  if bounds is None:return None
  im=im.crop(bounds)
  digest=hashlib.sha256(str(im.size).encode()+im.tobytes()).hexdigest()[:20]
  filename='part_'+digest+'.png';dest=self.out/filename
  valid=False
  if dest.exists():
   try:
    with Image.open(dest) as existing:existing.load();valid=True
   except (OSError,ValueError):pass
  if not valid:
   temporary=dest.with_suffix('.tmp')
   encoded=im.convert('RGB') if im.getchannel('A').getextrema()==(255,255) else im
   encoded.save(temporary,format='PNG',compress_level=6)
   with temporary.open('rb') as complete:os.fsync(complete.fileno())
   os.replace(temporary,dest)
  return {'type':'texture','texture':self.out.name+'/'+filename,'rect':[bounds[0]/2,bounds[1]/2,im.width/2,im.height/2]}
 def panel(self,e,t,alpha,path):
  fills=e.findall('./x:fills/x:FillStyle',NS);edges=e.findall('./x:edges/x:Edge',NS)
  if len(fills)!=1 or len(edges)!=1 or e.find('./x:strokes/*',NS)is not None:return False
  c=fills[0].find('x:SolidColor',NS)
  if c is None or abs(t[1])+abs(t[2])>1e-8:return False
  d=path_data(edges[0].get('edges',''))
  if 'Q' in d:return False
  values=[float(v) for v in re.findall(r'-?\d+(?:\.\d+)?',d)]
  points=list(zip(values[::2],values[1::2]));xs=sorted({p[0] for p in points});ys=sorted({p[1] for p in points})
  if len(xs)!=2 or len(ys)!=2 or set(points)!={(x,y) for x in xs for y in ys}:return False
  # Convert exact axis-aligned rectangle shapes to native ColorRect.
  x=sorted([t[0]*v+t[4] for v in xs]);y=sorted([t[3]*v+t[5] for v in ys]);color=c.get('color','#000000').lstrip('#')
  self.parts.append({'type':'panel','rect':[x[0],y[0],x[1]-x[0],y[1]-y[0]],'color':[int(color[i:i+2],16)/255 for i in [0,2,4]]+[alpha*float(c.get('alpha','1'))],'source':path})
  return True
 def walk(self,name,frame,ov,hide,path='',t=(1,0,0,1,0,0),alpha=1,depth=0):
  if depth>35 or name in self.omit_symbols or name in ['Symbol 88']:return
  if name=='Symbol 27' and getattr(self,'native_qte_buttons',False):
   points=[(t[0]*x+t[2]*y+t[4],t[1]*x+t[3]*y+t[5]) for x,y in [(0,0),(112,0),(0,112),(112,112)]]
   xs,ys=zip(*points)
   self.parts.append({'type':'qte_prompt','rect':[min(xs),min(ys),max(xs)-min(xs),max(ys)-min(ys)],'transform':list(t),'opacity':alpha,'text':'@loc:ui.qte.press','source':path+'/'+name})
   return
  if self.photo and path==self.photo_path:
   file=self.photos/self.photo
   with Image.open(file) as im:w,h=im.size
   mime='image/png' if file.suffix.lower()=='.png' else 'image/jpeg'
   url='data:'+mime+';base64,'+base64.b64encode(file.read_bytes()).decode()
   self.defs=[];self.emit(f'<image width="{w}" height="{h}" xlink:href="{url}"/>',t,alpha,path+'/external:'+self.photo)
  frame=self.display_frame(name,frame)
  for layer in reversed(self.root(name).findall('./x:timeline/x:DOMTimeline/x:layers/x:DOMLayer',NS)):
   fs=[f for f in layer.findall('./x:frames/x:DOMFrame',NS) if int(f.get('index','0'))<=frame]
   if not fs:continue
   for e in fs[-1].findall('./x:elements/*',NS):
    part=e.get('name','');p=(path+'.'+part).strip('.') if part else path
    if part and (p in hide or part in hide):continue
    m=combine(t,matrix(e));c=e.find('./x:color/x:Color',NS);a=alpha*(float(c.get('alphaMultiplier','1')) if c is not None else 1)
    tag=e.tag.split('}')[-1]
    if tag=='DOMSymbolInstance':self.walk(e.get('libraryItemName'),ov.get(p,int(e.get('firstFrame','0'))),ov,hide,p,m,a,depth+1)
    elif tag=='DOMShape':
     if self.omit_root_shapes and depth==0:continue
     if self.panel(e,m,a,p+'/'+name):continue
     self.defs=[];self.uid=0;self.emit(self.shape(e),m,a,p+'/'+name)
    elif tag=='DOMGroup':
     self.defs=[];self.uid=0;body=''.join(self.shape(ch) for ch in e.findall('./x:members/*',NS) if ch.tag.endswith('DOMShape'));self.emit(body,m,a,p+'/'+name)
    elif tag=='DOMBitmapInstance':
     f=self.library/e.get('libraryItemName')
     with Image.open(f) as im:w,h=im.size
     self.defs=[];self.emit(f'<image width="{w}" height="{h}" xlink:href="data:image/png;base64,{base64.b64encode(f.read_bytes()).decode()}"/>',m,a,p+'/'+name)
 def screen(self,name,items,spec=None):
  spec=spec or {};self.result_mode=name in ['result_alive','result_dead'];self.parts=[];self.photo=spec.get('photo','');self.photo_path=spec.get('photo_path','Mov.Mov');self.omit_symbols=set(spec.get('omit_symbols',[]));self.omit_root_shapes=spec.get('omit_root_shapes',False)
  for symbol,frame,x,y,ov,hide in items:self.walk(symbol,frame,ov,set(hide),t=(1,0,0,1,x,y))
  return self.parts

def plans(root):
 def s(n,f=0,x=0,y=0,o=None,h=None):return(f'Symbol {n}',f,x,y,o or {},h or set())
 nodes={k:v for k,v in load_all(root).items() if v.get('episode',1)==1}
 live={v[a] for v in nodes.values() if v.get('kind') not in ['city_death','city_ending'] for a in ['art','art_on_foot','controls_art','decision_art'] if a in v}
 manifests={};manifests.update(json.loads((root/'data/city_visuals.json').read_text()));manifests.update(json.loads((root/'data/episode1_visuals.json').read_text()))
 result={}
 for name in live:
  if name not in manifests:continue
  v=manifests[name];ov=dict(v.get('overrides',{}));ov.update(v.get('overrides_extra',{}))
  result[name]=([s(v['symbol'],v['frame'],o=ov,h=v.get('hide',[]))],v)
 for name,frame in [('wake',0),('screams',1),('morning_choice',2),('transport',4),('lift',5),('lift_button',6)]:
  ov={'Mov':14 if name=='wake' else 4 if name=='lift_button' else 0}
  result['layout_bg_'+name]=([s(2882,frame,o=ov,h=['Hist','But1','But2'])],{})
  result['layout_controls_'+name]=([s(2882,frame,o=ov,h=['Mov'])],{})
 for ch in range(7):result['layout_bg_tv_'+str(ch)]=([s(2882,3,o={'Canals':4,'Canals.Mov':ch},h=['Pult','Vikl'])],{})
 result['layout_controls_tv']=([s(2844,y=272),s(2820,x=379.95,y=382.4)],{})
 result['layout_controls_transport_no_keys']=([s(2882,4,h=['Mov','But2'])],{})
 result['adaptive_metro_background']=([s(2925,2,h=['Hist','But1','But2'])],{})
 result['adaptive_metro_controls']=([s(2925,2,h=['Mov'])],{})
 # Common episode UI is reused by later episodes, so migrate all its callers.
 result['item_keys']=([s(274,y=30,o={'Weapons':1,'ButExit':1},h=['Txt'])],{})
 # Metal answers are separate native buttons; these sets contain only the frame.
 for name in ['decision','city_decision_3','ep2_decision_4']:result[name]=([s(99,y=-18,h=['Txt']+[f'But{i}' for i in range(1,5)])],{})
 # PauseMov is exported independently by build_pause_components.py.
 for name,alive in [('result_dead',False),('result_alive',True)]:result[name]=([s(59,6,o={'Mov.Rezt':0,'Mov.Rezt.Symb':int(alive),'Mov.But1':1,'Mov.But2':1},h=['Itog','Mov.Rezt.Txt','Mov.Rezt.Opt','Mov.But3','Mov.StrBut3'])],{})
 return result

def build(archive,root,only=None):
 destination=root/'assets/flash_ui/episode1_components';destination.mkdir(exist_ok=True)
 with tempfile.TemporaryDirectory() as tmp:
  tmp=Path(tmp);lib=tmp/'LIBRARY';lib.mkdir();photos=tmp/'Images';photos.mkdir()
  with zipfile.ZipFile(archive) as z:
   for n in z.namelist():
    if '/ZombieApocalypse/LIBRARY/' in n and n.endswith(('.xml','.png','.jpg')):(lib/Path(n).name).write_bytes(z.read(n))
    elif n.startswith('assets/Images/') and not n.endswith('/'):(photos/Path(n).name).write_bytes(z.read(n))
  r=Exporter(lib,destination,root/'fonts/flash');r.photos=photos;r.scratch=tmp;r.raster_cache={};r.omit_brushes=True
  result=json.loads((root/"data/episode1_components.json").read_text()) if only else {}
  for name,(items,spec) in sorted(plans(root).items()):
   if only and name not in only:continue
   result[name]=r.screen(name,items,spec)
   if name in ['layout_bg_wake','layout_bg_lift_button']:
    file=photos/('Fon1_1.png' if name=='layout_bg_wake' else 'LiftKnop.jpg')
    with Image.open(file) as im:part=r.store(ImageOps.fit(im.convert('RGBA'),(1600,960)))
    result[name].insert(0,dict(part,source='external:'+file.name))
   print(name,len(result[name]),flush=True)
  brush_sets={}
  for name,(items,spec) in plans(root).items():
   records=[]
   for symbol,frame,x,y,ov,hide in items:records+=brushes(r,symbol,frame,ov,set(hide),transform=(1,0,0,1,x,y))
   if records:brush_sets[name]=records
  for name,parts in result.items():
   for part in parts:
    part['layer']='background'
    x,y,w,h=part['rect']
    for b in brush_sets.get(name,[]):
     bx,by,bw,bh=b['rect']
     if bx<=x+w/2<=bx+bw and by<=y+h/2<=by+bh and w<=bw*1.4 and h<=bh*1.4:part['layer']='foreground';break
  (root/'data/episode1_brushes.json').write_text(json.dumps(brush_sets,ensure_ascii=False,indent=2)+'\n')
  (root/'data/episode1_components.json').write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n')
  used={p['texture'].split('/')[-1] for ps in result.values() for p in ps if p['type']=='texture'}
  for f in destination.glob('*.png'):
   if f.name not in used:f.unlink();Path(str(f)+'.import').unlink(missing_ok=True)
 from clean_episode1_art import retired
 for f in retired(root):f.unlink();Path(str(f)+'.import').unlink(missing_ok=True)

if __name__=='__main__':
 p=argparse.ArgumentParser();p.add_argument('archive',type=Path);p.add_argument('--output',type=Path,default=ROOT);p.add_argument('--only',nargs='+');a=p.parse_args();build(a.archive,a.output,a.only)
