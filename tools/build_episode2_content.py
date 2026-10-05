"""Recover Episode II routes, text and 2x art from the original Flash archive.
Usage: python tools/build_episode2_content.py original.zip
Requires the same dependencies as build_episode1_art.py. Runtime uses exported art.
"""
import argparse,json,re,tempfile,zipfile,os,io
from pathlib import Path
from PIL import Image
from build_episode1_art import BackgroundRenderer
from render_flash_ui import Renderer,NS

CLASSES={'hospital':2443,'roof':2281,'first':2216,'hall':2077,'back':2010,'main':2145,'lift':2301,'attack':2020,'boom':2652}
AS={'hospital':'Episode2','roof':'StairsToTheRoof','first':'ToFirstFloor','hall':'ToTheKilling','back':'ZombieOnTheBack','main':'ToMainPart','lift':'LiftCall','attack':'ZombieAttackKill','boom':'MovBoom'}
def active_elements(r,symbol,frame):
 for layer in r.root(symbol).findall('./x:timeline/x:DOMTimeline/x:layers/x:DOMLayer',NS):
  frames=[f for f in layer.findall('./x:frames/x:DOMFrame',NS) if int(f.get('index','0'))<=frame]
  if frames:
   yield from frames[-1].findall('./x:elements/*',NS)
def max_frame(r,symbol):
 return max(int(f.get('index','0')) for f in r.root(symbol).findall('./x:timeline/x:DOMTimeline/x:layers/x:DOMLayer/x:frames/x:DOMFrame',NS))
def text_blocks(r,symbol,frame,overrides,path='',position=(0,0),depth=0):
 if depth>30:return []
 result=[]
 for e in active_elements(r,symbol,frame):
  part=e.get('name','');childpath=(path+'.'+part).strip('.') if part else path
  m=e.find('./x:matrix/x:Matrix',NS);xy=tuple(position[i]+float(m.get(k,'0')) if m is not None else position[i] for i,k in enumerate(['tx','ty']))
  if e.tag.endswith('DOMSymbolInstance'):
   result+=text_blocks(r,e.get('libraryItemName'),overrides.get(childpath,int(e.get('firstFrame','0'))),overrides,childpath,xy,depth+1)
  elif e.tag.endswith(('DOMStaticText','DOMDynamicText')):
   text=''.join(x.text or '' for x in e.findall('.//x:characters',NS)).strip();attrs=e.find('.//x:DOMTextAttrs',NS)
   if text and 'NumB' not in childpath:
    rect=[*xy,float(e.get('width','0')),float(e.get('height','0'))]
    rect[2]=min(rect[2],780-rect[0]);rect[3]=min(rect[3],480-rect[1])
    result.append({'text':re.sub(r'\s+',' ',text),'rect':rect,'font':attrs.get('face','GraffitiC1 Medium'),'size':int(float(attrs.get('size','24'))),'path':childpath})
 return result

