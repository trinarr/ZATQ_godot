"""Lossless migration of Flash-derived routes to the canonical visual story graph.
Run before editing graphs; later graph files are the source of truth.
"""
import json, argparse
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
def migrate(episode, routes):
 graph={'version':1,'episode':episode,'start':'wake' if episode==1 else 'e2_hospital_1','nodes':{},'edges':[]}
 nodes=graph['nodes'];edges=graph['edges']
 def put(id,kind,data,pos,title=''):
  nodes[id]={'type':kind,'data':data,'position':pos,'title':title or id}
 def link(a,p,b):edges.append({'from':a,'port':p,'to':b})
 for index,(id,src) in enumerate(routes.items()):
  x=(index//10)*1550;y=(index%10)*460
  data={k:v for k,v in src.items() if k not in ['choices','set','add','variants','pickup_if','back']}
  put(id,'scene',data,[x,y],id)
  if 'back' in src:link(id,'back',src['back'])
  if 'set' in src or 'add' in src:
   aid=id+'__entry';put(aid,'action',{k:src[k] for k in ['set','add'] if k in src},[x+360,y-120],'При входе');link(id,'entry',aid)
  if 'pickup_if' in src:
   cid=id+'__pickup';put(cid,'condition',{'when':src['pickup_if']['when']},[x+360,y-230],'Получение предмета');link(id,'pickup',cid);link(cid,'true',src['pickup_if']['next'])
  for vi,v in enumerate(src.get('variants',[])):
   cid=id+'__variant_'+str(vi);put(cid,'condition',{'when':v['when'],'patch':{k:val for k,val in v.items() if k!='when'}},[x-380,y+vi*120],'Вариант сцены');link(id,'variant:'+str(vi),cid)
  for ci,c in enumerate(src.get('choices',[])):
   cid=id+'__choice_'+str(ci);cx=x+420;cy=y+ci*140
   put(cid,'choice',{k:v for k,v in c.items() if k not in ['next','set','add','requires','next_cases','with_keys','by_car','unless_keys']},[cx,cy],c.get('text','Далее'));link(id,'choice:'+str(ci),cid)
   if 'next' in c:link(cid,'next',c['next'])
   for p in ['with_keys','by_car']:
    if p in c:link(cid,p,c[p])
   if 'set' in c or 'add' in c:
    aid=cid+'__effects';put(aid,'action',{k:c[k] for k in ['set','add'] if k in c},[cx+400,cy+90],'Последствия выбора');link(cid,'effects',aid)
   if 'requires' in c or 'unless_keys' in c:
    rid=cid+'__requires';d={'when':c.get('requires',{})}
    if c.get('unless_keys'):d['unless_keys']=True
    put(rid,'condition',d,[cx+400,cy-80],'Доступность ответа');link(cid,'requires',rid)
   for ri,r in enumerate(c.get('next_cases',[])):
    rid=cid+'__route_'+str(ri);put(rid,'condition',{'when':r['when']},[cx+800,cy+ri*110],'Условный переход');link(cid,'route:'+str(ri),rid);link(rid,'true',r['next'])
 return graph

def main():
 parser=argparse.ArgumentParser();parser.add_argument("--force",action="store_true");args=parser.parse_args()
 ep1={}
 for f in ['opening','city_routes','episode1_routes']:ep1.update(json.loads((ROOT/'data'/f'{f}.json').read_text())['nodes'])
 ep2=json.loads((ROOT/'data/episode2_routes.json').read_text())['nodes']
 for ep,nodes in [(1,ep1),(2,ep2)]:
  graph=migrate(ep,nodes)
  path=ROOT/'data/story_graphs'/f'episode{ep}.json'
  if path.exists() and not args.force:raise SystemExit('Graph exists; use --force only to discard authored edits: '+str(path))
  path.parent.mkdir(parents=True,exist_ok=True)
  path.write_text(json.dumps(graph,ensure_ascii=False,indent=2)+'\n')
  print(ep,len(nodes),'scenes',len(graph['nodes']),'graph blocks')
if __name__=='__main__':main()
