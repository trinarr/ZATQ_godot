"""Rebuild text-free Flash UI layers plus native label layout from the original XFL.
Usage: python tools/build_localized_ui.py /path/to/LIBRARY
Requires Pillow, fontTools and Inkscape only when rebuilding assets.
"""
import argparse,csv,json,math
from pathlib import Path
from render_flash_ui import Renderer,NS,FONT_IDS,path_data
import re,copy
from PIL import Image
from build_result_ui import ResultRenderer
from build_episode2_content import active_elements
ROOT=Path(__file__).resolve().parents[1]
class CleanRenderer(Renderer):
 def text(self,e):return ''
class CleanResult(ResultRenderer):
 def text(self,e):return ''
class IconRenderer(CleanRenderer):
 def shape(self,e):
  e=copy.deepcopy(e)
  fills=e.find('x:fills',NS)
  if fills is None:return ''
  for fill in list(fills):
   bitmap=fill.find('x:BitmapFill',NS);color=fill.find('x:SolidColor',NS)
   keep=False
   if color is not None:
    value=color.get('color','#000000').lstrip('#');keep=min(int(value[i:i+2],16) for i in [0,2,4])>=180
   elif bitmap is not None and bitmap.get('bitmapPath') not in BRUSHES:
    with Image.open(self.library/bitmap.get('bitmapPath')) as image:keep=max(image.size)<=130
   if not keep:fills.remove(fill)
  return super().shape(e)

def matrix(e):
 m=e.find('./x:matrix/x:Matrix',NS)
 return tuple(float(m.get(k,str(v))) if m is not None else v for k,v in zip(['a','b','c','d','tx','ty'],[1,0,0,1,0,0]))
def combine(p,q):
 a,b,c,d,x,y=p;A,B,C,D,X,Y=q
 return (a*A+c*B,b*A+d*B,a*C+c*D,b*C+d*D,a*X+c*Y+x,b*X+d*Y+y)
def labels(r,name,frame,ov,hide,path='',transform=(1,0,0,1,0,0),depth=0):
 result=[]
 if depth>35:return result
 for e in active_elements(r,name,frame):
  part=e.get('name','');p=(path+'.'+part).strip('.') if part else path
  if part and (p in hide or part in hide):continue
  t=combine(transform,matrix(e))
  if e.tag.endswith('DOMSymbolInstance'):
   result+=labels(r,e.get('libraryItemName'),ov.get(p,int(e.get('firstFrame','0'))),ov,hide,p,t,depth+1)
  elif e.tag.endswith(('DOMStaticText','DOMDynamicText')):
   text=''.join(x.text or '' for x in e.findall('.//x:characters',NS)).strip().replace('\r','\n')
   attrs=e.find('.//x:DOMTextAttrs',NS)
   if not text or attrs is None:continue
   # UI source transforms are translations and positive uniform scales.
   sx=math.hypot(t[0],t[1]);sy=(t[0]*t[3]-t[1]*t[2])/sx
   if sx<=0 or sy<=0:raise ValueError('Mirrored text: '+p)
   result.append({'text':text,'rect':[t[4],t[5],float(e.get('width','0'))*sx,float(e.get('height','0'))*sy],'size':float(attrs.get('size','24'))*sy,'rotation':math.atan2(t[1],t[0]),'font':FONT_IDS.get(attrs.get('face'),2),'alignment':attrs.get('alignment','left'),'color':attrs.get('fillColor','#ffffff')})
 return result

