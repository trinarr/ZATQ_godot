"""Migrate Episode II/III story glows and hit masks to shared vector contours.
Keep authored pose/opacity tracks, including static fallback frames. Never scan UI art.
"""
import argparse
import hashlib
import json
from pathlib import Path
import numpy as np
from PIL import Image
from build_episode1_highlights import contours, alpha_key
from build_episode1_components import shared_texture_references
ROOT = Path(__file__).resolve().parents[1]
SCENES = {
    2: ('e2_main_1_controls', 'e2_hospital_16_controls'),
    3: ('e3_opening_8', 'e3_opening_11', 'e3_john_6', 'e3_john_18',
        'e3_john_23', 'e3_john_28', 'e3_kill_6'),
}

def selected(art, episode):
    return any(art == name or art.startswith(name + '_anim_') for name in SCENES[episode])

def migrate(root=ROOT, episodes=(2, 3)):
    removed = set()
    for episode in episodes:
        path = root / f'data/episode{episode}_highlights.json'
        regions = json.loads(path.read_text()) if path.exists() else {'regions': {}, 'masks': {}}
        component_path = root / f'data/episode{episode}_components.json'
        animation_path = root / f'data/episode{episode}_animations.json'
        components = json.loads(component_path.read_text())
        animations = json.loads(animation_path.read_text()) if animation_path.exists() else {'art': {}}
        raster_regions = {}
        alpha_regions = {}
        count = 0

        def convert(part, animated):
            nonlocal count
            if part.get('type') != 'texture': return
            filename = part['texture']
            if filename not in raster_regions:
                with Image.open(root / 'assets/flash_ui' / filename) as raw:
                    im = raw.convert('RGBA')
                pixels = np.asarray(im)
                visible = pixels[pixels[:, :, 3] > 5].astype(float)
                if not len(visible): return
                red = (visible[:, 0] > visible[:, 1]*1.7) & (visible[:, 0] > visible[:, 2]*1.7) & (visible[:, 0] > 70)
                if np.mean(red) < .95: return
                peak = float(visible[:, 3].max())
                rgb = np.median(visible[red & (visible[:, 3] >= peak*.95), :3], axis=0)
                region = {'size': list(im.size), 'contours': contours(pixels[:, :, 3] >= peak*.2),
                          'color': [round(float(c)/255, 6) for c in rgb],
                          'alpha_min': peak/255, 'alpha_max': .80078125 if peak <= 128 else 1.0}
                assert region['contours'], filename
                rid = f'ep{episode}_region_' + hashlib.sha256(json.dumps(region, sort_keys=True).encode()).hexdigest()[:16]
                regions['regions'][rid] = region
                raster_regions[filename] = (rid, peak/255)
                alpha_regions[alpha_key(im)] = rid
            rid, opacity = raster_regions[filename]
            part.update(type='highlight', region=rid)
            # Snapshot PNG opacity is baked into alpha; animated PNG opacity is
            # combined with the MovieClip's color transform at runtime.
            if animated or episode == 3:
                part.update(timeline_alpha=True, opacity=opacity)
            part.pop('texture')
            removed.add(filename)
            count += 1

        for art, spec in animations['art'].items():
            if not selected(art, episode): continue
            for key, part in spec['parts'].items():
                convert(part, True)
                if part.get('type') == 'highlight':
                    assert all(record[2][4:] == [0, 0, 0] for phase in ['intro', 'outro'] for row in spec[phase] for record in row if record[0] == key), (art, key, 'unsupported additive color transform')
        for art, parts in components.items():
            if not selected(art, episode): continue
            for part in parts: convert(part, False)
        if episode == 2:
            for art in SCENES[2]:
                for mask in (root / 'assets/flash_ui').glob(art + '_hit_*.png'):
                    with Image.open(mask) as raw: rid = alpha_regions.get(alpha_key(raw.convert('RGBA')))
                    if rid is None:
                        assert mask.stem in regions['masks'], f'No matching contour for {mask}'
                        continue
                    regions['masks'][mask.stem] = rid
                    removed.add(mask.name)
        component_path.write_text(json.dumps(components, ensure_ascii=False, indent=2)+'\n')
        if animation_path.exists():
            animation_path.write_text(json.dumps(animations, separators=(',', ':'))+'\n')
        path.write_text(json.dumps(regions, separators=(',', ':'))+'\n')
        print(f'Episode {episode}: {count} layers converted, {len(regions["regions"])} contours, {len(regions["masks"])} hit regions')
    live = shared_texture_references(root)
    count = total = 0
    for filename in sorted(removed-live):
        file = root/'assets/flash_ui'/filename
        total += file.stat().st_size
        file.unlink()
        Path(str(file)+'.import').unlink(missing_ok=True)
        count += 1
    print(f'Retired {count} unused PNGs / {total} bytes')

if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', type=Path, default=ROOT)
    parser.add_argument('--episode', type=int, choices=[2, 3])
    args = parser.parse_args()
    migrate(args.output, (args.episode,) if args.episode else (2, 3))
