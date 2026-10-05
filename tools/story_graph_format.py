"""Read the canonical visual graph for offline content/resource audits."""
import json
import csv
from functools import lru_cache
from pathlib import Path
SCREENS={'scene','dialogue','code','qte'}
def compile_graph(graph):
    nodes=graph['nodes'];edges=graph['edges'];connections={}
    for edge in edges:
        assert edge['from'] in nodes and edge['to'] in nodes,edge
        key=(edge['from'],edge['port'])
        assert key not in connections,key
        connections[key]=edge['to']
    def target(id,p):return connections.get((id,p))
    def ports(id,p):return sorted((port for (source,port) in connections if source==id and port.startswith(p)),key=lambda port:int(port.split(':')[1]))
    def payload(id):return json.loads(json.dumps(nodes[id]['data']))
    assert graph['start'] in nodes
    result={}
    for id,record in nodes.items():
        if record['type'] not in SCREENS:continue
        data=payload(id)
        if record['type']!='scene':data['kind']='activity_'+record['type']
        if graph['episode']!=1 or record['type']!='scene':data['episode']=graph['episode']
        data['choices']=[]
        if entry:=target(id,'entry'):
            data['set']=payload(entry).get('set',{})
            if payload(entry).get('add'):data['add']=payload(entry)['add']
        if gate:=target(id,'pickup'):data['pickup_if']={'when':payload(gate).get('when',{}),'next':target(gate,'true')}
        if variants:=ports(id,'variant:'):
            data['variants']=[]
            for port in variants:
                v=payload(target(id,port));patch=v.get('patch',{});patch['when']=v.get('when',{});data['variants'].append(patch)
        if back:=target(id,'back'):data['back']=back
        for port in ports(id,'choice:'):
            cid=target(id,port);choice=payload(cid)
            for route in ['next','with_keys','by_car']:
                if t:=target(cid,route):choice[route]=t
            if action:=target(cid,'effects'):choice.update(payload(action))
            if requires:=target(cid,'requires'):
                req=payload(requires)
                if req.get('when'):choice['requires']=req['when']
                if req.get('unless_keys'):choice['unless_keys']=True
            if routes:=ports(cid,'route:'):choice['next_cases']=[{'when':payload(target(cid,r)).get('when',{}),'next':target(target(cid,r),'true')} for r in routes]
            data['choices'].append(choice)
        result[id]=data
    return resolve_tree(result)

@lru_cache(maxsize=None)
def table_rows(namespace):
    path=Path(__file__).resolve().parents[1]/'locales'/(namespace+'.csv')
    with path.open(newline='',encoding='utf-8-sig') as f:
        return {r['key']:r['ru'] for r in csv.DictReader(f)}

def resolve_tree(value):
    if isinstance(value,str) and value.startswith("@loc:"):
        key=value[5:]
        return table_rows(key.split(".")[0]).get(key,key)
    if isinstance(value,dict):return {k:resolve_tree(v) for k,v in value.items()}
    if isinstance(value,list):return [resolve_tree(v) for v in value]
    return value

def load_all(root):
    result={}
    for path in sorted((Path(root)/'data/story_graphs').glob('episode*.json')):
        result.update(compile_graph(json.loads(path.read_text())))
    return result
