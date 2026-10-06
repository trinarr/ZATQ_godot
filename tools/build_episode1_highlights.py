"""Replace Episode I red overlays and duplicated hit PNGs with contour data.
Run after build_episode1_components.py. Pillow and numpy are exporter dependencies.
Contours use the existing 2x authoring coordinates; holes use even-odd filling.
"""
import argparse
import hashlib
import json
from pathlib import Path
import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]


def simplify(points, tolerance=.6):
    def rdp(p):
        if len(p) < 3: return p
        a, b = np.asarray(p[0], float), np.asarray(p[-1], float)
        v = b-a
        q = np.asarray(p, float)-a
        distances = np.linalg.norm(q, axis=1) if not np.dot(v,v) else np.abs(v[0]*q[:,1]-v[1]*q[:,0])/np.linalg.norm(v)
        i = int(np.argmax(distances))
        if distances[i] <= tolerance: return [p[0],p[-1]]
        return rdp(p[:i+1])[:-1]+rdp(p[i:])
    if len(points) < 4: return points
    split = int(np.argmax(np.linalg.norm(np.asarray(points)-points[0],axis=1)))
    return rdp(points[:split+1])[:-1]+rdp(points[split:]+[points[0]])[:-1]


def contours(mask):
    padded = np.pad(mask,1)
    sides = [mask & ~padded[:-2,1:-1], mask & ~padded[1:-1,2:],
             mask & ~padded[2:,1:-1], mask & ~padded[1:-1,:-2]]
    edges = {}
    for side, cells in enumerate(sides):
        ys,xs=np.nonzero(cells)
        for x,y in zip(xs.tolist(),ys.tolist()):
            a,b=[((x,y),(x+1,y)),((x+1,y),(x+1,y+1)),
                 ((x+1,y+1),(x,y+1)),((x,y+1),(x,y))][side]
            edges.setdefault(a,[]).append((b,side))
    rings=[]
    while edges:
        start=next(iter(edges));point=start;direction=0;ring=[]
        while True:
            ring.append(point)
            options=edges[point]
            # Right turn keeps diagonally touching islands as separate rings.
            end,side=min(options,key=lambda e:{1:0,0:1,3:2,2:3}[(e[1]-direction)%4])
            options.remove((end,side))
            if not options:del edges[point]
            point=end;direction=side
            if point==start:break
        area=abs(sum(ring[i][0]*ring[(i+1)%len(ring)][1]-ring[(i+1)%len(ring)][0]*ring[i][1] for i in range(len(ring))))/2
        if area>=2:
            ring=simplify(ring)
            if len(ring)>=3:rings.append([c for p in ring for c in p])
    return rings


def alpha_key(image):
    return hashlib.sha256(str(image.size).encode()+image.getchannel('A').tobytes()).hexdigest()


def migrate(root=ROOT):
    path=root/'data/episode1_components.json'
    catalog=json.loads(path.read_text())
    target=root/'data/episode1_highlights.json'
    data=json.loads(target.read_text()) if target.exists() else {'regions':{},'masks':{}}
    removed=set(); alpha_ids={}; replacements={}
    for records in catalog.values():
        for part in records:
            if part['type']=='panel' and part['color'][0]>.3 and part['color'][1]<.05 and part['color'][2]<.05:
                w,h=[round(v*2) for v in part['rect'][2:]]
                region={'size':[w,h],'contours':[[0,0,w,0,w,h,0,h]],'color':part['color'][:3], 'alpha_min':part['color'][3],'alpha_max':1.0}
            elif part['type']=='texture':
                texture=part['texture']
                if texture in replacements:
                    part.update(replacements[texture]);part.pop('texture',None);continue
                with Image.open(root/'assets/flash_ui'/texture) as raw:im=raw.convert('RGBA')
                a=np.asarray(im);v=a[a[:,:,3]>5].astype(float)
                if not len(v) or v[:,3].max()>160:continue
                red=(v[:,0]>v[:,1]*1.7)&(v[:,0]>v[:,2]*1.7)&(v[:,0]>70)
                if np.mean(red)<.95:continue
                peak=int(v[:,3].max()); rgb=np.median(v[red & (v[:,3]>=peak*.95),:3],axis=0)
                region={'size':list(im.size),'contours':contours(a[:,:,3]>=peak*.2),
                        'color':[round(float(c)/255,6) for c in rgb],
                        'alpha_min':peak/255,'alpha_max':.80078125 if peak<=128 else 1.0}
                removed.add(texture)
            else:continue
            key='region_'+hashlib.sha256(json.dumps(region,sort_keys=True).encode()).hexdigest()[:16]
            data['regions'][key]=region
            if part['type']=='texture':
                alpha_ids[alpha_key(im)]=key
                replacements[part['texture']]={'type':'highlight','region':key}
            part['type']='highlight';part['region']=key;part.pop('texture',None);part.pop('color',None)
    # Keep existing graph identifiers and replace their PNG dependency internally.
    for file in (root/'assets/flash_ui').glob('ep1_hit_*.png'):
        with Image.open(file) as raw:im=raw.convert('RGBA')
        key=alpha_ids.get(alpha_key(im))
        if key is None:raise ValueError('Hit PNG does not match a recovered overlay: '+file.name)
        data['masks'][file.stem]=key
        removed.add(str(file.relative_to(root/'assets/flash_ui')))
    path.write_text(json.dumps(catalog,ensure_ascii=False,indent=2)+'\n')
    target.write_text(json.dumps(data,separators=(',',':'))+'\n')
    other=set()
    for p in (root/'data').glob('*components.json'):
        other.update(v.get('texture') for ps in json.loads(p.read_text()).values() for v in ps)
    total=0
    for name in sorted(removed-other):
        file=root/'assets/flash_ui'/name
        total+=file.stat().st_size
        file.unlink();Path(str(file)+'.import').unlink(missing_ok=True)
    print(f'PASS: {len(data["regions"])} vector highlights, {len(data["masks"])} shared hit regions; retired {len(removed-other)} PNGs / {total} bytes')


if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--output',type=Path,default=ROOT)
    migrate(parser.parse_args().output)
