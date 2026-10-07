"""Recover Episode IV routes and native captions from the original XFL/AS.
Usage: python tools/build_episode4_content.py ORIGINAL.zip [--force]
No baked screens are generated: component/animation exporters consume visuals.
"""
import argparse,copy,csv,json,re,tempfile,zipfile
from pathlib import Path
from build_episode1_art import BackgroundRenderer
from build_episode2_content import active_elements,max_frame,text_blocks
from migrate_story_graph import migrate
from render_flash_ui import NS
ROOT=Path(__file__).resolve().parents[1]
CLASSES={'church':('Episode4p0',1512,18,2),'camp':('Episode4p1',1428,14,2),'army':('Episode4p2',1350,2,1),'alone':('GoingAlone',1340,17,5),'jeep':('JeepGroup',1229,17,3),'jess':('AfterJess',1546,7,3),'harlem':('ToHarlem',1108,9,3),'exp':('ToExp',1126,4,1)}
def nid(cls,fr,v=1):return f'e4_{cls}_{fr}_v{v}'
def result(n):return f'e4_result_{n}'
def choice(target,**kw):return {'text':'Далее','next':target,'rect':[70,0,730,480],**kw}
def source_array(source,name):
 # Source constructors are either Vector.<String>[...] or Array(...).
 if name=='ResultArr':
  raw=re.search(r'this.ResultArr = new <String>\[(.*?)\];',source,re.S)[1]
  raw=re.sub(r'"(?:[^"\\]|\\.)*"\s*\+\s*Math\s*\.round\(.*?\)\s*\+\s*"(?:[^"\\]|\\.)*"','"TEST"',raw,flags=re.S)
 elif name=='itemStrings':raw=re.search(r'this.itemStrings = new <String>\[(.*?)\];',source,re.S)[1]
 else:raw=re.search(r'this.'+name+r' = new Array\((.*?)\);',source,re.S)[1]
 return json.loads('['+raw+']')
