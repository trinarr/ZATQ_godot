"""Compare exported timing to original XFL and preserve the removed Exit caption.
Usage: python tools/menu_animations_source_test.py /path/to/XFL/LIBRARY
"""
import argparse
import json
from pathlib import Path
from build_menu_animations import ROOT, extract
from build_localized_ui import CleanRenderer, labels, brushes

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('library', type=Path)
args = parser.parse_args()
assert extract(args.library) == json.loads((ROOT / 'data/menu_animations.json').read_text())
r = CleanRenderer(args.library, ROOT / 'assets/flash_ui', ROOT / 'fonts/flash')
for sound_frame in [0, 1]:
    hidden = {'But4'}
    ov = {'SndCheck': sound_frame}
    captions = labels(r, 'Symbol 118', 0, ov, hidden)
    # MenuMov's text fields are siblings of the buttons. The first is Exit;
    # build_localized_ui removes it before assigning stable locale IDs 1..3.
    assert len(captions) == 4 and captions[0]['rect'][1] == 236
    assert [b['text'] for b in captions[1:]] == ['справка', 'Тесты', 'Эпизоды']
    assert len(brushes(r, 'Symbol 118', 0, ov, hidden)) == 5
print('PASS: exported alpha/positions match original XFL; retained menu captions verified')
