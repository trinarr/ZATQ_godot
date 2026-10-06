"""Recover the complete Episode III from original XFL/ActionScript into a graph.
Usage: python tools/build_episode3_content.py original.zip [--reuse-art]
Only creates episode3.json; never overwrites authored graphs without --force.
Requires Pillow, fontTools and Inkscape, as the preceding episode exporters.
"""
import argparse, copy, io, json, re, tempfile, zipfile
from pathlib import Path
from PIL import Image
from build_episode1_art import BackgroundRenderer
from build_episode2_content import active_elements, max_frame, text_blocks
from render_flash_ui import Renderer, NS
from migrate_story_graph import migrate
CLASSES={'opening':('Episode3',2000,17),'out':('OutTheHouse',1824,5),'john':('WithJohn',1725,30),'kill':('KillTheJohn',1876,8),'north':('SeveroZapad',1801,15)}
FPS=19

def build(library, photos, sounds, sources, output, reuse=False):
 art=output/'assets/flash_ui'; fonts=output/'fonts/flash'
 r=BackgroundRenderer(library,art,fonts);r.photos=photos;r.retain_text=False;r.omit_root_shapes=False;r.omit_symbols=set()
 nodes={};visuals={};movies={}
 def nid(cls,fr):return f'e3_{cls}_{fr}'
 def result(n):return f'e3_result_{n}'
 def render(key,symbol,frame,ov,photo='',photo_path='Mov.Mov',hide=None,transparent=False,y=0):
  spec={'symbol':symbol,'frame':frame,'overrides':ov,'photo':photo,'photo_path':photo_path,'hide':sorted(hide or []),'offset_y':y}
  visuals[key]=spec
 def add(cls,fr):
  name,sym,_=CLASSES[cls];symbol=f'Symbol {sym}';ov={};photo='';sound=''
  for e in active_elements(r,symbol,fr-1):
   if e.get('name')=='Mov':
    mov=e.get('libraryItemName');movies[(cls,fr)]=mov;ov['Mov']=max_frame(r,mov)
  script='\n'.join(f.findtext('./x:Actionscript/x:script','',NS) for f in r.root(symbol).findall('./x:timeline/x:DOMTimeline/x:layers/x:DOMLayer/x:frames/x:DOMFrame',NS) if int(f.get('index','0'))==fr-1)
  m=re.search(r'LoadImage\("([^"]+)",this\.(Mov(?:\.Mov)?)',script)
  photo_path='Mov.Mov'
  if m:photo,photo_path=m.groups()
  m=re.search(r'SndPlayer\("([^"]+)"',script)
  if m:sound=m[1]
  # ActionScript advances the street caption on entry from the first escape.
  if cls=='out' and fr==3:ov['Mov.Hist']=1
  # KillTheJohn defaults to variant 0, using Hist frame 2 at its frame 4.
  if cls=='kill' and fr==4:ov['Mov.Hist']=1
  blocks=text_blocks(r,symbol,fr-1,ov)
  key=nid(cls,fr)
  node={'episode':3,'source':f'{name} frame {fr}','kind':'city_story','art':key,'art_extension':'png','clean_background':True,'blocks':blocks,'text':' '.join(b['text'] for b in blocks),'choices':[{'text':'Далее','next':nid(cls,fr+1),'rect':[70,0,730,480]}]}
  if sound:node['sound']=sound
  nodes[key]=node
  render(key,sym,fr-1,ov,photo,photo_path,{'Hist','MvMg','NumB'})
 for cls,(_,_,last) in CLASSES.items():
  for fr in range(1,last+1):
   if cls=='out' and fr==1:continue
   add(cls,fr)
 def edges(id,targets):nodes[id]['choices']=[{'text':'Далее','next':t,'rect':[70,0,730,480]} if isinstance(t,str) else t for t in targets]
 def goto(cls,fr,targets):edges(nid(cls,fr),targets)
 def choice(target,**kwargs):return {'text':'Далее','next':target,'rect':[70,0,730,480],**kwargs}
 def variant(cls,fr,v):
  id=nid(cls,fr)+f'_v{v}';node=copy.deepcopy(nodes[nid(cls,fr)])
  sym=CLASSES[cls][1];ov=dict(visuals[nid(cls,fr)]['overrides']);ov['Mov.Hist']=v-1
  node['blocks']=text_blocks(r,f'Symbol {sym}',fr-1,ov);node['text']=' '.join(b['text'] for b in node['blocks']);node['source']+=f'; Hist {v}'
  nodes[id]=node;return id
 def cut(cls,fr,target):
  goto(cls,fr,[target]);n=nodes[nid(cls,fr)];n['kind']='city_cutscene';n['auto_seconds']=(max_frame(r,movies[(cls,fr)])+1)/FPS
 def target_bounds(cls,fr,path,timeline_frames):
  class TargetRenderer(BackgroundRenderer):
   active_path=''
   def symbol(self,name,frame=0,overrides=None,hide=None,path='',depth=0):
    if path and not (target_path==path or target_path.startswith(path+'.') or path.startswith(target_path+'.')):return ''
    previous=self.active_path;self.active_path=path
    try:return super().symbol(name,frame,overrides,hide,path,depth)
    finally:self.active_path=previous
   def shape(self,e):
    return super().shape(e) if self.active_path==target_path or self.active_path.startswith(target_path+'.') else ''
  target_path=path
  fg=TargetRenderer(library,art,fonts);fg.photos=photos;fg.photo='';fg.photo_path='';fg.retain_text=False
  key=nid(cls,fr)+'_target_bounds';bounds=None
  for frame in timeline_frames:
   ov=dict(visuals[nid(cls,fr)]['overrides']);ov['Mov']=frame
   if cls=='john' and fr==23:ov['Mov.Mov']=frame
   fg.render(key+'.png',[(f'Symbol {CLASSES[cls][1]}',fr-1,0,0,ov,set())])
   with Image.open(art/(key+'.png')) as im:box=im.getbbox()
   if box:bounds=box if bounds is None else (min(bounds[0],box[0]),min(bounds[1],box[1]),max(bounds[2],box[2]),max(bounds[3],box[3]))
  (art/(key+'.png')).unlink(missing_ok=True)
  if bounds is None:raise ValueError('Empty original hit area: '+path)
  return [bounds[0]/2,bounds[1]/2,(bounds[2]-bounds[0])/2,(bounds[3]-bounds[1])/2]
 def qte(cls,fr,success,failure,minimum=1,maximum=3,seconds=None,**extra):
  id=nid(cls,fr);node=nodes[id];node['kind']='activity_qte';node['taps']=maximum;node['taps_range']=[minimum,maximum];node['seconds']=seconds or (max_frame(r,movies[(cls,fr)])+1)/FPS;node['original_ui']=True;node.update(extra)
  edges(id,[choice(success,text='Успех'),choice(failure,text='Время истекло')])
  # Recover the moving Flash backdrop at its original timeline rate.
  spec=visuals[id];mov=movies[(cls,fr)];node['animation_frames']=[];node['animation_fps']=FPS
  for frame in range(max_frame(r,mov)+1):
   key=id+f'_anim_{frame}';ov=dict(spec['overrides']);ov['Mov']=frame
   if cls=='john' and fr==23:ov['Mov.Mov']=frame
   render(key,CLASSES[cls][1],fr-1,ov,spec['photo'],spec['photo_path'],{'Hist','MvMg','NumB'})
   node['animation_frames'].append(key)
  node['art']=node['animation_frames'][0]
 raw=re.search(r'this.ResultArr = new <String>\[(.*?)\];',sources['ResultBad'],re.S)[1]
 # Test-result entries contain AS expressions rather than string literals.
 raw=re.sub(r'"(?:[^"\\]|\\.)*"\s*\+\s*Math\s*\.round\(.*?\)\s*\+\s*"(?:[^"\\]|\\.)*"', '"TEST"', raw, flags=re.S)
 results=json.loads('['+raw+']')
 for n in range(51,77):
  alive=n in [64,67,68,73]
  nodes[result(n)]={'episode':3,'source':f'ResultBad({n})','kind':'city_ending' if alive else 'city_death','alive':alive,'result_id':n,'text':results[n-1],'art':'result_alive' if alive else 'result_dead','choices':[]}
  if n==73:nodes[result(n)]['ending_id']=67
 raw=re.search(r'this.itemStrings = new <String>\[(.*?)\];',sources['NewItem'],re.S)[1];questions=json.loads('['+raw+']');labels={}
 for m in re.finditer(r'this.but([1-4])Str\[([\d.]+)\](?:\s*=\s*this.but[1-4]Str\[[\d.]+\])?\s*=\s*"([^"]*)"',sources['NewItem']):labels[(float(m[2]),int(m[1]))]=m[3]
 def decision(cls,fr,item,targets):
  base=nodes[nid(cls,fr)];id=nid(cls,fr)+f'_choice_{item}'
  nodes[id]={'episode':3,'source':f'NewItem({item})','kind':'city_decision','art':base['art'],'art_extension':'png','clean_background':True,'text':questions[item-1],'back':nid(cls,fr),'choices':[]}
  for i,t in enumerate(targets,1):
   c={'next':t} if isinstance(t,str) else copy.deepcopy(t);c['text']=labels[(float(item),i)];nodes[id]['choices'].append(c)
  return id
 # Original third-episode opening, the hand QTE and timed stair/kitchen choice.
 cut('opening',7,'e3_opening_8')
 qte('opening',8,'e3_opening_9','e3_opening_10',2,4,target_rect=target_bounds('opening',8,'Hand',[0]),meter_rect=[640,10,145,40])
 cut('opening',9,'e3_out_4')
 qte('opening',11,'e3_opening_12',result(51),2,4,2.5,qte_mode='branch',targets=[{'text':'К лестнице','rect':target_bounds('opening',11,'But1',[0])},{'text':'На кухню','rect':target_bounds('opening',11,'But2',[0])}],meter_rect=[80,10,220,40])
 edges('e3_opening_11',[choice('e3_opening_12',text='К лестнице'),choice('e3_opening_15',text='На кухню'),choice(result(51),text='Время истекло')])
 goto('opening',14,[result(53)]);nodes['e3_opening_14']['kind']='city_cutscene';nodes['e3_opening_14']['auto_seconds']=11/FPS
 goto('opening',17,[result(52)]);nodes['e3_opening_17']['kind']='city_cutscene';nodes['e3_opening_17']['auto_seconds']=12/FPS
 goto('opening',15,[decision('opening',15,24,['e3_opening_17','e3_opening_16'])]);goto('opening',16,['e3_out_2'])
 cut('out',2,'e3_out_3');goto('out',3,['e3_north_1']);cut('out',4,'e3_out_5');goto('out',5,['e3_dialogue_0'])
 # Dialogue tree is recovered from original sparse arrays and PersonSwitcher2.
 dlgroot=r.root('Symbol 237');script='\n'.join(f.findtext('./x:Actionscript/x:script','',NS) for f in dlgroot.findall('.//x:DOMFrame',NS) if f.get('index')=='1')
 arrays={}
 for m in re.finditer(r'((?:this\.DlgArr\[\d+\]\s*=\s*)+)(\[.*?\]|this\.DlgArr\[\d+\]);',script,re.S):
  value=m[2];value=copy.deepcopy(arrays[int(re.search(r'\d+',value)[0])]) if value.startswith('this.') else json.loads(value)
  for k in re.findall(r'DlgArr\[(\d+)\]',m[1]):arrays[int(k)]=value
 terminal={3:result(54),9:result(56),24:result(55),27:result(57),51:result(58),60:result(58),69:result(59),81:result(59)}
 for n in [45,54]:terminal[n]='e3_pickup_glock16'
 for n in [20,23,43,52]:terminal[n]='e3_pickup_knife'
 for n in [15,18,21,44,50,53,59]:terminal[n]='e3_out_3_v1'
 for n in [13,25,49,58,67,79]:terminal[n]='e3_john_1'
 for n in [68,80]:terminal[n]='e3_john_1_v3'
 for n,arr in arrays.items():
  id=f'e3_dialogue_{n}';cs=[]
  for i,text in enumerate(arr[1:],1):
   next_index=n*3+i;target=terminal.get(next_index,f'e3_dialogue_{next_index}')
   if next_index not in terminal and next_index not in arrays:raise ValueError(f'Missing dialogue {next_index}')
   cs.append({'text':text,'next':target})
  nodes[id]={'episode':3,'source':f'DialogMov(1) DlgArr[{n}], PersonSwitcher2','kind':'activity_dialogue','speaker':'Джон Доннатон','text':arr[0],'art':'e3_dialogue_john','art_extension':'png','original_ui':True,'choices':cs}
 render('e3_dialogue_john',237,1,{'Ava':1,'Dlg1':0,'Dlg2':0,'Dlg3':0},hide={'Txt','PrsnTxt','DlgTxt'})
 # Weapon pickups have the original silhouettes, captions and ammunition.
 weapons={4:'Кухонный нож',5:'Glock 17, 16 патронов 9x19 мм',6:'Glock 17, 7 патронов 9x19 мм'}
 for key,weapon,nxt,background in [('knife',4,'e3_john_1_v2','e3_john_1'),('glock16',5,'e3_kill_1','e3_kill_1'),('glock7',6,'e3_john_5','e3_john_4')]:
  a='e3_item_'+key;render(a,274,0,{'Weapons':weapon,'ButExit':1},hide={'Txt'},transparent=True,y=30)
  nodes['e3_pickup_'+key]={'episode':3,'source':f'AddItem({weapon})','kind':'city_pickup','art':a,'background_art':background,'text':weapons[weapon],'sound':'TakeKnife' if weapon==4 else 'GlockPickUp','set':{'TakenKnife':True} if weapon==4 else {'BulletsNumber':16 if weapon==5 else 7},'choices':[{'text':'Забрать','next':nxt,'rect':[656,326,65,58]}]}
 # Companion text variants, knife check and tunnel paths.
 j1v2=variant('john',1,2);j1v3=variant('john',1,3)
 edges(j1v2,['e3_john_2']);edges(j1v3,['e3_john_2']);out3v=variant('out',3,1);edges(out3v,['e3_north_1'])
 j5v2=variant('john',5,2);edges(j5v2,['e3_john_9'])
 j11v2=variant('john',11,2);edges(j11v2,[result(71)])
 nodes['e3_john_11']['variants']=[{'when':{'JohnVariant':3},'blocks':nodes[j11v2]['blocks'],'text':nodes[j11v2]['text']}]
 nodes[j1v3]['set']={'JohnVariant':3};nodes[j1v2]['set']={'JohnVariant':2}
 goto('john',3,[decision('john',3,25,[choice('e3_john_4',next_cases=[{'when':{'TakenKnife':True},'next':'e3_john_8'}]),j5v2])])
 goto('john',4,['e3_pickup_glock7'])
 qte('john',6,'e3_john_7',result(60),target_rect=target_bounds('john',6,'Mov.Mov.Circle',[0,21]))
 goto('john',7,[decision('john',7,28,['e3_john_17','e3_john_19'])])
 cut('john',8,result(61));goto('john',10,[decision('john',10,30,['e3_john_11','e3_john_12','e3_john_13'])]);goto('john',11,[result(71)]);cut('john',12,result(72))
 cut('john',13,'e3_john_15');nodes['e3_john_13']['choices'][0]['next_cases']=[{'when':{'TakenKnife':True},'next':'e3_john_14'}]
 goto('john',14,['e3_john_16']);cut('john',15,result(75));goto('john',16,[result(73)])
 qte('john',18,'e3_john_28',result(65),target_rect=[70,100,720,320])
 # Four shots: each original target exists for nine frames. Spamming outside
 # a window cannot count; a missed window makes the four-hit success impossible.
 windows=[]
 for start,number in [(2,4),(11,3),(20,2),(29,1)]:windows.append({'start':start/FPS,'end':(start+9)/FPS,'rect':target_bounds('john',23,f'Mov.Mov.Mov{number}',[start,start+8])})
 qte('john',23,'e3_john_24',result(66),4,4,target_windows=windows,resolve_at_end=True,meter_rect=[620,15,170,40])
 goto('john',27,[result(67)]);goto('john',28,[choice('e3_john_30',text='Левый туннель',rect=[65,70,310,340]),choice('e3_john_29',text='Правый туннель',rect=[415,70,350,340])]);goto('john',29,['e3_kill_4_v1']);goto('john',30,[result(70)])
 goto('kill',3,[decision('kill',3,26,['e3_kill_7','e3_kill_4'])]);goto('kill',8,[result(74)])
 kill4v=variant('kill',4,1);edges(kill4v,['e3_kill_5_v2']);kill5v=variant('kill',5,2);edges(kill5v,['e3_kill_6']);nodes[kill5v]['set']={'BulletsNumber':0}
 qte('kill',6,'e3_north_1_v3',result(62),target_rect=[70,75,720,350])
 n1v3=variant('north',1,3);n1v2=variant('north',1,2)
 nodes[n1v3]['choices']=[choice(decision('north',1,27,['e3_north_4','e3_north_3']))]
 nodes[n1v2]['choices']=copy.deepcopy(nodes[n1v3]['choices'])
 goto('north',2,['e3_north_8']);goto('north',3,['e3_north_6']);goto('north',5,[choice(result(63),next_cases=[{'when':{'BulletsNumber':0},'next':result(76)}])]);goto('north',7,[result(64)]);goto('north',9,[decision('north',9,29,['e3_north_12','e3_north_10'])]);goto('north',11,[result(68)]);goto('north',15,[result(69)])
 # Retain only routes reachable from Episode III, including conditional edges.
 seen=set();todo=['e3_opening_1']
 while todo:
  id=todo.pop()
  if id in seen:continue
  if id not in nodes:raise ValueError('Missing scene '+id)
  seen.add(id);n=nodes[id]
  for c in n['choices']:
   todo.append(c['next']);todo.extend(x['next'] for x in c.get('next_cases',[]))
  if n.get('back'):todo.append(n['back'])
 nodes={k:v for k,v in nodes.items() if k in seen}
 graph=migrate(3,nodes);graph['start']='e3_opening_1';graph['title']='III. Преждевременные надежды';graph['description']='Джек все больше погружается в пучину окружающего хаоса. Будет ли военная база последним спасением?';graph['variables']={'TakenKnife':False,'JohnVariant':1}
 for id,n in nodes.items():
  if n['kind'].startswith('activity_'):graph['nodes'][id]['type']=n['kind'].removeprefix('activity_')
  graph['nodes'][id]['title']=n['source']
 # Clear deterministic layout: primary screens occupy columns, associated
 # choices/conditions/actions remain beside their owners.
 output.joinpath('data/story_graphs/episode3.json').write_text(json.dumps(graph,ensure_ascii=False,indent=2)+'\n')
 output.joinpath('data/episode3_visuals.json').write_text(json.dumps(visuals,ensure_ascii=False,indent=2)+'\n')
 for sound in {n.get('sound','') for n in nodes.values()}:
  if sound:
   target=output/'assets/audio'/(sound+'.mp3')
   if not target.exists():target.write_bytes((sounds/(sound+'.mp3')).read_bytes())
 print('Episode III:',len(nodes),'screens;',len(graph['nodes']),'blocks;',sum(n['kind']=='activity_qte' for n in nodes.values()),'QTE;',sum(n['kind']=='activity_dialogue' for n in nodes.values()),'dialogue states',flush=True)