def build(lib,photos,sounds,sources,output):
 r=BackgroundRenderer(lib,output/'assets/flash_ui',output/'fonts/flash');r.photos=photos;r.retain_text=False
 r.omit_root_shapes=False;r.omit_symbols=set()
 nodes={};visuals={};movie_names={}
 def visual(key,symbol,fr,ov,photo='',photo_path='Mov.Mov',hide=None,offset_y=0):
  visuals[key]={'symbol':symbol,'frame':fr,'overrides':ov,'photo':photo,'photo_path':photo_path,'hide':sorted(hide or []),'offset_y':offset_y,'omit_symbols':['Symbol 539']}
 for cls,(name,sym,last,variants) in CLASSES.items():
  for v in range(1,variants+1):
   for fr in range(1,last+1):
    id=nid(cls,fr,v);symbol=f'Symbol {sym}';ov={};photo='';photo_path='Mov.Mov';sound=''
    for e in active_elements(r,symbol,fr-1):
     if e.get('name')=='Mov':movie_names[id]=e.get('libraryItemName');ov['Mov']=max_frame(r,movie_names[id])
    script='\n'.join(f.findtext('x:Actionscript/x:script','',NS) for f in r.root(symbol).findall('./x:timeline/x:DOMTimeline/x:layers/x:DOMLayer/x:frames/x:DOMFrame',NS) if int(f.get('index','0'))==fr-1)
    m=re.search(r'LoadImage\("([^"]+)",this\.(Mov(?:\.Mov)?)',script)
    if m:photo,photo_path=m.groups()
    m=re.search(r'SndPlayer\("([^"]+)"',script)
    if m:sound=m[1]
    hist=None
    if cls=='camp' and fr==13:hist=v
    if cls=='church' and fr in [5,6,8]:hist=v
    if cls=='jeep' and fr in [1,2,11,14]:hist=v
    if cls=='alone':
     if fr==1:hist=v
     elif fr==4:hist=v%4
     elif fr==9:hist=v-1
     elif fr==12:hist=v-2
     elif fr==17 and v==5:hist=2
    if cls=='jess' and fr in [2,3]:hist=v-1
    if cls=='harlem' and fr==5:hist=v
    if hist is not None:ov['Mov.Hist']=max(0,hist-1)
    # OnMovLoad supplies this photograph rather than a root frame script.
    if cls=='jess' and fr==1:photo='ToHotelStairs.png'
    blocks=text_blocks(r,symbol,fr-1,ov)
    node={'episode':4,'source':f'{name} frame {fr}; type {v}','kind':'city_story','art':id,'clean_background':True,'blocks':blocks,'text':' '.join(b['text'] for b in blocks),'choices':[choice(nid(cls,fr+1,v))]}
    if sound:node['sound']=sound
    if 'addEventListener("End"' in script:node['input_after_intro']=True
    if (cls=='camp' and fr==14) or (cls=='exp' and fr==4):node['pause_allowed']=False
    nodes[id]=node;visual(id,sym,fr-1,ov,photo,photo_path,{'Hist','MvMg','NumB',*[f'But{i}' for i in range(1,9)]})
 def edges(id,targets):nodes[id]['choices']=[choice(t) if isinstance(t,str) else t for t in targets]
 def goto(cls,fr,v,targets):edges(nid(cls,fr,v),targets)
 questions=source_array(sources['NewItem'],'itemStrings');labels={}
 for m in re.finditer(r'this.but([1-4])Str\[([\d.]+)\](?:\s*=\s*this.but[1-4]Str\[[\d.]+\])?\s*=\s*"([^"]*)"',sources['NewItem']):labels[(float(m[2]),int(m[1]))]=m[3]
 def decision(cls,fr,v,item,targets):
  back=nid(cls,fr,v);id=back+f'_choice_{item}'
  nodes[id]={'episode':4,'source':f'NewItem({item})','kind':'city_decision','art':back,'clean_background':True,'text':questions[item-1],'back':back,'choices':[]}
  for i,t in enumerate(targets,1):
   c=choice(t) if isinstance(t,str) else copy.deepcopy(t);c['text']=labels[(float(item),i)];c.pop('rect',None);nodes[id]['choices'].append(c)
  goto(cls,fr,v,[id]);return id
 def interactive(cls,fr,v,targets):
  id=nid(cls,fr,v);node=nodes[id];controls=id+'_controls'
  visual(controls,CLASSES[cls][1],fr-1,{f'But{i}':4 for i in range(1,9)},hide={'Mov'});visuals[controls]['omit_root_shapes']=True
  node['controls_art']=controls
  edges(id,[choice(target,text=label,source_button=button) for button,label,target in targets])
 results=source_array(sources['ResultBad'],'ResultArr')
 # 113/135 are also reachable through the original GoingAlone But4 formula.
 for n in [*range(79,100),*range(101,114),135]:
  alive=n in [96,98,112]
  nodes[result(n)]={'episode':4,'source':f'ResultBad({n})','kind':'city_ending' if alive else 'city_death','alive':alive,'result_id':n,'text':results[n-1],'choices':[]}
 def pickup(key,weapon,next_node,background):
  art='e4_item_'+key;visual(art,274,0,{'Weapons':weapon,'ButExit':1},hide={'Txt'},offset_y=30)
  names=source_array(sources['AddItem'],'weapStrings')
  sounds_by={3:'TakeMK23',4:'TakeKnife',7:'TakeRemington',8:'WeaponAim',9:'TakeKnife',10:'DesertTake'}
  node={'episode':4,'source':f'AddItem({weapon})','kind':'city_pickup','art':art,'background_art':background,'text':names[weapon-1],'sound':sounds_by[weapon],'choices':[choice(next_node,text='Забрать')]}
  if weapon in [4,9]:node['set']={'TakenKnife':True}
  elif weapon in [3,10]:node['set']={'BulletsNumber':12 if weapon==3 else 10}
  nodes['e4_pickup_'+key]=node;return 'e4_pickup_'+key
 # Three entry branches selected from the previous episode's active ending.
 goto('army',2,1,[nid('camp',1)])
 for v in (1,2):
  decision('camp',3,v,31,[nid('camp',4,v),nid('camp',5,v),nid('camp',10,v)])
  decision('camp',4,v,32,[nid('camp',14,v),nid('camp',7,v),nid('camp',8,v)])
  goto('camp',6,v,[result(79)]);goto('camp',7,v,[nid('camp',13,v)])
  goto('camp',9,v,[nid('jeep',1,1)])
  interactive('camp',10,v,[('But1','Взять гранату',pickup('flashbang',8,nid('camp',11,v),nid('camp',11,v))),('But2','Взять дробовик',pickup('remington',7,nid('camp',12,v),nid('camp',12,v)))])
  goto('camp',11,v,[nid('camp',13,2)]);goto('camp',12,v,[result(80)])
  goto('camp',13,v,[nid('alone',1,v)]);goto('camp',14,v,[result(81)])
 for v in (1,2):
  decision('church',2,v,39,[nid('church',5,v),nid('church',3,v)])
  goto('church',3,v,[nid('church',4,2)])
  decision('church',4,v,40,[nid('church',5,v),nid('church',10,v)])
  goto('church',6,v,[result(103) if v==2 else nid('church',7,v)])
  decision('church',7,v,41,[nid('church',8,2),nid('church',8,v)])
  goto('church',8,v,[result(104) if v==2 else nid('church',9,v)])
  goto('church',9,v,[nid('jeep',1,2)])
  decision('church',11,v,43,[nid('church',12,v),nid('church',14,v),nid('church',13,v)])
  goto('church',12,v,[result(110)]);goto('church',13,v,[result(111)])
  decision('church',16,v,44,[nid('church',17,v),nid('alone',4,5)])
  goto('church',18,v,[nid('alone',9,4)])
 for v in (1,2,3):
  second=nid('jeep',6,v) if v==1 else nid('jeep',11,3)
  interactive('jeep',3,v,[('But1','К реке',nid('jeep',4,v)),('But2','К лагерю',second),('But3','К отелю',nid('jeep',11,v))])
  goto('jeep',5,v,[result(82)])
  decision('jeep',7,v,33,[nid('jeep',9,v),nid('jeep',8,v)])
  goto('jeep',8,v,[nid('jeep',10,v)]);goto('jeep',9,v,[result(83)])
  goto('jeep',10,v,[nid('jeep',16,v)])
  goto('jeep',11,v,[pickup('knife',9,nid('jeep',12,v),nid('jeep',12,v)) if v==1 else nid('jeep',12,v)])
  if v!=3:decision('jeep',12,v,34,[nid('jeep',13,v),nid('jeep',14,v)])
  else:goto('jeep',12,v,[nid('jeep',14,v)])
  goto('jeep',13,v,['e4_dialogue_jess_0']);goto('jeep',15,v,[result(84)]);goto('jeep',17,v,['e4_dialogue_victor_0'])
 for v in range(1,6):
  interactive('alone',1,v,[('But1','По дороге',result(92) if v==1 else nid('alone',4,v)),('But2','В лес',nid('alone',2,v) if v==2 else nid('alone',3,v))])
  goto('alone',2,v,['e4_dialogue_matt_0']);goto('alone',3,v,[result(85)])
  if v==5:goto('alone',4,v,[nid('alone',17,v)])
  else:decision('alone',4,v,35,[nid('alone',17,v),nid('alone',5,v)])
  interactive('alone',5,v,[('But3','К реке',nid('alone',6,v) if v==3 else result(93)),('But4','В лес',result(157-v*22))])
  decision('alone',8,v,36,[nid('alone',10,1),nid('alone',9,2),nid('alone',9,3)])
  goto('alone',9,v,[nid('alone',16,v) if v==2 else nid('alone',11,v)])
  goto('alone',10,v,[result(94)])
  interactive('alone',11,v,[('But5','К пристани',nid('alone',12,v)),('But6','К пристани',nid('alone',12,v)),('But7','К пристани',nid('alone',12,v)),('But8','По трассе',result(95))])
  goto('alone',15,v,[result(96)]);goto('alone',16,v,[result(97)]);goto('alone',17,v,[result(109)])
 for v in (1,2,3):
  decision('jess',1,v,42,[nid('jess',2,3),nid('jess',5,v)])
  goto('jess',3,v,[choice(result(105),next_cases=[{'when':{'TakenKnife':True},'next':result(106)}])] if v==3 else [nid('jess',4,v)])
  goto('jess',4,v,[choice(result(107),next_cases=[{'when':{'TakenKnife':True},'next':result(84)}])])
  goto('jess',6,v,[choice(nid('jess',7,v),next_cases=[{'when':{'TakenKnife':True},'next':result(108)}])])
  goto('jess',7,v,[nid('exp',1)])
 for v in (1,2,3):
  decision('harlem',2,v,37,[nid('harlem',3,v),nid('harlem',6,v)])
  goto('harlem',4,v,[nid('harlem',5,1)]);goto('harlem',5,v,[result(98)])
  decision('harlem',6,v,38,[nid('harlem',8,v),nid('harlem',7,v)])
  goto('harlem',7,v,[result(99+v) if v>1 else nid('harlem',9,v)])
  goto('harlem',8,v,[result(99)]);goto('harlem',9,v,[nid('harlem',5,2)])
 goto('exp',4,1,[result(112)])
 terminal={
  'jess':{**{i:nid('jess',2,3) for i in [61,88]},**{i:nid('jess',2,2) for i in [16,31,34,43,52,58,67,70,79,85,112,115,178,220,223,232,259]},**{i:nid('jess',1) for i in [40,49,97,106,133,160,175,205,214,229,256,538,700,781]}},
  'matt':{**{i:pickup('deagle',10,nid('alone',4,3),nid('alone',4,3)) for i in [6,9,11,18,26,32,41,44,53,76,121,157]},7:result(86),16:result(86),31:result(87),43:result(88),122:result(90),77:result(89),158:result(89)},
  'victor':{**{i:nid('harlem',1) for i in [4,16,23,25,27,79,205]},**{i:pickup('army_knife',4,nid('harlem',1,2),nid('harlem',1,2)) for i in [17,69,80,206]},**{i:pickup('mark23',3,nid('harlem',1,3),nid('harlem',1,3)) for i in [202,203]}}
 }
 for key,frame in [('jess',2),('matt',3),('victor',4)]:
  script='\n'.join(f.findtext('x:Actionscript/x:script','',NS) for f in r.root('Symbol 237').findall('.//x:DOMFrame',NS) if int(f.get('index',0))==frame)
  arrays={}
  for m in re.finditer(r'((?:this\.DlgArr\[\d+\]\s*=\s*)+)(\[.*?\]|this\.DlgArr\[\d+\]);',script,re.S):
   value=copy.deepcopy(arrays[int(re.search(r'\d+',m[2])[0])]) if m[2].startswith('this.') else json.loads(m[2])
   for index in re.findall(r'DlgArr\[(\d+)\]',m[1]):arrays[int(index)]=value
  speaker=re.search(r'this.PrsnTxt.text = "([^"]+)"',script)[1]
  art='e4_dialogue_'+key;visual(art,237,frame,{'Ava':frame,'Dlg1':0,'Dlg2':0,'Dlg3':0},hide={'Txt','PrsnTxt','DlgTxt'})
  for n,arr in arrays.items():
   answers=[]
   for i,text in enumerate(arr[1:],1):
    next_index=n*3+i;target=terminal[key].get(next_index,'e4_dialogue_'+key+'_'+str(next_index))
    if next_index not in terminal[key] and next_index not in arrays:raise ValueError(f'Missing {key} dialogue {next_index}')
    answers.append({'text':text,'next':target})
   nodes[f'e4_dialogue_{key}_{n}']={'episode':4,'source':f'DialogMov({frame}) DlgArr[{n}]','kind':'activity_dialogue','speaker':speaker,'text':arr[0],'art':art,'original_ui':True,'choices':answers}
 starts=[nid('church',1),nid('camp',1),nid('army',1)]
 seen=set();todo=starts[:]
 while todo:
  id=todo.pop()
  if id in seen:continue
  if id not in nodes:raise ValueError('Missing reachable scene: '+id)
  seen.add(id);n=nodes[id]
  todo.extend(c['next'] for c in n['choices']);todo.extend(case['next'] for c in n['choices'] for case in c.get('next_cases',[]))
  if n.get('back'):todo.append(n['back'])
 nodes={k:v for k,v in nodes.items() if k in seen}
 # Lock transitions into terminal deaths as well as authored unpausable clips.
 for n in nodes.values():
  for c in n['choices']:
   if nodes[c['next']]['kind']=='city_death' and not c.get('next_cases'):c['pause_allowed']=False
 graph=migrate(4,nodes);graph['start']=nid('camp',1);graph['title']='IV. Исход';graph['description']='Его не сломать, Джек зубами будет выгрызать себе право жить. Выход близко, но хватит ли сил добраться?'
 graph['continuations']={'64':nid('church',1),'68':nid('camp',1),'67':nid('army',1)}
 graph['variables']={'TakenKnife':False,'BulletsNumber':-1}
 for id,n in nodes.items():
  if n['kind'].startswith('activity_'):graph['nodes'][id]['type']=n['kind'].removeprefix('activity_')
  graph['nodes'][id]['title']=n['source']
 # Localize every player-facing graph string without rewriting earlier tables.
 rows={}
 def localize(value,prefix):
  if isinstance(value,dict):return {k:marker(v,prefix+'.'+k) if k in ['text','speaker','title','description'] and isinstance(v,str) and v else localize(v,prefix+'.'+k) for k,v in value.items()}
  if isinstance(value,list):return [localize(v,prefix+'.'+str(i)) for i,v in enumerate(value)]
  return value
 def marker(value,key):rows[key]=value;return '@loc:'+key
 graph=localize(graph,'episode4')
 table=output/'locales/episode4.csv'
 if table.exists():
  with table.open(newline='',encoding='utf-8-sig') as f:old={r['key']:r for r in csv.DictReader(f)}
 else:old={}
 with table.open('w',newline='',encoding='utf-8') as f:
  w=csv.writer(f,lineterminator='\n');w.writerow(['key','ru','en']);w.writerows((k,v,old.get(k,{}).get('en','')) for k,v in sorted(rows.items()))
 import_path=Path(str(table)+'.import')
 if not import_path.exists():import_path.write_text('[remap]\nimporter="csv_translation"\ntype="Translation"\n[deps]\nfiles=["res://locales/episode4.ru.translation", "res://locales/episode4.en.translation"]\nsource_file="res://locales/episode4.csv"\ndest_files=["res://locales/episode4.ru.translation", "res://locales/episode4.en.translation"]\n[params]\ncompress=0\ndelimiter=0\nunescape_keys=false\nunescape_translations=false\n')
 (output/'data/story_graphs/episode4.json').write_text(json.dumps(graph,ensure_ascii=False,indent=2)+'\n')
 live={n[k] for n in nodes.values() for k in ['art','background_art','controls_art'] if k in n}
 (output/'data/episode4_visuals.json').write_text(json.dumps({k:v for k,v in visuals.items() if k in live},ensure_ascii=False,indent=2)+'\n')
 for sound in {n.get('sound','') for n in nodes.values()}:
  if sound and not (output/'assets/audio'/(sound+'.mp3')).exists():(output/'assets/audio'/(sound+'.mp3')).write_bytes((sounds/(sound+'.mp3')).read_bytes())
 print('Episode IV:',len(nodes),'screens;',len(graph['nodes']),'graph blocks;',len(rows),'localized strings;',sum(n['kind']=='activity_dialogue' for n in nodes.values()),'dialogue states',flush=True)
 return nodes

def main():
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('archive',type=Path);p.add_argument('--output',type=Path,default=ROOT);p.add_argument('--force',action='store_true');a=p.parse_args()
 if (a.output/'data/story_graphs/episode4.json').exists() and not a.force:raise SystemExit('Graph exists; --force discards authored edits')
 with tempfile.TemporaryDirectory() as td:
  temp=Path(td);lib=temp/'LIBRARY';photos=temp/'Images';sounds=temp/'Sound'
  for d in (lib,photos,sounds):d.mkdir()
  sources={}
  with zipfile.ZipFile(a.archive) as z:
   for n in z.namelist():
    if '/ZombieApocalypse/LIBRARY/' in n and n.endswith(('.xml','.png','.jpg')):(lib/Path(n).name).write_bytes(z.read(n))
    elif n.startswith('assets/Images/') and not n.endswith('/'):(photos/Path(n).name).write_bytes(z.read(n))
    elif n.startswith('assets/Sound/') and n.endswith('.mp3'):(sounds/Path(n).name).write_bytes(z.read(n))
    elif n.endswith('.as'):sources[Path(n).stem]=z.read(n).decode('utf-8-sig')
  build(lib,photos,sounds,sources,a.output)
if __name__=='__main__':main()
