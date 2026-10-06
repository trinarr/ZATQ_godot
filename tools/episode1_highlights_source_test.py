"""Compare Godot-generated contour masks with the pre-migration PNGs.
Run episode1_highlights_test.gd first, then this script before committing,
or pass --baseline-ref with the pre-migration commit.
"""
import argparse
import io
import json
import subprocess
from pathlib import Path
import numpy as np
from PIL import Image
from build_episode1_highlights import ROOT

p=argparse.ArgumentParser(description=__doc__);p.add_argument('--baseline-ref',default='HEAD');args=p.parse_args()
def original(name):
    return subprocess.check_output(['git','show',args.baseline_ref+':'+name],cwd=ROOT)
old=json.loads(original('data/episode1_components.json'))
new=json.loads((ROOT/'data/episode1_components.json').read_text())
data=json.loads((ROOT/'data/episode1_highlights.json').read_text())
seen=set();minimum=1.0
for name,parts in old.items():
    assert len(parts)==len(new[name])
    for before,after in zip(parts,new[name]):
        if after['type']!='highlight':continue
        assert before['rect']==after['rect'] and before['source']==after['source']
        if before['type']!='texture' or after['region'] in seen:continue
        seen.add(after['region'])
        image=Image.open(io.BytesIO(original('assets/flash_ui/'+before['texture']))).convert('RGBA')
        a=np.asarray(image);alpha=a[:,:,3];expected=alpha>=alpha.max()*.2
        generated=np.asarray(Image.open('/tmp/zatq_'+after['region']+'.png').convert('RGBA'))[:,:,3]>=128
        iou=np.sum(expected & generated)/np.sum(expected | generated)
        assert iou>.995,(name,iou)
        minimum=min(minimum,iou)
        region=data['regions'][after['region']]
        assert abs(region['alpha_min']-alpha.max()/255)<1e-6
        v=a[(alpha>=alpha.max()*.95)].astype(float)
        red=(v[:,0]>v[:,1]*1.7)&(v[:,0]>v[:,2]*1.7)&(v[:,0]>70)
        assert np.max(np.abs(np.asarray(region['color'])*255-np.median(v[red,:3],axis=0)))<.001
        assert not (ROOT/'assets/flash_ui'/before['texture']).exists()
for mask in data['masks']:assert not (ROOT/'assets/flash_ui'/(mask+'.png')).exists()
assert len(seen)==14
print(f'PASS: 14 silhouettes match originals; minimum intersection/union {minimum:.4%}; colors/geometry/alpha retained; no overlay PNGs')
