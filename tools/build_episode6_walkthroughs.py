"""Enumerate all authored Episode VI routes and result states."""
import json
from collections import deque
from pathlib import Path
from story_graph_format import compile_graph
ROOT=Path(__file__).resolve().parents[1]
def build():
 graph=json.loads((ROOT/"data/story_graphs/episode6.json").read_text());nodes=compile_graph(graph)
 todo=deque([(graph["start"],[])]);seen=set();states={};results={}
 while todo:
  id,route=todo.popleft()
  if id in seen:continue
  seen.add(id);states[id]=[{}];node=nodes[id]
  if node.get("result_id"):results[id]={"choices":route};continue
  todo.extend((c["next"],route+[index]) for index,c in enumerate(node["choices"]))
 assert set(results)=={f"e6_result_{n}" for n in range(137,162) if n!=150},set(results)
 assert seen==set(nodes),set(nodes)-seen
 (ROOT/"data/episode6_walkthroughs.json").write_text(json.dumps({"results":results,"states":states},ensure_ascii=False,indent=2)+"\n")
 print(len(states),"states;",len(results),"results")
if __name__=="__main__":build()