BRUSHES={'Bitmap 5.png','Bitmap 62.png','Bitmap 103.png','Bitmap 95.png','Bitmap 206.png','Bitmap 153.png','Bitmap 17.png','Bitmap 91.png'}
def brushes(r,name,frame,ov,hide,path='',transform=(1,0,0,1,0,0),depth=0):
 result=[]
 if depth>35:return result
 for e in active_elements(r,name,frame):
  part=e.get('name','');p=(path+'.'+part).strip('.') if part else path
  if part and (p in hide or part in hide):continue
  t=combine(transform,matrix(e))
  if e.tag.endswith('DOMSymbolInstance'):
   result+=brushes(r,e.get('libraryItemName'),ov.get(p,int(e.get('firstFrame','0'))),ov,hide,p,t,depth+1)
  elif e.tag.endswith('DOMShape'):
   for fill in e.findall('./x:fills/x:FillStyle',NS):
    bitmap=fill.find('x:BitmapFill',NS)
    if bitmap is None or bitmap.get('bitmapPath') not in BRUSHES:continue
    idx=fill.get('index');points=[]
    for edge in e.findall('./x:edges/x:Edge',NS):
     if idx not in [edge.get('fillStyle0'),edge.get('fillStyle1')]:continue
     coords=[float(x) for x in re.findall(r'-?\d+(?:\.\d+)?',path_data(edge.get('edges','')))]
     points+=list(zip(coords[::2],coords[1::2]))
    if not points:continue
    x=min(v[0] for v in points);y=min(v[1] for v in points);w=max(v[0] for v in points)-x;h=max(v[1] for v in points)-y
    sx=math.hypot(t[0],t[1]);sy=(t[0]*t[3]-t[1]*t[2])/sx
    with Image.open(r.library/bitmap.get('bitmapPath')) as image:
     pixels=[v for v in image.convert('RGBA').get_flattened_data() if v[3]>128]
    color=[sum(v[i] for v in pixels)/len(pixels)/255 for i in range(3)]+[1.0]
    result.append({'rect':[t[0]*x+t[2]*y+t[4],t[1]*x+t[3]*y+t[5],w*sx,h*sy],'rotation':math.atan2(t[1],t[0]),'color':color,'path':p})
 return result

