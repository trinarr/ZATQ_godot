"""Recover both John web-story parts from the actual SWF, never the stale bundled XFL.
Usage: python tools/build_john_episode.py SOURCE.zip --ffdec /path/to/ffdec.jar
Requires Java/JPEXS, Inkscape and the existing component-export dependencies.
The two source parts are exported separately, then unified as bonus episode 101.
"""
import argparse,csv,json,re,subprocess,tempfile,zipfile
from pathlib import Path
from build_episode1_art import BackgroundRenderer
from build_episode2_content import active_elements,max_frame,text_blocks
from build_episode4_content import source_array
from migrate_story_graph import migrate
from render_flash_ui import NS
ROOT=Path(__file__).resolve().parents[1]
OFFSET=10000

def prepare(archive,ffdec,temp):
 with zipfile.ZipFile(archive) as z:
  swf=temp/'john.swf';swf.write_bytes(z.read('assets/ZombieApocalypse.swf'))
  sounds={Path(n).name:z.read(n) for n in z.namelist() if n.startswith('assets/Sound/') and n.endswith('.mp3')}
 for kind in ['script','xfl']:
  subprocess.run(['java','-jar',str(ffdec),'-export',kind,str(temp/kind),str(swf)],check=True)
 from extract_flash_fonts import extract
 extract(swf,temp/'fonts');(ROOT/'fonts/flash/john_console.ttf').write_bytes((temp/'fonts/font_314.ttf').read_bytes())
 lib=next((temp/'xfl').rglob('LIBRARY'));sources={p.stem:p.read_text(encoding='utf-8-sig') for p in (temp/'script').rglob('*.as')}
 normalized=temp/'john_normalized.zip'
 def remap(s):return re.sub(r'\b(Symbol|Bitmap) (\d+)',lambda m:f'{m[1]} {int(m[2])+OFFSET}',s)
 with zipfile.ZipFile(normalized,'w',zipfile.ZIP_DEFLATED) as z:
  for p in lib.iterdir():
   if p.suffix not in ['.xml','.png','.jpg']:continue
   z.writestr('John/ZombieApocalypse/LIBRARY/'+remap(p.name),remap(p.read_text()).encode() if p.suffix=='.xml' else p.read_bytes())
  for name,data in sounds.items():z.writestr('assets/Sound/'+name,data)
 return normalized,sources,sounds

