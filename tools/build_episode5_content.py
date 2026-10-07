"""Recover Episode V, its conditional dialogue and native activity definitions.
Usage: python tools/build_episode5_content.py ORIGINAL.zip [--force]
"""
import argparse,copy,csv,json,re,tempfile,zipfile
from pathlib import Path
from build_episode1_art import BackgroundRenderer
from build_episode2_content import active_elements,max_frame,text_blocks
from build_episode4_content import source_array
from migrate_story_graph import migrate
from render_flash_ui import NS
from build_localized_ui import matrix
ROOT=Path(__file__).resolve().parents[1]
CLASSES={'plane':('Episode5',1031,23,4),'upper':('UpperDeck',804,14,8),'hide':('HideInTheEnd',907,10,3),'rest':('RestArea',834,5,4),'sector':('InsideTheSector',855,4,2),'under':('EndsUnder',1058,5,2)}
def nid(cls,fr,v=1):return f'e5_{cls}_{fr}_v{v}'
def result(n):return f'e5_result_{n}'
def branch(target,**kw):return {'text':'Далее','next':target,'rect':[70,0,730,480],**kw}
def build(lib,photos,sounds,sources,output):
 r=BackgroundRenderer(lib,output/'assets/flash_ui',output/'fonts/flash');r.photos=photos;r.retain_text=False;r.omit_root_shapes=False;r.omit_symbols=set()
 nodes={};visuals={};movies={}
 def visual(key,symbol,fr,ov,photo='',hide=None):
  visuals[key]={'symbol':symbol,'frame':fr,'overrides':ov,'photo':photo,'photo_path':'Mov.Mov','hide':sorted(hide or []),'omit_symbols':['Symbol 539','Symbol 379']}
 for cls,(name,sym,last,variants) in CLASSES.items():
  for v in range(1,variants+1):
   for fr in range(1,last+1):
    id=nid(cls,fr,v);symbol=f'Symbol {sym}';ov={};photo='';sound='';hist=None
    for e in active_elements(r,symbol,fr-1):
     if e.get('name')=='Mov':movies[id]=e.get('libraryItemName');ov['Mov']=max_frame(r,movies[id])
    script='\n'.join(f.findtext('x:Actionscript/x:script','',NS) for f in r.root(symbol).findall('./x:timeline/x:DOMTimeline/x:layers/x:DOMLayer/x:frames/x:DOMFrame',NS) if int(f.get('index',0))==fr-1)
    m=re.search(r'LoadImage\("([^"]+)"',script)
    if m:photo=m[1]
    m=re.search(r'SndPlayer\("([^"]+)"',script)
    if m:sound=m[1]
    if cls=='plane':
     if fr in [5,8,12]:hist=v-1
     elif fr in [9,16]:hist=v//2
    elif cls=='upper':
     if fr in [2,5]:hist=v-1
     elif fr in [3,4]:hist=max(0,v-2)
     elif fr==6:hist=max(0,7-v)
     elif fr==9:hist=0 if v==7 else 1
    elif cls=='hide' and fr==1:hist=v//3
    elif cls=='under' and fr==2:hist=v-1
    if hist is not None:ov['Mov.Hist']=hist
    if cls=='sector' and fr in [1,2]:photo='VnizuVluke.png' if fr==1 else 'SvetVOtseke.jpg';sound='AliceFallInside'
    if cls=='under' and fr==1:photo='OborachivayushiysaZombi.jpg';sound='ZombieRoar2'
    if cls=='rest' and fr in [1,3]:sound='DoorKicksHide'
    if cls=='upper' and fr==1:sound='AliceMetalHit'
    blocks=text_blocks(r,symbol,fr-1,ov)
    node={'episode':5,'source':f'{name} frame {fr}; type {v}','kind':'city_story','art':id,'clean_background':True,'blocks':blocks,'text':' '.join(b['text'] for b in blocks),'choices':[branch(nid(cls,fr+1,v))]}
    if sound:node['sound']=sound
    if 'addEventListener("End"' in script or (cls=='upper' and fr==1) or (cls=='sector' and fr in [1,2]):node['input_after_intro']=True
    nodes[id]=node;visual(id,sym,fr-1,ov,photo,{'Hist','MvMg','Fing','Tap','But',*[f'But{i}' for i in range(1,5)],*[f'ButL{i}' for i in range(12)]})
 def edges(cls,fr,v,targets):nodes[nid(cls,fr,v)]['choices']=[branch(t) if isinstance(t,str) else t for t in targets]
 questions=source_array(sources['NewItem'],'itemStrings');labels={}
 for m in re.finditer(r'this.but([1-4])Str\[([\d.]+)\](?:\s*=\s*this.but[1-4]Str\[[\d.]+\])?\s*=\s*"([^"]*)"',sources['NewItem']):labels[(float(m[2]),int(m[1]))]=m[3]
 labels[(56.1,1)]=labels[(56.,1)];labels[(56.1,2)]=labels[(56.,2)]
 labels[(55.,2)]='Постучаться к пилоту'
 def decision(cls,fr,v,item,targets):
  back=nid(cls,fr,v);id=back+f'_choice_{str(item).replace(".","_")}';choices=[]
  for i,t in enumerate(targets,1):
   c=branch(t) if isinstance(t,str) else copy.deepcopy(t);c['text']=labels[(float(item),i)];c.pop('rect',None);choices.append(c)
  nodes[id]={'episode':5,'source':f'NewItem({item})','kind':'city_decision','art':back,'clean_background':True,'text':questions[int(item)-1],'back':back,'choices':choices}
  edges(cls,fr,v,[id]);return id
 results=source_array(sources['ResultBad'],'ResultArr')
 for n in range(114,137):
  nodes[result(n)]={'episode':5,'source':f'ResultBad({n})','kind':'city_ending' if n in [124,130,133,136] else 'city_death','alive':n in [124,130,133,136],'result_id':n,'text':results[n-1],'choices':[]}
  if n==136:nodes[result(n)]['ending_id']=133
 def pickup(key,weapon,next_node,background):
  art='e5_item_'+key;visual(art,274,0,{'Weapons':weapon,'ButExit':1},hide={'Txt'});visuals[art]['offset_y']=30
  nodes['e5_pickup_'+key]={'episode':5,'source':f'AddItem({weapon})','kind':'city_pickup','art':art,'background_art':background,'text':source_array(sources['AddItem'],'weapStrings')[weapon-1],'sound':{11:'DocumentsTake',12:'BulletproofVest',13:'Sig250Take'}[weapon],'choices':[branch(next_node,text='Забрать')]}
  if weapon in [11,12]:nodes['e5_pickup_'+key]['set']={'TakenDocs' if weapon==11 else 'TakenArmor':True}
  return 'e5_pickup_'+key
 def qte(cls,fr,v,success,failure,**data):
  data.setdefault('taps',data.get('taps_range',[10])[0]);node=nodes[nid(cls,fr,v)];node.update(kind='activity_qte',original_ui=True,**data);node.pop('input_after_intro',None);node['choices']=[branch(success,text='Успеть'),branch(failure,text='Не успеть')]
  if node.get('native_prompt'):
   frames=r.root('Symbol 28').findall('./x:timeline/x:DOMTimeline/x:layers/x:DOMLayer/x:frames/x:DOMFrame',NS)
   offsets={int(f.get('index')):list(matrix(f.find('x:elements/x:DOMSymbolInstance',NS))[4:]) for f in frames if f.find('x:elements/x:DOMSymbolInstance',NS) is not None}
   node['prompt_offsets']=[offsets[i] for i in range(13)]
  node['blocks']=[];node['text']='';node['meter_mode']='remaining_taps';visuals[node['art']]['activity_qte']=True;visuals[node['art']]['activity_frames']=round(data['seconds']*19)
 for v in range(1,5):
  decision('plane',4,v,45,[nid('plane',5,1),nid('plane',5,2)])
  edges('plane',5,v,[nid('plane',5+v,v)] if v in [1,2] else [result(114)])
  decision('plane',6,v,47,[nid('plane',18,v),nid('plane',9,v)])
  decision('plane',7,v,46,[nid('plane',8,v),nid('plane',17,v)])
  edges('plane',8,v,[nid('plane',9,min(v+1,4))])
  decision('plane',9,v,48+v//2,[nid('plane',12,v) if v==1 else nid('plane',10,v),nid('plane',16,v)])
  edges('plane',11,v,[result(114)])
  decision('plane',12,v,50,[nid('plane',14,v),nid('plane',13,v)])
  edges('plane',13,v,[nid('upper',1)])
  qte('plane',15,v,nid('sector',min(v,2)),result(115),qte_mode='ratchet',seconds=60/19,taps=3,ratchet_start=14,ratchet_step=5,ratchet_finish=4,ratchet_variable='lock',target_rect=[70,0,730,480],meter_rect=[70,4,660,40])
  visuals[nid('plane',15,v)]['overrides']['Lock']=14;visuals[nid('plane',15,v)]['control_tracks']={'lock':{'path':'Lock','frames':15}}
  edges('plane',16,v,[result(116) if v==1 else nid('hide',1,v-1)])
  edges('plane',17,v,[nid('plane',8)])
  qte('plane',20,v,nid('plane',21,v),nid('plane',23,v),seconds=39/19,taps=2,target_cycles=3,cycle_seconds=13/19,target_areas=[[46,225,155,127],[467,179,144,177]],target_size=[112,112],native_prompt=True,meter_rect=[1,20,75,45])
  edges('plane',22,v,[nid('plane',12,2)]);edges('plane',23,v,[nid('plane',16,4)])
 for v in range(1,9):
  id=nid('upper',1,v);controls=id+'_controls';visual(controls,804,0,{'But1':4,'But2':4},hide={'Mov'});visuals[controls]['omit_root_shapes']=True
  nodes[id]['controls_art']=controls;nodes[id]['choices']=[branch(pickup('documents',11,nid('upper',3,2),nid('upper',3,2)),text='Взять документы',source_button='But1'),branch(nid('upper',2,v),text='Осмотреть палубу',source_button='But2')]
  edges('upper',2,v,[result(122) if v==3 else nid('upper',5,v)])
  if v==3:edges('upper',3,v,[nid('upper',4,v)])
  else:decision('upper',3,v,51,[nid('upper',2,2),nid('upper',4,2)])
  edges('upper',4,v,[pickup('armor',12,nid('upper',9,v),nid('upper',9,v)) if v==3 else result(117)])
  edges('upper',5,v,['e5_dialogue_lex_0']);edges('upper',6,v,[nid('upper',10,v)])
  decision('upper',7,v,53,[nid('upper',6,v),result(119)])
  decision('upper',9,v,54,[nid('under',2,2),nid('under',1)])
  id=decision('upper',10,v,55,[result(121),branch(nid('upper',2,3),next_cases=[{'when':{'CabinCodeKnown':True},'next':nid('upper',12)}]),nid('upper',11,v)])
  true_choices=copy.deepcopy(nodes[id]['choices']);true_choices[1]['text']='Использовать код';nodes[id]['variants']=[{'when':{'CabinCodeKnown':True},'choices':true_choices}]
  edges('upper',11,v,[result(120)]);edges('upper',14,v,[result(124)])
 # Exact keypad positions are filled from the button HIT state by the component exporter.
 code=nodes[nid('upper',12)];code.update(kind='activity_code',original_ui=True,code_variable='PilotCode',attempts=3,keypad=True,labels_in_art=True,feedback_seconds=16/19,indicator_variable='light',choices=[branch(nid('upper',13)),branch(result(123))],blocks=[],text='');code.pop('input_after_intro',None)
 visuals[nid('upper',12)]['control_tracks']={'light':{'path':'Light','frames':33}};visuals[nid('upper',12)]['omit_symbols'].append('Symbol 792')
 for v in [1,2,3]:
  decision('hide',1,v,52,[nid('hide',2,v),result(126)])
  qte('hide',3,v,nid('rest',1,1+v//2),nid('hide',4,v),seconds=21/19,taps_range=[2,5],target_rect=[180,120,300,300],meter_rect=[690,20,90,45])
  if v==3:decision('hide',4,v,56.1,[nid('hide',9,v),nid('hide',8,v)])
  else:decision('hide',4,v,56,[nid('hide',9,v),nid('hide',8,v),nid('hide',5,v)])
  qte('hide',6,v,nid('hide',7,v),result(127),seconds=52/19,taps=3,target_cycles=4,cycle_seconds=13/19,target_areas=[[177,9,314,304]],target_size=[112,112],native_prompt=True,meter_rect=[690,20,90,45])
  edges('hide',7,v,[nid('hide',10,v)]);edges('hide',8,v,[nid('rest',3,3+v//2)]);edges('hide',9,v,[result(128)]);edges('hide',10,v,[result(135)])
 for v in range(1,5):
  edges('rest',3,v,[nid('rest',4,v) if v==1 else result(125+v%2*4)]);edges('rest',5,v,[result(130)])
 for v in [1,2]:
  edges('sector',1,v,[result(131)]);edges('sector',3,v,[pickup('sig',13,nid('sector',4,v),nid('sector',4,v))]);edges('sector',4,v,[result(136)])
  edges('under',2,v,[nid('under',2*v+1,v)])
  node=nodes[nid('under',4,v)];node.update(kind='city_cutscene',pause_allowed=False,auto_seconds=0.3,choices=[branch(result(132),next_cases=[{'when':{'TakenArmor':True},'next':result(133)}])]);node.pop('input_after_intro',None)
  edges('under',5,v,[result(134)])
 # Lex: preserve source array aliases, random password, document-specific answers.
 script='\n'.join(f.findtext('x:Actionscript/x:script','',NS) for f in r.root('Symbol 237').findall('.//x:DOMFrame',NS) if int(f.get('index',0))==5)
 arrays={};doc_answers={}
 def expression(raw):
  raw=re.sub(r'"((?:[^"\\]|\\.)*)"\s*\+\s*this\.randKey\.split\(""\)\.join\("-"\)\s*\+\s*"((?:[^"\\]|\\.)*)"',lambda m:json.dumps(json.loads('"'+m[1]+'"').removesuffix('*')+'{PilotCodeSpaced}'+json.loads('"'+m[2]+'"').removeprefix('#'),ensure_ascii=False),raw)
  raw=re.sub(r'"((?:[^"\\]|\\.)*)"\s*\+\s*this\.randKey\s*\+\s*"((?:[^"\\]|\\.)*)"',lambda m:json.dumps(json.loads('"'+m[1]+'"').removesuffix('*')+'{PilotCode}'+json.loads('"'+m[2]+'"').removeprefix('#'),ensure_ascii=False),raw)
  m=re.search(r'this.Main.TakenDocs\s*\?\s*("(?:[^"\\]|\\.)*")\s*:\s*("(?:[^"\\]|\\.)*")',raw)
  docs=json.loads(m[1]) if m else None
  if m:raw=raw[:m.start()]+m[2]+raw[m.end():]
  return json.loads(raw),docs
 for m in re.finditer(r'((?:this\.DlgArr\[\d+\]\s*=\s*)+)(\[.*?\]|this\.DlgArr\[\d+\]);',script,re.S):
  if m[2].startswith('this.'):
   old=int(re.search(r'\d+',m[2])[0]);arr=copy.deepcopy(arrays[old]);docs=doc_answers.get(old)
  else:arr,docs=expression(m[2])
  for index in re.findall(r'DlgArr\[(\d+)\]',m[1]):arrays[int(index)]=arr;doc_answers[int(index)]=docs
 terminals={11:result(118)}
 for i in [13,22,154,160,163,167,170,239,244,295,298,302,305,727,730,880,889]:terminals[i]=nid('upper',7,7)
 for i in [14,23,52,77,94,97,166,169,229,230,238,241,301,304]:terminals[i]=nid('upper',6,6)
 for i in [46,95]:terminals[i]=nid('upper',8,8)
 for i in [148,151]:terminals[i]=branch(nid('upper',6,6),set={'CabinCodeKnown':True})
 art='e5_dialogue_lex';visual(art,237,5,{'Ava':5,'Dlg1':0,'Dlg2':0,'Dlg3':0},hide={'Txt','PrsnTxt','DlgTxt'})
 for n,arr in arrays.items():
  answers=[]
  for i,text in enumerate(arr[1:],1):
   dest=n*3+i;target=terminals.get(dest,'e5_dialogue_lex_'+str(dest));c=branch(target) if isinstance(target,str) else copy.deepcopy(target);c['text']=text;c.pop('rect',None)
   if dest in [18,33,81,96]:c['next_cases']=[{'when':{'TakenDocs':True},'next':nid('upper',3,3)}]
   if dest not in terminals and dest not in arrays:raise ValueError(f'Missing Lex dialogue {dest}')
   answers.append(c)
  if n==31:answers.append(branch(nid('upper',3,3),text='Подождите, Лекс! Я нашла какие-то документы здесь, в них все есть!',requires={'TakenDocs':True}))
  id=f'e5_dialogue_lex_{n}';nodes[id]={'episode':5,'source':f'DialogMov(5) DlgArr[{n}]','kind':'activity_dialogue','speaker':'Лекс Лембиков','text':arr[0],'art':art,'original_ui':True,'choices':answers}
  if doc_answers[n]:
   choices=copy.deepcopy(answers);choices[2]['text']=doc_answers[n];nodes[id]['variants']=[{'when':{'TakenDocs':True},'choices':choices}]
  if n==0:nodes[id]['random_values']={'PilotCode':{'minimum':0,'maximum':1000000,'digits':6,'prefix':'*','suffix':'#','spaced_variable':'PilotCodeSpaced'}}
 # Reachable graph only; every scene keeps its own authored frame, never a fallback picture.
 live=set();todo=[nid('plane',1)]
 while todo:
  id=todo.pop()
  if id in live:continue
  if id not in nodes:raise ValueError('Missing scene '+id)
  live.add(id);node=nodes[id]
  for choices in [node['choices'],*[v.get('choices',[]) for v in node.get('variants',[])]]:
   todo.extend(c['next'] for c in choices);todo.extend(case['next'] for c in choices for case in c.get('next_cases',[]))
  if node.get('back'):todo.append(node['back'])
 nodes={k:v for k,v in nodes.items() if k in live}
 for node in nodes.values():
  for c in node['choices']:
   if nodes[c['next']]['kind']=='city_death' and not c.get('next_cases'):c['pause_allowed']=False
 graph=migrate(5,nodes);graph.update(start=nid('plane',1),title='V. Смерть в воздухе',description='Тучи сгущаются над спящим Нью-Тауном, и бегство — лучший выход. Но от некоторых проблем не скрыться.',variables={'TakenDocs':False,'TakenArmor':False,'BulletsNumber':-1,'PilotCode':'','PilotCodeSpaced':'','CabinCodeKnown':False})
 for id,node in nodes.items():
  if node['kind'].startswith('activity_'):graph['nodes'][id]['type']=node['kind'].removeprefix('activity_')
  graph['nodes'][id]['title']=node['source']
 rows={}
 def localize(v,key):
  if isinstance(v,dict):return {k:marker(x,key+'.'+k) if k in ['text','speaker','title','description'] and isinstance(x,str) and x else localize(x,key+'.'+k) for k,x in v.items()}
  if isinstance(v,list):return [localize(x,key+'.'+str(i)) for i,x in enumerate(v)]
  return v
 def marker(v,key):rows[key]=v;return '@loc:'+key
 graph=localize(graph,'episode5');path=output/'locales/episode5.csv';old={}
 if path.exists():
  with path.open(newline='',encoding='utf-8-sig') as f:old={r['key']:r for r in csv.DictReader(f)}
 with path.open('w',newline='',encoding='utf-8') as f:
  w=csv.writer(f,lineterminator='\n');w.writerow(['key','ru','en']);w.writerows((k,v,old.get(k,{}).get('en','')) for k,v in sorted(rows.items()))
 imports=Path(str(path)+'.import')
 if not imports.exists():imports.write_text('[remap]\nimporter="csv_translation"\ntype="Translation"\n[deps]\nfiles=["res://locales/episode5.ru.translation", "res://locales/episode5.en.translation"]\nsource_file="res://locales/episode5.csv"\ndest_files=["res://locales/episode5.ru.translation", "res://locales/episode5.en.translation"]\n[params]\ncompress=0\ndelimiter=0\nunescape_keys=false\nunescape_translations=false\n')
 (output/'data/story_graphs/episode5.json').write_text(json.dumps(graph,ensure_ascii=False,indent=2)+'\n')
 arts={node[k] for node in nodes.values() for k in ['art','background_art','controls_art'] if k in node}
 (output/'data/episode5_visuals.json').write_text(json.dumps({k:v for k,v in visuals.items() if k in arts},ensure_ascii=False,indent=2)+'\n')
 for sound in {node.get('sound','') for node in nodes.values()}|{'MetalButtonsCLick','ClosedBeep','OpenedBeep'}:
  if sound and not (output/'assets/audio'/(sound+'.mp3')).exists():(output/'assets/audio'/(sound+'.mp3')).write_bytes((sounds/(sound+'.mp3')).read_bytes())
 print('Episode V:',len(nodes),'states,',len(graph['nodes']),'blocks,',len(rows),'locale keys',flush=True)
 return nodes
if __name__=='__main__':
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('archive',type=Path);p.add_argument('--force',action='store_true');a=p.parse_args()
 if (ROOT/'data/story_graphs/episode5.json').exists() and not a.force:raise SystemExit('Graph exists: --force discards authored edits')
 with tempfile.TemporaryDirectory() as td:
  temp=Path(td);lib=temp/'LIBRARY';photos=temp/'Images';sounds=temp/'Sound'
  for d in [lib,photos,sounds]:d.mkdir()
  sources={}
  with zipfile.ZipFile(a.archive) as z:
   for n in z.namelist():
    if '/ZombieApocalypse/LIBRARY/' in n and n.endswith(('.xml','.png','.jpg')):(lib/Path(n).name).write_bytes(z.read(n))
    elif n.startswith('assets/Images/') and not n.endswith('/'):(photos/Path(n).name).write_bytes(z.read(n))
    elif n.startswith('assets/Sound/') and n.endswith('.mp3'):(sounds/Path(n).name).write_bytes(z.read(n))
    elif n.endswith('.as'):sources[Path(n).stem]=z.read(n).decode('utf-8-sig')
  build(lib,photos,sounds,sources,ROOT)