def main():
 p=argparse.ArgumentParser();p.add_argument('archive',type=Path);p.add_argument('--output',type=Path,default=Path(__file__).resolve().parents[1]);p.add_argument('--reuse-art',action='store_true');p.add_argument('--force',action='store_true');a=p.parse_args()
 if (a.output/'data/story_graphs/episode3.json').exists() and not a.force:raise SystemExit('episode3.json already exists; --force discards authored changes')
 with tempfile.TemporaryDirectory() as tmp:
  lib=Path(tmp)/'LIBRARY';photos=Path(tmp)/'Images';sounds=Path(tmp)/'Sound'
  for d in [lib,photos,sounds]:d.mkdir()
  sources={}
  with zipfile.ZipFile(a.archive) as z:
   for n in z.namelist():
    if '/ZombieApocalypse/LIBRARY/' in n and n.endswith(('.xml','.png','.jpg')):(lib/Path(n).name).write_bytes(z.read(n))
    elif n.startswith('assets/Images/') and not n.endswith('/'):(photos/Path(n).name).write_bytes(z.read(n))
    elif n.startswith('assets/Sound/') and n.endswith('.mp3'):(sounds/Path(n).name).write_bytes(z.read(n))
    elif n.endswith('.as'):sources[Path(n).stem]=z.read(n).decode('utf-8-sig')
  build(lib,photos,sounds,sources,a.output,a.reuse_art)
 from build_episode3_components import build as build_components
 build_components(a.archive,a.output)
if __name__=='__main__':main()