def content(lib,sources,sounds):
 r=BackgroundRenderer(lib,ROOT/'assets/flash_ui',ROOT/'fonts/flash');r.photos=lib;r.retain_text=False;r.omit_symbols=set()
 questions=source_array(sources['NewItem'],'itemStrings');labels={(int(m[2]),int(m[1])):m[3] for m in re.finditer(r'this.but([1-4])Str\[(\d+)\]\s*=\s*"([^"]*)"',sources['NewItem'])}
 for ep,sym,last,part in [(101,10379,11,1),(102,10312,16,2)]:
  nodes={};visuals={}
  def nid(fr):return f'john{part}_{fr}'
  def branch(target,text='Далее',**kw):return {'text':text,'next':target,**kw}
  for fr in range(1,last+1):
   id=nid(fr);ov={}
   for e in active_elements(r,f'Symbol {sym}',fr-1):
    if e.get('name')=='Mov':ov['Mov']=max_frame(r,e.get('libraryItemName'))
   blocks=text_blocks(r,f'Symbol {sym}',fr-1,ov)
   if part==1 and fr<=3:
    texts=r.root(f'Symbol {10319+(fr-1)*3}').findall('.//x:characters',NS)
    report=''.join(c.text or '' for c in texts).strip().replace('\r>','\n\n>').replace('\r','\n')
    blocks=[{'text':report,'rect':[22,54,715,385],'size':19,'font':'Lucida Console','path':'ConsoleReport','line_spacing':-4,'padding':0,'minimum':19},
            {'text':'CONSOLE','rect':[13.75,9.3,220,30],'size':22,'font':'Lucida Console','path':'ConsoleHeading','padding':0,'minimum':22},
            {'text':'shiftOS ver. 1.567.89 Copyright STB Corporation. All rights reserved','rect':[171.55,454,623,22],'size':15,'font':'Lucida Console','path':'ConsoleFooter','padding':0,'minimum':15}]
   for b in blocks:
    if b['font']=='Lucida Console':b['font_file']='res://fonts/flash/john_console.ttf';b['wrap']=False
   nodes[id]={'episode':ep,'source':f'Web Episode{part} frame {fr}','kind':'city_story','art':id,'clean_background':True,'blocks':blocks,'text':' '.join(b['text'] for b in blocks),'choices':[branch(nid(fr+1),rect=[70,0,730,480])] if fr<last else []}
   script='\n'.join(f.findtext('x:Actionscript/x:script','',NS) for f in r.root(f'Symbol {sym}').findall('.//x:DOMFrame',NS) if int(f.get('index',0))==fr-1)
   sound=re.search(r'SndPlayer\("([^"]+)"',script)
   if sound:nodes[id]['sound']=sound[1]
   if 'addEventListener("End"' in script:nodes[id]['input_after_intro']=True
   visuals[id]={'symbol':sym,'frame':fr-1,'overrides':ov,'hide':['Hist'],'photo':'','omit_symbols':[]}
  def decision(fr,item,advance):
   id=nid(fr)+'_choice';choices=[]
   for i in range(1,4 if item in [1,2,5] else 3):
    c=branch(nid(fr+1) if i==advance else nid(fr),labels[item,i])
    if i!=advance:c['unfinished']=True
    choices.append(c)
   nodes[id]={'episode':ep,'source':f'Web NewItem({item})','kind':'city_decision','art':nid(fr),'clean_background':True,'text':questions[item-1],'back':nid(fr),'choices':choices}
   nodes[nid(fr)]['choices']=[branch(id,rect=[70,0,730,480])]
  def pickup(key,index,target,back):
   id=f'john{part}_pickup_{key}';art=id+'_item'
   visuals[art]={'symbol':10177,'frame':0,'overrides':{'Weapons':index,'ButExit':1},'hide':['Txt'],'offset_y':30,'photo':''}
   nodes[id]={'episode':ep,'source':f'Web AddItem({index})','kind':'city_pickup','art':art,'background_art':back,'text':source_array(sources['AddItem'],'weapStrings')[index-1],'sound':'TakeMessage' if index==1 else 'LaserTake','choices':[branch(target,'Забрать')]}
   return id
  if part==1:
   decision(7,1,2)
   art='john1_dialogue_alex';visuals[art]={'symbol':10165,'frame':1,'overrides':{'Ava':1},'hide':['Txt','PrsnTxt','Dlg1','Dlg2','Dlg3'],'photo':''}
   src=sources['Символ1051_97'];arrays={int(m[1]):json.loads(m[2]) for m in re.finditer(r'this.DlgArr\[(\d+)\] = (\[.*?\]);',src,re.S)}
   item=pickup('note',1,nid(9),nid(9))
   for i,slot,target in [(0,1,'john1_alex_1'),(1,2,item)]:
    a=arrays[i];nodes[f'john1_alex_{i}']={'episode':ep,'source':f'Web DialogMov(1) DlgArr[{i}], only answer {slot} enabled','kind':'activity_dialogue','original_ui':True,'art':art,'speaker':'Алекс Рейвен','text':a[0],'choices':[branch(target if j==slot else f'john1_alex_{i}',a[j],disabled=j!=slot) for j in range(1,len(a))]}
   nodes[nid(8)]['choices']=[branch('john1_alex_0',rect=[70,0,730,480])]
   nodes[nid(11)]['unfinished']=True # Original frame has no listener or transition.
  else:
   nodes[nid(3)]['choices']=[branch(pickup('laser',2,nid(4),nid(4)),rect=[70,0,730,480])]
   for fr,item,advance in [(4,2,1),(7,3,2),(10,4,1),(11,5,2)]:decision(fr,item,advance)
   # Original frame 8 stops at key 0; a click starts keys 1..8 then End advances.
   cut='john2_8_departure';nodes[cut]={'episode':ep,'source':'Web Episode2 frame 8 Mov.gotoAndPlay(2), End -> frame 9','kind':'city_cutscene','art':cut,'clean_background':True,'auto_seconds':8/19,'choices':[branch(nid(9))]}
   visuals[nid(8)]['overrides']['Mov']=0;visuals[cut]=dict(visuals[nid(8)],overrides={'Mov':8})
   nodes[nid(8)]['choices']=[branch(cut,rect=[70,0,730,480])]
   nodes[nid(7)]['sound']='AlarmLoud'
   nodes['john2_result']={'episode':ep,'source':'Web ResultBad(1), Summer(0): survived','kind':'city_ending','alive':True,'result_id':1,'text':source_array(sources['ResultBad'],'ResultArr')[0],'sound':'Ending','choices':[]}
   nodes[nid(16)]['choices']=[branch('john2_result',rect=[70,0,730,480])]
  for n in nodes.values():
   if n.get('sound'):
    old=n['sound'];name='john_'+old;n['sound']=name
    (ROOT/'assets/audio'/f'{name}.mp3').write_bytes(sounds[old+'.mp3'])
  graph=migrate(ep,nodes);graph.update(start=nid(1),title=f'Джон. {"Предыстория" if part==1 else "Побег"}',description='Web-эпизод о Джоне Доннатоне. '+('Первая часть: события на базе Терри.' if part==1 else 'Вторая часть: побег с базы Терри.'),variables={'BulletsNumber':-1},bonus=True,source_fps=19,selector_art=f'john_selector_{ep}')
  for id,n in nodes.items():
   if n['kind']=='activity_dialogue':graph['nodes'][id]['type']='dialogue'
  rows={}
  def localize(v,key):
   if isinstance(v,dict):
    out={}
    for k,x in v.items():
     if k in ['text','speaker','title','description'] and isinstance(x,str) and x:rows[key+'.'+k]=x;out[k]='@loc:'+key+'.'+k
     else:out[k]=localize(x,key+'.'+k)
    return out
   if isinstance(v,list):return [localize(x,key+'.'+str(i)) for i,x in enumerate(v)]
   return v
  graph=localize(graph,f'episode{ep}')
  (ROOT/f'data/story_graphs/episode{ep}.json').write_text(json.dumps(graph,ensure_ascii=False,indent=2)+'\n')
  (ROOT/f'data/episode{ep}_visuals.json').write_text(json.dumps(visuals,ensure_ascii=False,indent=2)+'\n')
  with (ROOT/f'locales/episode{ep}.csv').open('w',newline='') as f:
   w=csv.writer(f,lineterminator='\n');w.writerow(['key','ru','en']);w.writerows((k,v,'') for k,v in sorted(rows.items()))
  for sound in {n.get('sound') for n in nodes.values()}- {None}:
   path=ROOT/'assets/audio'/f'{sound}.mp3'
   # Shared effects keep the existing file; web-specific names preserve originals.
   if not path.exists():path.write_bytes(sounds[sound.removeprefix('john_')+'.mp3'])
  print('John part',part,':',len(nodes),'scenes',flush=True)

