"""Enumerate Episode V choices under equipment/password conditions."""
import copy,json
from collections import deque
from pathlib import Path
from story_graph_format import compile_graph
ROOT=Path(__file__).resolve().parents[1]
def build():
 graph=json.loads((ROOT/'data/story_graphs/episode5.json').read_text());nodes=compile_graph(graph)
 def match(flags,when):return all(flags.get(k)==v for k,v in when.items())
 todo=deque([(graph['start'],graph['variables'],[])]);seen=set();states={};results={}
 while todo:
  id,flags,route=todo.popleft();node=copy.deepcopy(nodes[id]);flags=flags|node.get('set',{})
  key=(id,flags['TakenDocs'],flags['TakenArmor'],flags['CabinCodeKnown'])
  if key in seen:continue
  seen.add(key);states.setdefault(id,[]).append(flags)
  if node.get('result_id'):results.setdefault(id,{'choices':route});continue
  for variant in node.get('variants',[]):
   if match(flags,variant['when']):node.update({k:v for k,v in variant.items() if k!='when'})
  choices=[c for c in node['choices'] if match(flags,c.get('requires',{}))]
  for index,c in enumerate(choices):
   flags2=flags|c.get('set',{});dest=c['next']
   for case in c.get('next_cases',[]):
    if match(flags2,case['when']):dest=case['next'];break
   todo.append((dest,flags2,route+[index]))
 assert set(results)=={f'e5_result_{n}' for n in range(114,137)},set(results)
 assert set(states)==set(nodes),set(nodes)-set(states)
 (ROOT/'data/episode5_walkthroughs.json').write_text(json.dumps({'results':results,'states':states},ensure_ascii=False,indent=2)+'\n')
 print(len(states),'states;',len(results),'results;',len(seen),'conditional states')
if __name__=='__main__':build()
