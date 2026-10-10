"""Render original XFL art to 2x PNG; recover font glyphs from the original SWF.
No Adobe/Flash runtime dependency in the Godot project.
"""
import base64,html,json,re,subprocess,tempfile,os
from pathlib import Path
import xml.etree.ElementTree as E
from fontTools.ttLib import TTFont
from fontTools.pens.svgPathPen import SVGPathPen
from fontTools.pens.transformPen import TransformPen
from PIL import Image
NS={'x':'http://ns.adobe.com/xfl/2008/'}
FONT_IDS={'28 Days Later Cyr Regular':1,'GraffitiC1 Medium':2,'Oswald Medium':2,'SegoeScript':2508,'Segoe Script':2508,'B52 Regular':2511,'Caveat Medium':2508,'DS Crystal Regular':2836,'DSEG7 Classic':2836,'Verdana':2,'Lucida Console':314,'JetBrains Mono NL Regular':314}

def number(v):
 if v.startswith('#'):
  p=v[1:].split('.');n=int(p[0],16);n=n-(1<<32) if n&(1<<31) else n
  return n+(int(p[1],16)/(16**len(p[1])) if len(p)>1 else 0)
 return float(v)

def path_data(edges):
 tokens=re.findall(r'[!|\[\]]|#[0-9A-Fa-f]+(?:\.[0-9A-Fa-f]+)?|-?\d+(?:\.\d+)?',edges);out=[];i=0
 while i<len(tokens):
  op=tokens[i];i+=1
  if op in ['!','|'] and i+1<len(tokens):
   x,y=number(tokens[i])/20,number(tokens[i+1])/20;i+=2;out.append(f'{"M" if op=="!" else "L"}{x:g},{y:g}')
  elif op=='[' and i+3<len(tokens):
   p=[number(t)/20 for t in tokens[i:i+4]];i+=4;out.append('Q'+','.join(f'{x:g}' for x in p))
 return ' '.join(out)