def build(library,photos,sources,output,render=True,reuse_art=False):
 art=output/'assets/flash_ui';fonts=output/'fonts/flash';r=BackgroundRenderer(library,art,fonts);r.photos=photos;r.retain_text=False
 r.omit_root_shapes=False;r.omit_symbols=set()
 nodes={};visuals={}
 def nid(cls,frame):return 'e2_'+cls+'_'+str(frame)
 def add(cls,frame,variant=1):
  id=nid(cls,frame)+(('_v'+str(variant)) if variant!=1 else '')
  symbol='Symbol '+str(CLASSES[cls]);ov={};photo='';photo_path='Mov.Mov';snd=''
  if cls in ['first','hall','main','lift']:ov['Mov.Hist']=variant-1
  if cls=='hospital' and frame in [7,8,15,16,17]:ov['Mov.Hist']=variant-1
  for e in active_elements(r,symbol,frame-1):
   if e.tag.endswith('DOMSymbolInstance') and e.get('name')=='Mov':
    ov['Mov']=max_frame(r,e.get('libraryItemName'))
  for layer in r.root(symbol).findall('./x:timeline/x:DOMTimeline/x:layers/x:DOMLayer',NS):
   for f in layer.findall('./x:frames/x:DOMFrame',NS):
    if int(f.get('index','0'))==frame-1:
     script=f.findtext('./x:Actionscript/x:script','',NS)
     match=re.search(r'LoadImage\("([^"]+)",this\.(Mov(?:\.Mov)?)',script)
     if match:photo,photo_path=match.groups()
     match=re.search(r'SndPlayer\("([^"]+)"',script)
     if match:snd=match[1]
  blocks=text_blocks(r,symbol,frame-1,ov)
  if not blocks:blocks=text_blocks(r,symbol,frame-1,{k:v for k,v in ov.items() if k!='Mov'})
  key=nid(cls,frame) # Hist variants only change native text; backgrounds are identical.
  node={'episode':2,'source':AS[cls]+' frame '+str(frame)+'; Hist '+str(variant),'kind':'city_story','art':key,'art_extension':'webp','clean_background':True,'blocks':blocks,'text':' '.join(b['text'] for b in blocks),'choices':[{'text':'Далее','next':nid(cls,frame+1),'rect':[70,0,730,480]}]}
  if snd:node['sound']=snd
  nodes[id]=node
  if key not in visuals:
   visual={'symbol':CLASSES[cls],'frame':frame-1,'overrides':ov,'photo':photo,'photo_path':photo_path,'hide':['Hist','But1','But2','NumB']}
   visuals[key]=visual
   if render and (not reuse_art or not (art/(key+".webp")).exists() or (art/(key+".webp")).stat().st_size==0):
    r.photo=photo;r.photo_path=photo_path
    r.render(key+'.png',[(symbol,frame-1,0,0,ov,set(visual['hide']))])
    with Image.open(art/(key+'.png')) as im:
     bg=Image.new('RGBA',im.size,'black');bg.alpha_composite(im.convert('RGBA'));buffer=io.BytesIO();bg.convert('RGB').save(buffer,format='WEBP',quality=95,method=6)
     temporary=art/(key+'.webp.tmp')
     with temporary.open('wb') as f:f.write(buffer.getvalue());f.flush();os.fsync(f.fileno())
     os.replace(temporary,art/(key+'.webp'))
    (art/(key+'.png')).unlink()
  return id
 for cls,last in [('hospital',20),('roof',12),('first',12),('hall',9),('back',2),('main',11),('lift',3),('attack',2)]:
  for frame in range(1,last+1):add(cls,frame)
 for cls,frames,variants in [('hospital',[7,8,15,17],[2]),('hospital',[16],[2,3]),('first',[1],[2,3]),('first',[2],[2]),('first',[10],[2]),('hall',[1,2],[2]),('main',[1],[2,3]),('lift',[1,2],[2])]:
  for frame in frames:
   for v in variants:add(cls,frame,v)
 # ResultBad keeps the original texts and result IDs; episode-local statistics.
 result_source=sources['ResultBad'];raw=re.search(r'this.ResultArr = new <String>\[(.*?)\];',result_source,re.S)[1]
 endings=[json.loads(m[0]) for m in re.finditer(r'"(?:[^"\\]|\\.)*"',raw)]
 for result_id in range(33,50):
  alive=result_id in [38,43,47]
  nodes['e2_result_'+str(result_id)]={'episode':2,'source':'ResultBad('+str(result_id)+')','kind':'city_ending' if alive else 'city_death','alive':alive,'result_id':result_id,'text':endings[result_id-1],'art':'result_alive' if alive else 'result_dead','choices':[]}
 def edge(id,targets):
  nodes[id]['choices']=[{'text':'Далее','next':target,'rect':[70,0,730,480]} if isinstance(target,str) else target for target in targets]
 def goto(cls,fr,targets):edge(nid(cls,fr),targets)
 def branch(target,when=None,**extra):
  d={'text':'Далее','next':target,'rect':[70,0,730,480],**extra}
  if when:d['requires']=when
  return d
 def cut(cls,fr,targets,seconds=1.5):
  goto(cls,fr,targets);nodes[nid(cls,fr)]['kind']='city_cutscene';nodes[nid(cls,fr)]['auto_seconds']=seconds
 # Native decision text is recovered verbatim from NewItem.
 raw=re.search(r'this.itemStrings = new <String>\[(.*?)\];',sources['NewItem'],re.S)[1];questions=json.loads('['+raw+']')
 labels={}
 for m in re.finditer(r'this.but([1-4])Str\[([\d.]+)\](?:\s*=\s*this.but[1-4]Str\[[\d.]+\])?\s*=\s*"([^"]*)"',sources['NewItem']):labels[(float(m[2]),int(m[1]))]=m[3]
 def decision(cls,fr,item,targets,back=None):
  id=nid(cls,fr)+'_choice_'+str(item).replace('.','_');base=nodes[nid(cls,fr)]
  node={'episode':2,'source':'NewItem('+str(item)+')','kind':'city_decision','art':base['art'],'art_extension':'webp','clean_background':True,'text':questions[int(item)-1],'choices':[],'back':back or nid(cls,fr)}
  for i,target in enumerate(targets,1):
   choice={'text':labels.get((float(item),i),labels.get((float(int(item)),i),'')),'next':target} if isinstance(target,str) else dict(target)
   choice['text']=labels.get((float(item),i),labels.get((float(int(item)),i),choice.get('text','')));node['choices'].append(choice)
  if len(targets)==4:node['decision_art']='ep2_decision_4'
  nodes[id]=node;return id
 def result(n):return 'e2_result_'+str(n)
 # Opening, police pistol and Nick's injured friend.
 q11=decision('hospital',5,11,['e2_glock','e2_hospital_13','e2_hospital_6']);goto('hospital',5,[q11])
 q12=decision('hospital',6,12,['e2_hospital_7_v2','e2_hospital_15','e2_hospital_16_v3']);goto('hospital',6,[q12])
 goto('hospital',7,['e2_hospital_8']);edge('e2_hospital_7_v2',['e2_hospital_8_v2'])
 goto('hospital',8,['e2_hospital_19']);edge('e2_hospital_8_v2',[result(33)])
 q13=decision('hospital',9,13,['e2_hospital_10','e2_hospital_11']);goto('hospital',9,[q13])
 cut('hospital',10,[branch('e2_hospital_11',add={'BulletsNumber':-1})])
 q14=decision('hospital',11,14,['e2_hospital_12',branch('e2_hospital_16',{'BulletsNumber':5}),branch('e2_hospital_17',{'BulletsNumber':{'max':4}})])
 # q14 has two authored buttons: the second button selects its target by ammo.
 nodes[q14]['choices']=[nodes[q14]['choices'][0],{'text':labels[(14.0,2)],'next':'e2_hospital_17','next_cases':[{'when':{'BulletsNumber':5},'next':'e2_hospital_16'}]}]
 goto('hospital',11,[q14]);cut('hospital',12,[branch('e2_first_1',add={'BulletsNumber':-2})])
 goto('hospital',14,[result(34)])
 q16=decision('hospital',15,16,['e2_hospital_7','e2_first_1_v2','e2_hospital_17_v2','e2_lift_1'])
 q161=decision('hospital',15,16.1,['e2_hospital_7','e2_first_1_v2','e2_hospital_17_v2','e2_lift_1'])
 nodes['e2_hospital_15']['set']={'LinkedFr':True};nodes['e2_hospital_15']['variants']=[{'when':{'BulletsNumber':{'min':0}},'blocks':nodes['e2_hospital_15_v2']['blocks']}]
 goto('hospital',15,[branch(q161,{'BulletsNumber':{'min':0}}),branch(q16,{'BulletsNumber':-1})])
 for id in ['e2_hospital_16','e2_hospital_16_v2','e2_hospital_16_v3']:
  edge(id,['e2_roof_1',branch('e2_hall_1_v2',{'BulletsNumber':{'min':1}}),branch('e2_hall_1',{'BulletsNumber':{'max':0}})])
  nodes[id]['choices'][0]['text']='Подняться на крышу'
  for c in nodes[id]['choices'][1:]:c['text']='Идти в главную часть больницы'
 nodes['e2_hospital_16']['variants']=[{'when':{'BulletsNumber':0},'blocks':nodes['e2_hospital_16_v2']['blocks']},{'when':{'BulletsNumber':-1},'blocks':nodes['e2_hospital_16_v3']['blocks']}]
 q18=decision('hospital',17,18,['e2_hospital_18','e2_hospital_15','e2_first_1_v3']);goto('hospital',17,[q18]);edge('e2_hospital_17_v2',['e2_back_1'])
 cut('hospital',18,[branch('e2_hospital_16',set={'BulletsNumber':0})]);cut('hospital',20,[branch('e2_boom_4',add={'BulletsNumber':-1})])
 goto('hospital',19,['e2_hospital_20']);nodes['e2_hospital_19']['pickup_if']={'when':{'BulletsNumber':-1},'next':'e2_glock_friend'}
 # Pickup screens, faithful weapon and ammunition counts.
 for id,next in [('e2_glock','e2_hospital_9'),('e2_glock_friend','e2_hospital_19'),('e2_mark23','e2_main_4')]:
  mark=id=='e2_mark23';nodes[id]={'episode':2,'source':'AddItem('+('3' if mark else '2')+')','kind':'city_pickup','art':'ep2_item_mark23' if mark else 'ep2_item_glock','background_art':'e2_main_3' if mark else 'e2_hospital_5','text':'Mark 23, 12 патронов .45 ACP' if mark else 'Glock 19 Gen4, 5 патронов 9x19 мм','sound':'TakeMK23' if mark else 'GlockPickUp','set':{'BulletsNumber':12 if mark else 5},'choices':[{'text':'Забрать','next':next,'rect':[656,326,65,58]}]}
 # Fire escape, chain locks and military checkpoint.
 q15=decision('first',3,15,[{'next':'e2_first_4','next_cases':[{'when':{'BulletsNumber':3},'next':'e2_first_11'},{'when':{'BulletsNumber':2},'next':'e2_first_12'}]},'e2_first_9'])
 q19=decision('first',3,19,['e2_first_locked','e2_first_9'])
 goto('first',3,[branch(q15,{'BulletsNumber':{'min':1}}),branch(q19,{'BulletsNumber':{'max':0}})])
 nodes['e2_first_locked']={**nodes['e2_first_3'],'source':'NewItem(19), closed door','blocks':[{'path':'Hist','text':'Цепи и замок не поддаются. Двери закрыты снаружи.','rect':[11,7,769,86],'font':'GraffitiC1 Medium','size':24}]};edge('e2_first_locked',[result(49)])
 cut('first',4,[branch('e2_first_6',{'LinkedFr':True}),branch('e2_first_5',{'LinkedFr':False})]);cut('first',11,['e2_first_5']);cut('first',12,['e2_first_5'])
 goto('first',5,[result(46)]);goto('first',8,[result(47)])
 q23=decision('first',9,23,['e2_first_10',result(49)]);goto('first',9,[q23]);goto('first',10,[result(48)])
 nodes['e2_first_10']['variants']=[{'when':{'LinkedFr':True},'blocks':nodes['e2_first_10_v2']['blocks']}]
 edge('e2_first_1_v2',['e2_first_2_v2']);edge('e2_first_1_v3',['e2_first_2']);edge('e2_first_2_v2',['e2_first_3'])
 # Roof route. Shooting through the crowd ends at the gunner's sights.
 q17=decision('roof',3,17,['e2_roof_4','e2_roof_8']);goto('roof',3,[branch(q17,{'BulletsNumber':{'min':1}}),branch('e2_roof_7',{'BulletsNumber':{'max':0}})])
 cut('roof',4,['e2_roof_5']);cut('roof',6,['e2_roof_12']);cut('roof',8,[branch('e2_roof_9',{'BulletsNumber':{'min':1}}),branch(result(37),{'BulletsNumber':{'max':0}})])
 goto('roof',11,[result(38)]);goto('roof',12,[result(39)])
 # Main hospital wing, SWAT team and second pistol.
 edge('e2_hall_1_v2',['e2_hall_2_v2']);edge('e2_hall_2_v2',['e2_hall_3'])
 q20=decision('hall',3,20,['e2_hall_7','e2_hall_8']);goto('hall',3,[branch('e2_hall_4',{'BulletsNumber':{'min':1}}),branch(q20,{'BulletsNumber':{'max':0}})])
 cut('hall',6,[result(40)]);goto('hall',7,['e2_main_1_v2']);goto('hall',9,[result(41)])
 cut('back',2,[branch('e2_main_1_v3',{'BulletsNumber':{'min':0}}),branch('e2_main_1',{'BulletsNumber':-1})])
 for id in ['e2_main_1','e2_main_1_v2','e2_main_1_v3']:
  edge(id,['e2_main_2','e2_lift_1_v2']);nodes[id]['choices'][0]['text']='Спуститься по лестнице';nodes[id]['choices'][1]['text']='Вызвать лифт'
 q21=decision('main',3,21,['e2_mark23','e2_main_4']);goto('main',3,[q21])
 q22=decision('main',7,22,['e2_main_11','e2_attack_1',{'next':'e2_main_8','requires':{'BulletsNumber':12},'add':{'BulletsNumber':-1}}]);goto('main',7,[q22])
 cut('main',11,[result(44)]);goto('main',10,[result(43)]);cut('attack',2,[result(42)])
 edge('e2_lift_1_v2',['e2_lift_2_v2']);cut('lift',3,[result(36)])
 nodes['e2_lift_3_v2']={**nodes['e2_lift_3'],'source':'LiftCall(2) frame 3','choices':[{'text':'Далее','next':result(45)}]}
 # These animations finish on a readable page; Flash waits for another tap.
 for cls,fr in [('hospital',10),('hospital',12),('hospital',20),('back',2),('first',4),('first',11),('first',12)]:
  nodes[nid(cls,fr)]['kind']='city_story';nodes[nid(cls,fr)].pop('auto_seconds',None)
 nodes['e2_roof_8']['variants']=[{'when':{'BulletsNumber':{'min':1}},'sound':'ZombieFallingOnDavidShooting'},{'when':{'BulletsNumber':{'max':0}},'sound':'ZombieFallingOnDavidKill'}]
 # Variant lift routes both enter the same automatic finale, carrying companion state.
 edge('e2_lift_2_v2',['e2_lift_3_v2'])
 # MovBoom(3), same explosion sequence used by Episode I.
 for fr in [4,5]:
  id='e2_boom_'+str(fr);nodes[id]={'episode':2,'source':'MovBoom(3) frame '+str(fr),'kind':'city_cutscene','art':'city_door_explosion' if fr==4 else 'city_explosion_flash','auto_seconds':1.6,'sound':'Explosion' if fr==4 else '','choices':[{'text':'Далее','next':'e2_boom_5' if fr==4 else result(35)}]}
 # End-state text variants are not separate routes unless explicitly targeted.
 reachable=set();pending=['e2_hospital_1']
 while pending:
  id=pending.pop()
  if id in reachable:continue
  if id not in nodes:raise ValueError('Missing route '+id)
  reachable.add(id)
  for c in nodes[id]['choices']:
   pending.append(c['next']);pending.extend(x['next'] for x in c.get('next_cases',[]))
  if nodes[id].get('pickup_if'):pending.append(nodes[id]['pickup_if']['next'])
 nodes={k:v for k,v in nodes.items() if k in reachable}
 # Original interactive arrows are exported separately so only one backdrop fills the screen.
 if render:
  fg=Renderer(library,art,fonts)
  for cls,fr in [('hospital',16),('main',1)]:
   key=nid(cls,fr)+'_controls';fg.render(key+'.png',[('Symbol '+str(CLASSES[cls]),fr-1,0,0,{}, {'Mov'})])
   for index in [1,2]:
    mask=key+'_hit_'+str(index)
    fg.render(mask+'.png',[('Symbol '+str(CLASSES[cls]),fr-1,0,0,{}, {'Mov','But'+str(3-index)})])
    with Image.open(art/(mask+'.png')) as im:
     bbox=im.getbbox()
     if bbox is None:raise ValueError('Empty arrow '+mask)
     cropped=im.crop(bbox);cropped.save(art/(mask+'.tmp'),format='PNG')
    os.replace(art/(mask+'.tmp'),art/(mask+'.png'))
    rect=[bbox[0]/2,bbox[1]/2,(bbox[2]-bbox[0])/2,(bbox[3]-bbox[1])/2]
    for id,n in nodes.items():
     if id.startswith(nid(cls,fr)) and n['kind']=='city_story':
      n['controls_art']=key
      for choice in n['choices']:
       if (index==1 and choice['text'] in ['Подняться на крышу','Спуститься по лестнице']) or (index==2 and choice['text'] in ['Идти в главную часть больницы','Вызвать лифт']):
        choice['rect']=rect;choice['mask']=mask
  for name,weapon in [('ep2_item_glock',2),('ep2_item_mark23',3)]:fg.render(name+'.png',[('Symbol 274',0,0,30,{'Weapons':weapon,'ButExit':1},{'Txt'})])
  fg.render('ep2_decision_4.png',[('Symbol 99',0,0,-18,{}, {'Txt','But1.Txt','But2.Txt','But3.Txt','But4.Txt'})])
 else:
  previous=json.loads((output/'data/episode2_routes.json').read_text())['nodes'] if (output/'data/episode2_routes.json').exists() else {}
  for id,node in nodes.items():
   if id in previous:
    for i,choice in enumerate(node['choices']):
     if i<len(previous[id]['choices']) and previous[id]['choices'][i].get('mask'):
      for key in ['rect','mask']:choice[key]=previous[id]['choices'][i][key]
  for cls,fr in [('hospital',16),('main',1)]:
   for id,n in nodes.items():
    if id.startswith(nid(cls,fr)) and n['kind']=='city_story':n['controls_art']=nid(cls,fr)+'_controls'
 if render:
  fg.render('ep2_continue_button.png',[('Symbol 8',1,67.05,360,{},set()),('Symbol 54',0,93,376,{},set())])
  sounds={n.get('sound','') for n in nodes.values()}|{'ZombieFallingOnDavidKill','ZombieFallingOnDavidShooting'}
  for sound in sounds:
   if sound and (photos.parent/'Sound'/(sound+'.mp3')).exists():
    target=output/'assets/audio'/(sound+'.mp3')
    if not target.exists():target.write_bytes((photos.parent/'Sound'/(sound+'.mp3')).read_bytes())
 output.joinpath('data/episode2_routes.json').write_text(json.dumps({'episode':2,'start':'e2_hospital_1','nodes':nodes},ensure_ascii=False,indent=2)+'\n')
 output.joinpath('data/episode2_visuals.json').write_text(json.dumps(visuals,ensure_ascii=False,indent=2)+'\n')
 print('Episode II:',len(nodes),'nodes;',len([n for n in nodes.values() if n.get('result_id')]),'results')

