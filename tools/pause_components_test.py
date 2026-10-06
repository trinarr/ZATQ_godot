"""Audit the independent Flash pause parts and retirement of the composite."""
import hashlib
import json
from pathlib import Path
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
ART = ROOT / 'assets/flash_ui'
parts = json.loads((ROOT / 'data/pause_components.json').read_text())
textures = set()
for records in parts.values():
    assert len(records) == 1
    part = records[0]
    assert part['type'] == 'texture' and part['source']
    textures.add(part['texture'])
    with Image.open(ART / part['texture']) as image:
        image = image.convert('RGBA')
        assert image.getchannel('A').getbbox() == (0, 0, image.width, image.height)
        assert image.size == tuple(round(v*2) for v in part['rect'][2:])
        digest = hashlib.sha256(str(image.size).encode() + image.tobytes()).hexdigest()[:20]
        assert part['texture'].endswith('part_' + digest + '.png')
assert textures == {'pause_components/' + p.name for p in (ART / 'pause_components').glob('*.png')}
assert len(textures) == 8
assert parts['pause_resume_hit'][0]['rect'] == [0, -37.25, 70, 147]
for name in ['episode1_components', 'episode1_brushes', 'ui_brush_layout', 'ui_text_layout']:
    assert 'layout_pause' not in json.loads((ROOT / f'data/{name}.json').read_text())
assert not (ART / 'episode1_components/part_cb95175da5f876a8d557.png').exists()
print('PASS: eight complete independent pause textures, original hit state, retired composite')