def selectors():
 import copy
 base=json.loads((ROOT/'data/ui_components.json').read_text())['adaptive_selector_2']
 text_path=ROOT/'data/ui_text_layout.json';texts=json.loads(text_path.read_text())
 brushes=json.loads((ROOT/'data/ui_brush_layout.json').read_text())
 for ep,scene in [(101,'john1_5'),(102,'john2_10')]:
  path=ROOT/f'data/episode{ep}_components.json';catalog=json.loads(path.read_text())
  poses=catalog.get(scene) or list(json.loads((ROOT/f'data/episode{ep}_animations.json').read_text())['art'][scene]['parts'].values())
  preview=max((p for p in poses if p['type']=='texture'),key=lambda p:p['rect'][2]*p['rect'][3])
  parts=copy.deepcopy(base)
  for p in parts:
   if p.get('source','').endswith('/EpImg'):p['texture']=preview['texture']
   p.setdefault('type','texture')
  if ep==101:
   # Original console chrome is drawn with SWF strokes. Keep it as native parts.
   lines=[[0,0,800,1],[0,479,800,1],[0,0,1,480],[799,0,1,480],[0,39,800,1],[0,443,800,1],[757,48,31,1],[757,433,31,1],[757,48,1,386],[787,48,1,386]]
   for scene_id in ['john1_1','john1_2','john1_3']:
    catalog[scene_id]=[p for p in catalog[scene_id] if p.get('source')!='JohnConsoleStroke']
    catalog[scene_id].extend({'type':'panel','rect':rect,'color':[1,1,1,1],'source':'JohnConsoleStroke','layer':'foreground'} for rect in lines)
    for points in [[[765,65],[773,57],[781,65],[780,66],[773,59],[766,66]],[[765,416],[773,424],[781,416],[780,415],[773,422],[766,415]]]:
     catalog[scene_id].append({'type':'polygon','points':points,'color':[1,1,1,1],'source':'JohnConsoleStroke','layer':'foreground'})
  catalog[f'john_selector_{ep}']=parts
  texts[f'john_selector_{ep}']=copy.deepcopy(texts['adaptive_selector_2'][:1])
  brush_path=ROOT/f'data/episode{ep}_brushes.json';rows=json.loads(brush_path.read_text());rows[f'john_selector_{ep}']=copy.deepcopy(brushes['adaptive_selector_2']);brush_path.write_text(json.dumps(rows,ensure_ascii=False,indent=2)+'\n')
  path.write_text(json.dumps(catalog,ensure_ascii=False,indent=2)+'\n')
 text_path.write_text(json.dumps(texts,ensure_ascii=False,indent=2)+'\n')
 animation_path=ROOT/'data/episode102_animations.json';tracks=json.loads(animation_path.read_text())
 for art,frame in [('john2_6',6),('john2_7',5)]:tracks['art'][art]['input_ready_frame']=frame
 animation_path.write_text(json.dumps(tracks,separators=(',',':'))+'\n')