def main():
 parser=argparse.ArgumentParser();parser.add_argument('archive',type=Path);parser.add_argument('--output',type=Path,default=Path(__file__).resolve().parents[1]);parser.add_argument('--content-only',action='store_true');parser.add_argument('--reuse-art',action='store_true');args=parser.parse_args()
 with tempfile.TemporaryDirectory() as tmp:
  library=Path(tmp)/'LIBRARY';photos=Path(tmp)/'Images';library.mkdir();photos.mkdir();(Path(tmp)/'Sound').mkdir();sources={}
  with zipfile.ZipFile(args.archive) as z:
   for name in z.namelist():
    if '/ZombieApocalypse/LIBRARY/' in name and name.endswith(('.xml','.png','.jpg')):(library/Path(name).name).write_bytes(z.read(name))
    elif name.startswith('assets/Images/') and not name.endswith('/'):(photos/Path(name).name).write_bytes(z.read(name))
    elif name.startswith('assets/Sound/') and name.endswith('.mp3'):(Path(tmp)/'Sound'/Path(name).name).write_bytes(z.read(name))
    elif name.endswith('.as'):sources[Path(name).stem]=z.read(name).decode('utf-8-sig')
  build(library,photos,sources,args.output,not args.content_only,args.reuse_art)
if __name__=='__main__':main()
