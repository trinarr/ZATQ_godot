"""Episode VI routes, authored captions and three original dialogue trees.
Rebuild: python tools/build_episode6_content.py ORIGINAL.zip [--force].
"""
import argparse,copy,csv,json,re,tempfile,zipfile
from pathlib import Path
from build_episode1_art import BackgroundRenderer
from build_episode2_content import active_elements,max_frame,text_blocks
from build_episode4_content import source_array
from build_episode5_content import branch
from migrate_story_graph import migrate
from render_flash_ui import NS
from build_localized_ui import matrix
ROOT=Path(__file__).resolve().parents[1]
CLASSES={'carrier':('Episode6',655,16,3),'boats':('RoadToBoats',575,9,1),'wake':('WakeUpNoLeg',412,14,6),'after':('AfterDialog',703,9,5),'noleg':('WithoutLeg',320,8,2),'prison':('TwoDaysPrison',479,11,7),'base':('SideMilitaryBase',524,7,3)}
def nid(cls,fr,v=1):return f'e6_{cls}_{fr}_v{v}'
def result(n):return f'e6_result_{n}'
def build(lib,photos,sounds,sources,output):
 r=BackgroundRenderer(lib,output/'assets/flash_ui',output/'fonts/flash');r.photos=photos;r.retain_text=False;r.omit_root_shapes=False;r.omit_symbols=set()
 nodes={};visuals={}
 def visual(key,symbol,fr,ov,photo='',photo_path='Mov.Mov',hide=None):
  visuals[key]={'symbol':symbol,'frame':fr,'overrides':ov,'photo':photo,'photo_path':photo_path,'hide':sorted(hide or []),'omit_symbols':['Symbol 539','Symbol 379']}
 for cls,(name,sym,last,variants) in CLASSES.items():
  for v in range(1,variants+1):
   for fr in range(1,last+1):
    id=nid(cls,fr,v);symbol=f'Symbol {sym}';ov={};photo='';path='Mov.Mov';sound='';hist=None
    for e in active_elements(r,symbol,fr-1):
     if e.get('name')=='Mov':ov['Mov']=max_frame(r,e.get('libraryItemName'))
    script='\n'.join(f.findtext('x:Actionscript/x:script','',NS) for f in r.root(symbol).findall('./x:timeline/x:DOMTimeline/x:layers/x:DOMLayer/x:frames/x:DOMFrame',NS) if int(f.get('index',0))==fr-1)
    m=re.search(r'LoadImage\("([^"]+)",this\.(Mov(?:\.Mov)?)',script)
    if m:photo,path=m.groups()
    m=re.search(r'SndPlayer\("([^"]+)"',script)
    if m:sound=m[1]
    if cls=='carrier' and fr==8:hist=v//2
    if cls=='wake':
     if fr==2:hist=v-2
     elif fr==3:hist=1 if v in [2,6] else 0
     elif fr==4:hist=1 if v==3 else 0
    if cls=='after' and fr in [2,3]:hist=v-2 if fr==2 else v-4
    if cls=='noleg' and fr in [6,7]:hist=v-1
    if cls=='prison':
     if fr==1:hist=v-1
     elif fr==4:hist=v-1 # 1=missed first fight; 2=missed second; 3=won second.
     elif fr in [6,9,10]:hist=v-5
     elif fr==8:hist=v//7
    if cls=='base':
     if fr==1:hist=v-1
     elif fr==3:hist=1 if v==3 else 0
    if hist is not None:ov['Mov.Hist']=max(0,hist)
    if cls=='noleg' and fr==1:photo='FindingLED.jpg';sound='LyingBed'
    if cls=='prison' and fr==1:photo='AfterPrisonCell.jpg'
    blocks=text_blocks(r,symbol,fr-1,ov)
    nodes[id]={'episode':6,'source':f'{name} frame {fr}; type {v}','kind':'city_story','art':id,'clean_background':True,'blocks':blocks,'text':' '.join(b['text'] for b in blocks),'choices':[branch(nid(cls,fr+1,v))]}
    if sound:nodes[id]['sound']=sound
    if 'addEventListener("End"' in script or (cls=='wake' and fr==1):nodes[id]['input_after_intro']=True
    if cls=='carrier' and fr in [8,9] and v!=1:nodes[id].pop('input_after_intro',None)
    if cls=='base' and fr==3 and v!=3:nodes[id].pop('input_after_intro',None)
    visual(id,sym,fr-1,ov,photo,path,{'Hist','MvMg','Fing','Tap','But',*[f'But{i}' for i in range(1,5)]})
 def edges(cls,fr,v,targets):nodes[nid(cls,fr,v)]['choices']=[branch(t) if isinstance(t,str) else t for t in targets]
 questions=source_array(sources['NewItem'],'itemStrings');labels={}
 for m in re.finditer(r'this.but([1-4])Str\[([\d.]+)\](?:\s*=\s*this.but[1-4]Str\[[\d.]+\])?\s*=\s*"([^"]*)"',sources['NewItem']):labels[(int(float(m[2])),int(m[1]))]=m[3]
 def decision(cls,fr,v,item,targets):
  back=nid(cls,fr,v);id=back+f'_choice_{item}';choices=[]
  for i,t in enumerate(targets,1):
   c=branch(t) if isinstance(t,str) else copy.deepcopy(t);c['text']=labels[(item,i)];c.pop('rect',None);choices.append(c)
  nodes[id]={'episode':6,'source':f'NewItem({item})','kind':'city_decision','art':back,'clean_background':True,'text':questions[item-1],'back':back,'choices':choices};edges(cls,fr,v,[id])
 results=source_array(sources['ResultBad'],'ResultArr')
 for n in range(137,162):
  alive=n in [151,160];nodes[result(n)]={'episode':6,'source':f'ResultBad({n})','kind':'city_ending' if alive else 'city_death','alive':alive,'result_id':n,'text':results[n-1],'choices':[]}
 def pickup(key,weapon,next_node,background):
  art='e6_item_'+key;visual(art,274,0,{'Weapons':weapon,'ButExit':1},hide={'Txt'});visuals[art]['offset_y']=30
  id='e6_pickup_'+key;nodes[id]={'episode':6,'source':f'AddItem({weapon})','kind':'city_pickup','art':art,'background_art':background,'text':source_array(sources['AddItem'],'weapStrings')[weapon-1],'sound':{14:'WeaponAim',15:'TakeKnife',16:'M4Chamber',17:'GlockPickUp',18:'WeaponAim'}[weapon],'choices':[branch(next_node,text='Забрать')]};return id
 def qte(cls,fr,v,success,failure,**data):
  data.setdefault('taps',data.get('taps_range',[10])[0])
  node=nodes[nid(cls,fr,v)];node.update(kind='activity_qte',original_ui=True,**data);node.pop('input_after_intro',None);node['choices']=[branch(success,text='Успеть'),branch(failure,text='Не успеть')];node.update(blocks=[],text='',meter_mode='remaining_taps')
  visuals[node['art']].update(activity_qte=True,activity_frames=round(data['seconds']*19))
  if data.get('native_prompt'):
   fs=r.root('Symbol 28').findall('./x:timeline/x:DOMTimeline/x:layers/x:DOMLayer/x:frames/x:DOMFrame',NS)
   offsets={int(f.get('index')):list(matrix(f.find('x:elements/x:DOMSymbolInstance',NS))[4:]) for f in fs if f.find('x:elements/x:DOMSymbolInstance',NS) is not None};node['prompt_offsets']=[offsets[i] for i in range(13)]
 def cycle(cls,fr,v,success,failure,taps,cycles,area):qte(cls,fr,v,success,failure,taps=taps,seconds=cycles*13/19,target_cycles=cycles,cycle_seconds=13/19,target_areas=[area],target_size=[112,112],native_prompt=True,meter_rect=[1,20,75,45])
 for v in [1,2,3]:
  edges('carrier',1,v,[pickup('tooth',14,nid('carrier',2),nid('carrier',2))])
  decision('carrier',2,v,57,[nid('carrier',5),nid('carrier',12),nid('carrier',3)])
  edges('carrier',4,v,[nid('carrier',6,v)])
  decision('carrier',6,v,58,[nid('carrier',9,2),nid('carrier',7),nid('carrier',9,3)])
  cycle('carrier',7,v,result(137),nid('carrier',8),1,3,[221,0,250,280])
  edges('carrier',8,v,[result(138) if v==3 else nid('carrier',15,v)])
  edges('carrier',9,v,[nid('carrier',8,v) if v==3 else nid('carrier',11,v)])
  edges('carrier',11,v,[nid('boats',1)])
  edges('carrier',14,v,['e6_dialogue_hernandez_0'])
  edges('carrier',16,v,[nid('wake',1)])
 decision('boats',1,1,59,[nid('boats',6),nid('boats',2)])
 id=nid('boats',2);controls=id+'_controls';visual(controls,575,1,{'But1':4,'But2':4},hide={'Mov'});visuals[controls]['omit_root_shapes']=True
 nodes[id]['controls_art']=controls;nodes[id]['choices']=[branch(pickup('knife',15,nid('boats',3),nid('boats',3)),text='Взять нож',source_button='But1'),branch(nid('boats',4),text='Идти дальше',source_button='But2')]
 edges('boats',3,1,[result(139)]);decision('boats',5,1,61,[nid('wake',2,2),result(140)])
 decision('boats',6,1,63,[nid('wake',2,5),nid('boats',7)])
 cycle('boats',7,1,pickup('m4_boats',16,nid('boats',8),nid('boats',8)),result(141),2,3,[120,107,498,75])
 edges('boats',9,1,[nid('base',1)])
 for v in range(1,7):
  decision('wake',1,v,60,[nid('noleg',2),nid('noleg',1)])
  if v in [4,5]:decision('wake',3,v,64,[result(143),nid('wake',4,v)])
  elif v in [2,6]:decision('wake',3,v,65,[pickup('glock',17,nid('wake',5,v),nid('wake',5,v)),nid('prison',1),result(145)])
  else:edges('wake',3,v,[nid('wake',4,v)])
  edges('wake',4,v,[nid('wake',9,v) if v==3 else result(144)])
  cycle('wake',7,v,result(146),nid('wake',8,v),2,5,[15,9,240,234])
  edges('wake',8,v,[nid('prison',1,2)])
  decision('wake',9,v,68,[nid('wake',10,v),nid('wake',11,v)])
  edges('wake',10,v,[nid('wake',12,v)])
  nodes[nid('wake',12,v)].update(kind='city_cutscene',auto_seconds=.01,pause_allowed=False)
  edges('wake',14,v,[result(151)])
 for v in range(1,6):
  edges('after',1,v,[nid('after',4,v)])
  edges('after',2,v,[nid('wake',2,6) if v==4 else nid('after',8,v)])
  edges('after',3,v,[nid('after',2,4)])
  decision('after',4,v,62,[nid('after',5,v),nid('after',6,v)])
  edges('after',5,v,[nid('wake',2,3)])
  edges('after',6,v,[pickup('m4_lab',16,nid('after',7,v),nid('after',7,v))]);edges('after',7,v,[nid('after',9,v)])
  edges('after',8,v,[result(142)]);edges('after',9,v,[nid('base',1,2)])
 for v in [1,2]:
  edges('noleg',1,v,[pickup('torch',18,nid('noleg',3,v),nid('noleg',3,v))]);edges('noleg',2,v,[nid('noleg',5,v)])
  decision('noleg',4,v,66,[nid('noleg',6,2),nid('noleg',6)])
  edges('noleg',5,v,[result(147)])
  if v==2:decision('noleg',6,v,67,['e6_dialogue_pete_0',nid('noleg',7,2)])
  else:edges('noleg',6,v,[result(148)])
  edges('noleg',8,v,[result(149)])
 for v in range(1,8):
  cycle('prison',3,v,result(155) if v==1 else nid('prison',4,3),nid('prison',4,1 if v==1 else 2),2 if v==1 else 1,3,[107,28,316,227])
  edges('prison',4,v,[nid('prison',8,7) if v==1 else 'e6_dialogue_dave_0' if v==2 else nid('prison',5,v)])
  edges('prison',5,v,[nid('prison',6,5)]);edges('prison',6,v,[nid('prison',8,v)])
  edges('prison',7,v,[nid('prison',6,6)])
  if v==6:decision('prison',8,v,71,[nid('prison',9,7),nid('prison',9,6)])
  else:edges('prison',8,v,[result(156) if v==7 else nid('prison',9,v)])
  edges('prison',9,v,[result(157) if v==7 else nid('prison',10,v)])
  decision('prison',10,v,72,[result(158),nid('prison',11,v)])
  edges('prison',11,v,[result(154+v)])
 for v in [1,2,3]:
  decision('base',2,v,69,[nid('base',7,v),nid('base',3,v)])
  edges('base',3,v,[nid('base',4,v)])
  decision('base',4,v,70,[nid('base',5,v),result(152)])
  edges('base',6,v,[result(154 if v==3 else 153)])
  qte('base',7,v,nid('base',3,3),result(161),seconds=33/19,taps_range=[2,3],target_rect=[70,0,730,480],meter_rect=[1,20,75,45])
 # Dialogue N calls PersonSwitcher N+1, with index = previous * 3 + answer.
 for n,key in [(6,'hernandez'),(7,'pete'),(8,'dave')]:
  script='\n'.join(f.findtext('x:Actionscript/x:script','',NS) for f in r.root('Symbol 237').findall('.//x:DOMFrame',NS) if int(f.get('index',0))==n)
  arrays={}
  for m in re.finditer(r'((?:this\.DlgArr\[\d+\]\s*=\s*)+)(\[.*?\]|this\.DlgArr\[\d+\]);',script,re.S):
   arr=copy.deepcopy(arrays[int(re.search(r'\d+',m[2])[0])]) if m[2].startswith('this.') else json.loads(m[2])
   for index in re.findall(r'DlgArr\[(\d+)\]',m[1]):arrays[int(index)]=arr
  fn=sources['DialogMov'].split(f'public function PersonSwitcher{n+1}(')[1].split('public function ')[0];terminals={}
  for m in re.finditer(r'((?:\s*case \d+:)+)(.*?)break;',fn,re.S):
   a=re.search(r'new (AfterDialog|WithoutLeg|TwoDaysPrison)\((\d*)\)',m[2])
   if not a:continue
   cls={'AfterDialog':'after','WithoutLeg':'noleg','TwoDaysPrison':'prison'}[a[1]];v=int(a[2] or 1);fr=v//2+1 if cls=='after' else v
   for index in re.findall(r'case (\d+):',m[1]):terminals[int(index)]=nid(cls,fr,v if cls!='noleg' else 1)
  art='e6_dialogue_'+key;visual(art,237,n,{'Ava':n,'Dlg1':0,'Dlg2':0,'Dlg3':0},hide={'Txt','PrsnTxt','DlgTxt'})
  speaker=json.loads(re.search(r'this.PrsnTxt.text = ("(?:[^"\\]|\\.)*")',script)[1])
  for index,arr in arrays.items():
   choices=[]
   for i,text in enumerate(arr[1:],1):
    dest=index*3+i
    if dest not in terminals and dest not in arrays:raise ValueError(f'Missing {key} dialogue {dest}')
    c=branch(terminals.get(dest,f'e6_dialogue_{key}_{dest}'),text=text);c.pop('rect',None);choices.append(c)
   nodes[f'e6_dialogue_{key}_{index}']={'episode':6,'source':f'DialogMov({n}) DlgArr[{index}]','kind':'activity_dialogue','speaker':speaker,'text':arr[0],'art':art,'original_ui':True,'choices':choices}
 live=set();todo=[nid('carrier',1)]
 while todo:
  id=todo.pop()
  if id in live:continue
  if id not in nodes:raise ValueError('Missing scene '+id)
  live.add(id);todo.extend(c['next'] for c in nodes[id]['choices'])
  if nodes[id].get('back'):todo.append(nodes[id]['back'])
 nodes={k:v for k,v in nodes.items() if k in live}
 for node in nodes.values():
  for c in node['choices']:
   if nodes[c['next']]['kind']=='city_death':c['pause_allowed']=False
 graph=migrate(6,nodes);graph.update(start=nid('carrier',1),title='VI. Рассвет',description='Здесь ничто не стоит на месте. И ты либо приспособлен, либо мертв — законы нового мира предельно просты.',variables={})
 for id,node in nodes.items():
  if node['kind'].startswith('activity_'):graph['nodes'][id]['type']=node['kind'].removeprefix('activity_')
  graph['nodes'][id]['title']=node['source']
 rows={}
 def marker(value,key):rows[key]=value;return '@loc:'+key
 def localize(value,key):
  if isinstance(value,dict):return {k:marker(v,key+'.'+k) if k in ['text','speaker','title','description'] and isinstance(v,str) and v else localize(v,key+'.'+k) for k,v in value.items()}
  if isinstance(value,list):return [localize(v,key+'.'+str(i)) for i,v in enumerate(value)]
  return value
 graph=localize(graph,'episode6');path=output/'locales/episode6.csv'
 with path.open('w',newline='',encoding='utf-8') as f:
  w=csv.writer(f,lineterminator='\n');w.writerow(['key','ru','en']);w.writerows((k,v,'') for k,v in sorted(rows.items()))
 Path(str(path)+'.import').write_text('[remap]\nimporter="csv_translation"\ntype="Translation"\n[deps]\nfiles=["res://locales/episode6.ru.translation", "res://locales/episode6.en.translation"]\nsource_file="res://locales/episode6.csv"\ndest_files=["res://locales/episode6.ru.translation", "res://locales/episode6.en.translation"]\n[params]\ncompress=0\ndelimiter=0\nunescape_keys=false\nunescape_translations=false\n')
 (output/'data/story_graphs/episode6.json').write_text(json.dumps(graph,ensure_ascii=False,indent=2)+'\n')
 arts={node[k] for node in nodes.values() for k in ['art','background_art','controls_art'] if k in node}
 (output/'data/episode6_visuals.json').write_text(json.dumps({k:v for k,v in visuals.items() if k in arts},ensure_ascii=False,indent=2)+'\n')
 for sound in {node.get('sound','') for node in nodes.values()}:
  if sound and not (output/'assets/audio'/(sound+'.mp3')).exists():(output/'assets/audio'/(sound+'.mp3')).write_bytes((sounds/(sound+'.mp3')).read_bytes())
 print('Episode VI:',len(nodes),'states;',len(rows),'locale keys')
 return nodes
if __name__=='__main__':
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('archive',type=Path);p.add_argument('--force',action='store_true');a=p.parse_args()
 if (ROOT/'data/story_graphs/episode6.json').exists() and not a.force:raise SystemExit('Graph exists: --force discards authored edits')
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