def unify():
 """Publish both source timelines as one playable, localized bonus episode."""
 def read(path):return json.loads((ROOT/path).read_text())
 def write(path,value):
  compact=Path(path).name in ['episode101_animations.json','episode101_text_animations.json','episode101_highlights.json']
  (ROOT/path).write_text(json.dumps(value,ensure_ascii=False,**({'separators':(',',':')} if compact else {'indent':2}))+'\n')
 def remap(value):
  if isinstance(value,str):return value.replace('@loc:episode102.','@loc:episode101.')
  if isinstance(value,list):return [remap(v) for v in value]
  if isinstance(value,dict):return {k:remap(v) for k,v in value.items()}
  return value
 graph=read('data/story_graphs/episode101.json');second=remap(read('data/story_graphs/episode102.json'))
 for node in second['nodes'].values():
  if 'episode' in node.get('data',{}):node['data']['episode']=101
 graph['nodes'].update(second['nodes']);graph['edges'].extend(second['edges'])
 graph['legacy_episodes']=[102]
 graph['nodes']['john1_11']['data'].pop('unfinished',None)
 key='episode101.nodes.john1_11__choice_0.data.text'
 graph['nodes']['john1_11__choice_0']={'type':'choice','data':{'text':'@loc:'+key,'rect':[70,0,730,480]},'position':[1970,0],'title':'@loc:'+key}
 graph['edges'].extend([{'from':'john1_11','port':'choice:0','to':'john1_11__choice_0'},{'from':'john1_11__choice_0','port':'next','to':'john2_1'}])
 write('data/story_graphs/episode101.json',graph)
 rows={}
 for ep in [101,102]:
  with (ROOT/f'locales/episode{ep}.csv').open(newline='') as f:
   for row in list(csv.reader(f))[1:]:
    k=row[0].replace('episode102.','episode101.')
    if ep==102 and k in rows:continue
    rows[k]=row[1:]
 rows['episode101.title']=['ВЕБ-ЭПИЗОД 1. ДЖОН',''];rows['episode101.description']=['История Джона Доннатона: события на базе Терри и побег.',''];rows[key]=['Далее','']
 with (ROOT/'locales/episode101.csv').open('w',newline='') as f:
  w=csv.writer(f,lineterminator='\n');w.writerow(['key','ru','en']);w.writerows([k,*v] for k,v in sorted(rows.items()))
 # OptimizedTranslation cannot enumerate keys; Localization builds its fallback
 # tables by enumeration, including in Android exports without source CSV.
 (ROOT/'locales/episode101.csv.import').write_text('[remap]\n\nimporter="csv_translation"\ntype="Translation"\nuid="uid://csds3ebackt2k"\n\n[deps]\n\nfiles=["res://locales/episode101.ru.translation", "res://locales/episode101.en.translation"]\nsource_file="res://locales/episode101.csv"\ndest_files=["res://locales/episode101.ru.translation", "res://locales/episode101.en.translation"]\n\n[params]\n\ncompress=0\ndelimiter=0\nunescape_keys=false\nunescape_translations=true\n')
 for path in sorted((ROOT/'data').glob('episode102_*.json')):
  target=path.with_name(path.name.replace('episode102_','episode101_'));first=json.loads(target.read_text());second=json.loads(path.read_text())
  if path.name=='episode102_animations.json':
   for group in ['art','audit']:first[group].update(second[group])
  elif path.name.endswith('_highlights.json'):
   for group in ['regions','masks']:first[group].update(second[group])
  else:first.update(second)
  first.pop('john_selector_102',None)
  write(target.relative_to(ROOT),first);path.unlink()
 texts=read('data/ui_text_layout.json');texts.pop('john_selector_102',None);write('data/ui_text_layout.json',texts)
 for name in ['data/story_graphs/episode102.json','locales/episode102.csv','locales/episode102.csv.import','locales/episode102.ru.translation','locales/episode102.en.translation']:
  (ROOT/name).unlink(missing_ok=True)

if __name__=='__main__':
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('archive',type=Path);p.add_argument('--ffdec',type=Path,required=True);a=p.parse_args()
 with tempfile.TemporaryDirectory() as td:
  temp=Path(td);archive,sources,sounds=prepare(a.archive,a.ffdec,temp);lib=temp/'LIBRARY';lib.mkdir()
  with zipfile.ZipFile(archive) as z:
   for n in z.namelist():
    if '/LIBRARY/' in n:(lib/Path(n).name).write_bytes(z.read(n))
  content(lib,sources,sounds)
  from build_episode4_components import build as components
  from build_episode23_animations import build as animations
  for ep in [101,102]:components(archive,ROOT,episode=ep)
  animations(archive,episodes=(101,102))
  selectors()
  unify()
