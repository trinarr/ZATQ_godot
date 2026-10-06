"""Restore Symbol276's header shadow without duplicating the shared Bitmap56 face.
Usage: python tools/build_item_popup_header.py /path/to/LIBRARY
The first 60 pixels already exist in result_alive/result_dead; only the tail is new.
"""
from pathlib import Path
import sys, json
from PIL import Image
ROOT = Path(__file__).resolve().parents[1]
def build(library):
    with Image.open(Path(library)/'Bitmap 56.png') as image:
        image.convert('RGBA').crop((0,60,729,82)).resize((1458,44),Image.Resampling.NEAREST).save(ROOT/'assets/flash_ui/components/panel_header_shadow_tail.png')
    header = next(p for p in json.loads((ROOT/'data/episode1_components.json').read_text())['result_alive'] if p.get('source') == '/Symbol 57')
    header = dict(header, rect=[35,0,729,60])
    tail = {'type':'texture','texture':'components/panel_header_shadow_tail.png','rect':[35,60,729,22],'source':'/Symbol 57 shadow tail','layer':'background'}
    (ROOT/'data/item_popup_components.json').write_text(json.dumps({'header':[header,tail]},ensure_ascii=False,indent=2)+'\n')
if __name__ == '__main__': build(sys.argv[1])
