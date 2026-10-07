"""Extract native popup and remote control motion from original MovieClips."""
import argparse,json,xml.etree.ElementTree as E
from pathlib import Path
NS={'x':'http://ns.adobe.com/xfl/2008/'}
ROOT=Path(__file__).resolve().parents[1]
def extract(library):
 result={'fps':19,'tracks':{}}
 for key,symbol,member,last in [('item',276,'Mov',5),('dialog',100,'Mov',6),('result',59,'Mov',6),('remote',2844,None,4)]:
  root=E.parse(library/f'Symbol {symbol}.xml').getroot();positions=[]
  for index in range(last+1):
   found=None
   for layer in root.findall('.//x:DOMLayer',NS):
    active=[f for f in layer.findall('x:frames/x:DOMFrame',NS) if int(f.get('index',0))<=index<int(f.get('index',0))+int(f.get('duration',1))]
    for f in active:
     for e in f.findall('x:elements/x:DOMSymbolInstance',NS):
      if e.get('name')==member:found=e
   m=found.find('x:matrix/x:Matrix',NS);positions.append([float(m.get('tx',0)),float(m.get('ty',0))])
  x,y=positions[-1]
  result['tracks'][key]={'source':f'Symbol {symbol}/{member or "Symbol 2843"}','start_frame':0 if key=='remote' else 1,'offsets':[[a-x,b-y] for a,b in positions]}
 # Symbol 97 dims only its answer plate; the label remains stationary.
 answer=E.parse(library/'Symbol 97.xml').getroot()
 colors={}
 for frame in answer.findall('.//x:DOMFrame',NS):
  for element in frame.findall('x:elements/x:DOMSymbolInstance',NS):
   if element.get('libraryItemName')!='Symbol 93':continue
   color=element.find('x:color/x:Color',NS)
   colors[int(frame.get('index',0))]=float(color.get('redMultiplier',1)) if color is not None else 1.0
 result['answer_tint']=[colors[i] for i in range(5)]
 return result
if __name__=='__main__':
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('library',type=Path);a=p.parse_args()
 (ROOT/'data/episode1_ui_animations.json').write_text(json.dumps(extract(a.library),indent=2)+'\n')
