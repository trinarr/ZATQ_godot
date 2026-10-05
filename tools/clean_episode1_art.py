"""Remove retired Episode I composites; keep live alpha masks. Dry-run by default."""
import argparse,json
from pathlib import Path
from story_graph_format import load_all
ROOT=Path(__file__).resolve().parents[1]
def retired(root):
 components=json.loads((root/'data/episode1_components.json').read_text())
 nodes=load_all(root)
 masks={c['mask'] for n in nodes.values() for c in n.get('choices',[]) if 'mask' in c}
 live={n[k] for n in nodes.values() for k in ['art','art_on_foot','controls_art','decision_art','background_art'] if k in n}
 candidates=[]
 for p in (root/'assets/flash_ui').glob('*.png'):
  key=p.stem
  replaced=key in components or key.removesuffix('_icons') in components
  old=key.startswith(('story_','tv_','layout_bg_','layout_controls_','city_','ep1_')) or key=='pause'
  if key not in masks and (replaced or (old and key not in live)):candidates.append(p)
 return candidates
if __name__=='__main__':
 p=argparse.ArgumentParser();p.add_argument('--apply',action='store_true');a=p.parse_args()
 files=retired(ROOT);size=sum(f.stat().st_size for f in files)
 for f in files:
  print(f.relative_to(ROOT))
  if a.apply:f.unlink();Path(str(f)+'.import').unlink(missing_ok=True)
 print(f'{len(files)} retired PNGs, {size} bytes')