class Renderer:
 def __init__(self,library,out,fonts):
  self.library=Path(library);self.out=Path(out);self.fonts={i:TTFont(Path(fonts).parent/'jetbrains_mono/JetBrainsMonoNL-Regular.ttf' if i==314 else Path(fonts).parent/'caveat/Caveat-Medium.ttf' if i in [2508,2511] else Path(fonts).parent/'oswald/Oswald-Medium.ttf' if i in [1,2] else Path(fonts).parent/'dseg/DSEG7Classic-Regular.ttf' if i==2836 else Path(fonts)/f'font_{i}.ttf') for i in set(FONT_IDS.values())};self.defs=[];self.uid=0;self.cache={}
 def root(self,name):
  if name not in self.cache:
   root=E.parse(self.library/(name+'.xml')).getroot()
   # The navigation chevron occupies the right half of its bitmap sheet.
   # Register the visible half at x=0 instead of retaining 380 source units.
   if name=='Symbol 53':
    for shape in root.findall('.//x:DOMShape',NS):
     matrix=E.SubElement(shape,'{'+NS['x']+'}matrix')
     E.SubElement(matrix,'{'+NS['x']+'}Matrix',{'tx':'-380','ty':'0'})
   self.cache[name]=root
  return self.cache[name]
 def matrix(self,e,bitmap=False):
  m=e.find('./x:matrix/x:Matrix',NS)
  if m is None:return 'matrix(1 0 0 1 0 0)'
  a=[float(m.get(k,str(default))) for k,default in zip(['a','b','c','d','tx','ty'],[1,0,0,1,0,0])]
  if bitmap:a[:4]=[x/20 for x in a[:4]]
  return 'matrix('+' '.join(f'{x:g}' for x in a)+')'
 def shape(self,e):
  fills={int(f.get('index')):f for f in e.findall('./x:fills/x:FillStyle',NS)};groups={}
  for edge in e.findall('./x:edges/x:Edge',NS):
   data=path_data(edge.get('edges',''))
   if not data:continue
   for style in set([int(edge.get('fillStyle0','0')),int(edge.get('fillStyle1','0'))]):
    if style:groups.setdefault(style,[]).append(data)
  out=[]
  for idx,paths in groups.items():
   if idx not in fills:continue
   f=fills[idx];color=f.find('x:SolidColor',NS);bitmap=f.find('x:BitmapFill',NS);alpha=1
   if bitmap is not None and getattr(self,'omit_brushes',False) and bitmap.get('bitmapPath') in {'Bitmap 5.png','Bitmap 62.png','Bitmap 103.png','Bitmap 95.png','Bitmap 206.png','Bitmap 153.png','Bitmap 17.png','Bitmap 91.png'}:continue
   if color is not None:paint=color.get('color','#000000');alpha=float(color.get('alpha','1'))
   elif bitmap is not None:
    self.uid+=1;pid=f'p{self.uid}';file=self.library/bitmap.get('bitmapPath');im=Image.open(file);mime='image/png' if file.suffix=='.png' else 'image/jpeg';url=f'data:{mime};base64,'+base64.b64encode(file.read_bytes()).decode()
    self.defs.append(f'<pattern id="{pid}" patternUnits="userSpaceOnUse" width="{im.width}" height="{im.height}" patternTransform="{self.matrix(bitmap,True)}"><image width="{im.width}" height="{im.height}" xlink:href="{url}"/></pattern>');paint=f'url(#{pid})'
   else:
    grad=next(iter(f),None)
    if grad is None:continue
    self.uid+=1;pid=f'g{self.uid}';stops=''.join(f'<stop offset="{float(s.get("ratio","0"))}" stop-color="{s.get("color","#000000")}" stop-opacity="{s.get("alpha","1")}"/>' for s in grad.findall('x:GradientEntry',NS))
    self.defs.append(f'<linearGradient id="{pid}" x1="-819.2" x2="819.2" gradientUnits="userSpaceOnUse" gradientTransform="{self.matrix(grad)}">{stops}</linearGradient>');paint=f'url(#{pid})'
   out.append(f'<path d="{html.escape(" ".join(paths))}" fill="{paint}" fill-opacity="{alpha}" fill-rule="evenodd"/>')
  return ''.join(out)
 def text(self,e):
  # Convert embedded glyphs to paths, so no machine-installed font is required.
  out=[];y=2.0;width=float(e.get('width','800'))
  for run in e.findall('./x:textRuns/x:DOMTextRun',NS):
   t=run.find('x:characters',NS);attrs=run.find('./x:textAttrs/x:DOMTextAttrs',NS)
   if t is None or not t.text or attrs is None:continue
   font=self.fonts[FONT_IDS.get(attrs.get('face'),2)];scale=float(attrs.get('size','24'))/font['head'].unitsPerEm;gs=font.getGlyphSet();cmap=font.getBestCmap();ascent=font['hhea'].ascent*scale
   for line in t.text.replace('\r','\n').strip('\n').split('\n'):
    names=[cmap.get(ord(c),'.notdef') for c in line];length=sum(font['hmtx'][n][0]*scale for n in names)
    align=attrs.get('alignment');x=2.0+(max(0,(width-length)/2) if align=='center' else max(0,width-length) if align=='right' else 0)
    for name in names:
     pen=SVGPathPen(gs);gs[name].draw(TransformPen(pen,(scale,0,0,-scale,x,y+ascent)))
     out.append(f'<path d="{pen.getCommands()}" fill="{attrs.get("fillColor","#ffffff")}" fill-opacity="{attrs.get("alpha","1")}"/>');x+=font['hmtx'][name][0]*scale
    y+=float(attrs.get('size','24'))+float(attrs.get('lineSpacing','0'))
  return ''.join(out)
 def display_frame(self,name,frame):
  root=self.root(name)
  if frame==0 and root.get('symbolType')=='button':
   frames=[int(f.get('index','0')) for f in root.findall('./x:timeline/x:DOMTimeline/x:layers/x:DOMLayer/x:frames/x:DOMFrame',NS)]
   if frames and min(frames)>0:return min(frames)
  return frame
 def symbol(self,name,frame=0,overrides=None,hide=None,path='',depth=0):
  if depth>35:return ''
  frame=self.display_frame(name,frame)
  overrides=overrides or {};hide=hide or set();root=self.root(name);out=[]
  layers=root.findall('./x:timeline/x:DOMTimeline/x:layers/x:DOMLayer',NS)
  for layer in reversed(layers):
   fs=layer.findall('./x:frames/x:DOMFrame',NS);active=None
   for f in fs:
    if int(f.get('index','0'))<=frame:active=f
   if active is None:continue
   for e in active.findall('./x:elements/*',NS):
    tag=e.tag.split('}')[-1];part=e.get('name','');childpath=(path+'.'+part).strip('.') if part else path
    if part and (childpath in hide or part in hide):continue
    body=''
    if tag=='DOMSymbolInstance':
     child=e.get('libraryItemName');fr=int(e.get('firstFrame','0'));fr=overrides.get(childpath,fr)
     body=self.symbol(child,fr,overrides,hide,childpath,depth+1)
    elif tag=='DOMShape':body=self.shape(e)
    elif tag in ['DOMStaticText','DOMDynamicText']:body=self.text(e)
    elif tag=='DOMGroup':
     for c in e.findall('./x:members/*',NS):
      if c.tag.endswith('DOMShape'):body+=self.shape(c)
    elif tag=='DOMBitmapInstance':
     file=self.library/e.get('libraryItemName');im=Image.open(file);url='data:image/png;base64,'+base64.b64encode(file.read_bytes()).decode();body=f'<image width="{im.width}" height="{im.height}" xlink:href="{url}"/>'
    if body:
     color=e.find('./x:color/x:Color',NS);alpha=float(color.get('alphaMultiplier','1')) if color is not None else 1
     out.append(f'<g transform="{self.matrix(e)}" opacity="{alpha}">{body}</g>')
  return ''.join(out)
 def render(self,filename,symbols,width=800,height=480):
  self.defs=[];body=''
  for item in symbols:
   name,frame,x,y,overrides,hide=item;body+=f'<g transform="translate({x},{y})">{self.symbol(name,frame,overrides,hide)}</g>'
  if getattr(self,'clip_rects',None):
   rects=''.join(f'<rect x="{r[0]}" y="{r[1]}" width="{r[2]}" height="{r[3]}"/>' for r in self.clip_rects)
   self.defs.append('<clipPath id="buttonIconsClip">'+rects+'</clipPath>')
   body='<g clip-path="url(#buttonIconsClip)">'+body+'</g>'
  svg=f'<svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" width="{width}" height="{height}" viewBox="0 0 {width} {height}"><defs>{"".join(self.defs)}</defs>{body}</svg>'
  self.out.mkdir(parents=True,exist_ok=True)
  with tempfile.TemporaryDirectory() as tmp:
   p=Path(tmp)/'ui.svg';p.write_text(svg)
   subprocess.run(['inkscape',str(p),'--export-type=png',f'--export-filename={p.parent/"ui.png"}',f'--export-width={width*2}',f'--export-height={height*2}'],check=True,stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL)
   # Publish only a complete PNG; importers never see an unfinished export.
   with Image.open(p.parent/"ui.png") as check:
    check.load()
    temporary = self.out/(filename+".tmp")
    check.save(temporary,format="PNG")
  os.replace(temporary,self.out/filename)
  with open(self.out/filename,"rb") as f: os.fsync(f.fileno())
  print(filename)

if __name__=='__main__':
 import sys
 r=Renderer(sys.argv[1],sys.argv[2],sys.argv[3]);r.render('menu.png',[('Symbol 150',0,0,0,{},set()),('Symbol 118',0,0,0,{},set()),('Symbol 132',8,415,70,{},set())])
