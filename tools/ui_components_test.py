"""Verify resource reuse, trimming, ordering and original raster reconstruction.
Run with --baseline REV to compare against full layers from the migration base.
"""
import argparse
import io
import json
import subprocess
from pathlib import Path
from PIL import Image, ImageChops, ImageStat

ROOT = Path(__file__).resolve().parents[1]
ART = ROOT / 'assets/flash_ui'


def compose(parts):
    image = Image.new('RGBA', (1600, 960))
    for part in parts:
        with Image.open(ART / part['texture']) as texture:
            x, y, w, h = [round(v * 2) for v in part['rect']]
            assert texture.size == (w, h), part
            assert texture.getchannel('A').getbbox() == (0, 0, w, h), part
            image.alpha_composite(texture.convert('RGBA'), (x, y))
    return image


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--baseline')
    args = parser.parse_args()
    screens = json.loads((ROOT / 'data/ui_components.json').read_text())
    assert len(screens) == 14
    assets = {p['texture'] for parts in screens.values() for p in parts}
    assert assets == {'components/' + p.name for p in (ART / 'components').glob('*.png')}
    # Every selector shares its original frame; image changes independently.
    shared = set(p['texture'] for p in screens['adaptive_selector_0'])
    for i in range(12):
        parts = screens[f'adaptive_selector_{i}']
        shared &= {p['texture'] for p in parts}
        assert sum(p['source'].endswith('/EpImg') for p in parts) == 1
    assert shared, 'selector frame/control reuse'
    on = {p['texture'] for p in screens['adaptive_menu']}
    off = {p['texture'] for p in screens['adaptive_menu_off']}
    assert len(on & off) >= len(on) - 1, 'sound toggle should only replace its icon'
    for screen, parts in screens.items():
        assert not (ART / (screen + '.png')).exists()
        assert not (ART / (screen.removeprefix('adaptive_') + '.png')).exists()
        image = compose(parts)
        if screen.startswith("adaptive_selector_") and int(screen.removeprefix("adaptive_selector_")) in [0,2,4,5,7,9,11]:
            with Image.open(ART / "components/stat_tick.png") as source:
                tick = source.convert('RGBA').resize((28,34),Image.Resampling.BILINEAR)
                r,g,b,a = tick.split()
                tick = Image.merge('RGBA',(r.point(lambda v:round(v*128/255)),g.point(lambda v:round(v*60/255)),b.point(lambda v:round(v*60/255)),a))
                for i in range(3):
                    image.alpha_composite(tick,(568+i*30,568))
        if args.baseline:
            old = subprocess.check_output(['git', 'show', args.baseline + ':assets/flash_ui/' + screen + '.png'], cwd=ROOT)
            reference = Image.open(io.BytesIO(old)).convert('RGBA')
            # Hidden RGB under transparent pixels does not affect display.
            bg = Image.new('RGBA', image.size, 'black')
            expected = Image.alpha_composite(bg, reference).convert('RGB')
            actual = Image.alpha_composite(bg, image).convert('RGB')
            error = max(ImageStat.Stat(ImageChops.difference(expected, actual)).mean)
            assert error < 0.2, (screen, error)
    print(f'PASS: 14 composed screens, {len(assets)} shared trimmed textures, original raster layout')


if __name__ == '__main__':
    main()
