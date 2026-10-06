"""Extract the original PauseMov parts; run with the original Flash ZIP.

Symbol 83: Grey (82), Butns (70); buttons 65, central button 79.
Bitmap 60 contains four baked shadows. Partition its rows without changing
pixels so each button owns its shadow and the assembled image stays exact.
"""
import argparse
import json
import tempfile
import zipfile
from pathlib import Path

from PIL import Image
from build_episode1_components import Exporter

ROOT = Path(__file__).resolve().parents[1]
BUTTONS = [('row_1', 0, 13), ('row_2', 54, 79),
           ('row_3', 54, 144), ('row_4', 10, 210)]


def build(archive, root=ROOT):
    destination = root / 'assets/flash_ui/pause_components'
    destination.mkdir(exist_ok=True)
    with tempfile.TemporaryDirectory() as tmp:
        tmp = Path(tmp)
        library = tmp / 'LIBRARY'
        library.mkdir()
        with zipfile.ZipFile(archive) as z:
            for name in z.namelist():
                if '/ZombieApocalypse/LIBRARY/' in name and name.endswith(('.xml', '.png', '.jpg')):
                    (library / Path(name).name).write_bytes(z.read(name))
        r = Exporter(library, destination, root / 'fonts/flash')
        r.scratch = tmp
        r.photos = tmp
        r.raster_cache = {}
        r.omit_brushes = True
        def symbol(number, frame=0, y=0, hide=()):
            return r.screen('pause', [(f'Symbol {number}', frame, 0, y, {}, hide)])
        # Reverse display order: drum bitmap first, arrow bitmap last.
        drum, arrow = symbol(82, hide=['ButMid'])
        arrow['rect'][1] -= 130.95
        parts = {'pause_drum': [drum], 'pause_arrow': [arrow],
                 'pause_resume': symbol(74),
                 'pause_resume_hit': symbol(79, 4, 37.25)}
        for p in parts['pause_resume_hit']:
            p['rect'][1] -= 37.25
        # Bitmap 60 is positioned at (-4, 0) within Butns.
        with Image.open(library / 'Bitmap 60.png') as source:
            source = source.convert('RGBA').resize((718, 586), Image.Resampling.BICUBIC)
            rows = [0, 72, 138, 203, 293]
            for i, (name, x, y) in enumerate(BUTTONS):
                top, bottom = rows[i:i+2]
                p = r.store(source.crop((0, top*2, 718, bottom*2)))
                p['rect'][0] -= 4 + x
                p['rect'][1] += top - y
                p['source'] = f'Butns/Symbol 70/Bitmap 60.png rows {top}:{bottom}'
                parts['pause_' + name + '_shadow'] = [p]
        for records in parts.values():
            for p in records:
                p['layer'] = 'background'
        (root / 'data/pause_components.json').write_text(json.dumps(parts, ensure_ascii=False, indent=2)+'\n')
        used = {p['texture'].split('/')[-1] for records in parts.values() for p in records}
        for path in destination.glob('*.png'):
            if path.name not in used:
                path.unlink()
                Path(str(path)+'.import').unlink(missing_ok=True)
    # Retire the old composite and its shader layout. The component owns the
    # individual shader backgrounds and localized labels now.
    for name in ['episode1_components', 'episode1_brushes', 'ui_brush_layout', 'ui_text_layout']:
        path = root / f'data/{name}.json'
        data = json.loads(path.read_text())
        old = data.pop('layout_pause', [])
        path.write_text(json.dumps(data, ensure_ascii=False, indent=2)+'\n')
        if name == 'episode1_components':
            used = {p.get('texture') for records in data.values() for p in records}
            for p in old:
                if p.get('texture') and p['texture'] not in used:
                    image = root / 'assets/flash_ui' / p['texture']
                    image.unlink(missing_ok=True)
                    Path(str(image)+'.import').unlink(missing_ok=True)
    print(f'PASS: {len(parts)} independent pause part sets')


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('archive', type=Path)
    args = parser.parse_args()
    build(args.archive)