def build(library):
 r=CleanRenderer(library,ROOT/'assets/flash_ui',ROOT/'fonts/flash');rr=CleanResult(library,r.out,ROOT/'fonts/flash')
 r.omit_brushes=True;rr.omit_brushes=True
 icons=IconRenderer(library,r.out,ROOT/"fonts/flash");icons.omit_brushes=True
 def s(n,f=0,x=0,y=0,o=None,h=None):return(f'Symbol {n}',f,x,y,o or {},h or set())
 plans={'adaptive_menu':[s(118),s(132,8,415,70)],'adaptive_menu_off':[s(118,o={'SndCheck':1}),s(132,8,415,70)],'adaptive_help':[s(147,6)],'layout_pause':[s(83,5,0,61,{'Butns.But2':1,'Butns.But3':1,'Butns.But4':1,'Butns.But5':1},{'ForSound','Grey'})]}
 for name,fr in [('wake',0),('screams',1),('morning_choice',2),('transport',4),('lift',5),('lift_button',6)]:
  plans['layout_controls_'+name]=[s(2882,fr,o={'Mov':14 if name=='wake' else 4 if name=='lift_button' else 0},h={'Mov'})]
 plans['layout_controls_transport_no_keys']=[s(2882,4,h={'Mov','But2'})]
 plans['adaptive_metro_controls']=[s(2925,2,h={'Mov'})]
 for i in range(12):plans[f'adaptive_selector_{i}']=[s(211,o={'EpImg':i,'LeftOpt':2 if i in [1,3,6,8,10] else 0,'RightOpt':1 if i in [1,3,6,8,10] else 0,'But3':1,'But4':1,'But1':1,'But2':1},h={'NameTxt','EpOptions','InfoOpt','AnsNumb','txtWins','txtLoses'})]
 for name,alive in [('result_dead',False),('result_alive',True)]:plans[name]=[s(59,6,o={'Mov.Rezt':0,'Mov.Rezt.Symb':int(alive),'Mov.But1':1,'Mov.But2':1},h={'Itog','Mov.Rezt.Txt','Mov.Rezt.Opt','Mov.But3','Mov.StrBut3'})]
 # This empty dynamic field was assigned by InfoMov's first-frame script.
 for field in r.root('Symbol 146').findall('.//x:DOMDynamicText',NS):
  if field.get('name')=='Txt':
   field.find('.//x:characters',NS).text='Автор: Луканин Никита\nВерсия: {version}\n\nМатериалы тестов:\nKotbayun, UsVsTh3m и др.'
 plans['item_keys']=[s(274,y=30,o={'Weapons':1,'ButExit':1},h={'Txt'})]
 for name,weapon in [('ep2_item_glock',2),('ep2_item_mark23',3)]:plans[name]=[s(274,y=30,o={'Weapons':weapon,'ButExit':1},h={'Txt'})]
 for name,weapon in [('knife',4),('glock16',5),('glock7',6)]:plans['e3_item_'+name]=[s(274,y=30,o={'Weapons':weapon,'ButExit':1},h={'Txt'})]
 plans['e3_dialogue_john']=[s(237,1,o={'Ava':1,'Dlg1':0,'Dlg2':0,'Dlg3':0},h={'Txt','PrsnTxt','DlgTxt'})]
 plans['decision']=[s(99,y=-18,h={'Txt','But3','But4','But1.Txt','But2.Txt'})]
 plans['city_decision_3']=[s(99,y=-18,h={'Txt','But4','But1.Txt','But2.Txt','But3.Txt'})]
 plans['ep2_decision_4']=[s(99,y=-18,h={'Txt','But1.Txt','But2.Txt','But3.Txt','But4.Txt'})]
 plans['ep2_continue_button']=[s(8,1,67.05,360),s(54,0,93,376)]
 tables={};layout={};brush_layout={}
 for table_name in ['ui','episode1']:
  with (ROOT/f'locales/{table_name}.csv').open(newline='',encoding='utf-8') as f:
   reader=csv.DictReader(f);tables[table_name]=(reader.fieldnames,{row['key']:row for row in reader})
 for filename,items in plans.items():
  renderer=rr if filename.startswith('result_') else r
  renderer.render(filename+'.png',items)
  if filename=='e3_dialogue_john':
   with Image.open(renderer.out/(filename+'.png')) as image:image.save(renderer.out/(filename+'.webp'),format='WEBP',lossless=True)
   (renderer.out/(filename+'.png')).unlink()
  brush_layout[filename]=[]
  for name,frame,x,y,ov,hide in items:brush_layout[filename]+=brushes(renderer,name,frame,ov,hide,transform=(1,0,0,1,x,y))
  if brush_layout[filename]:
   icons.clip_rects=[b['rect'] for b in brush_layout[filename]]
   icons.render(filename+'_icons.png',items)
  blocks=[]
  for name,frame,x,y,ov,hide in items:blocks+=labels(renderer,name,frame,ov,hide,transform=(1,0,0,1,x,y))
  namespace='episode1' if filename.startswith('layout_controls_') or filename=='adaptive_metro_controls' else 'ui'
  headers,existing=tables[namespace]
  for i,block in enumerate(blocks):
   key=f'{namespace}.art.{filename}.{i}'
   row={h:'' for h in headers};row.update({'key':key,'ru':block['text']})
   existing.setdefault(key,row)
   block['text']='@loc:'+key
  layout[filename]=blocks
 for namespace,(headers,existing) in tables.items():
  with (ROOT/f'locales/{namespace}.csv').open('w',newline='',encoding='utf-8') as f:
   w=csv.DictWriter(f,fieldnames=headers,lineterminator="\n");w.writeheader();w.writerows(existing[k] for k in sorted(existing))
 (ROOT/'data/ui_brush_layout.json').write_text(json.dumps(brush_layout,indent=2)+'\n')
 (ROOT/'data/ui_text_layout.json').write_text(json.dumps(layout,ensure_ascii=False,indent=2)+'\n')
if __name__=='__main__':
 p=argparse.ArgumentParser();p.add_argument('library',type=Path);args=p.parse_args();build(args.library)
