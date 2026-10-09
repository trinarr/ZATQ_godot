"""Audit tracked runtime art, fonts and import sidecars, including graph-driven loads.

Migration catalogs and exporter source metadata are deliberately not runtime roots.
Run after exporting components to catch abandoned textures and temporary files.
"""
import json
import re
import subprocess
from pathlib import Path
from story_graph_format import load_all

ROOT = Path(__file__).resolve().parents[1]


def dictionaries(value):
    if isinstance(value, dict):
        yield value
        for child in value.values():
            yield from dictionaries(child)
    elif isinstance(value, list):
        for child in value:
            yield from dictionaries(child)


def audit(root=ROOT):
    tracked = set(subprocess.check_output(['git', 'ls-files'], cwd=root, text=True).splitlines())
    resources = set()
    components = {}
    for path in (root / 'data').glob('*components.json'):
        catalog = json.loads(path.read_text())
        components.update(catalog)
        for parts in catalog.values():
            resources.update('assets/flash_ui/' + p['texture'] for p in parts if 'texture' in p)
    animated_art = set()
    for animation_path in (root / 'data').glob('episode*_animations.json'):
        artworks = json.loads(animation_path.read_text()).get('art', {})
        animated_art.update(artworks)
        for artwork in artworks.values():
            resources.update('assets/flash_ui/' + p['texture'] for p in artwork['parts'].values() if 'texture' in p)
    text = json.loads((root / 'data/ui_text_layout.json').read_text())
    resources.update(("fonts/caveat/Caveat-Medium.ttf" if int(block['font']) in [2508,2511] else "fonts/oswald/Oswald-Medium.ttf" if int(block['font'])==2 else "fonts/dseg/DSEG7Classic-Regular.ttf" if int(block['font'])==2836 else f"fonts/flash/font_{int(block['font'])}.ttf") for block in dictionaries(text) if 'font' in block)
    dynamic_masks = {}
    for highlight_path in (root / 'data').glob('episode*_highlights.json'):
        definition = json.loads(highlight_path.read_text())
        dynamic_masks.update(definition.get('masks', {}))
        dynamic_masks.update(definition.get('regions', {}))
    nodes = load_all(root)
    for record in dictionaries(nodes):
        for key in ['art', 'art_on_foot', 'controls_art', 'decision_art', 'background_art', 'selector_art']:
            if key in record and record[key] not in components and record[key] not in animated_art:
                name = record[key]
                resources.add('assets/flash_ui/' + name + '.png')
                icons = 'assets/flash_ui/' + name + '_icons.png'
                if icons in tracked:
                    resources.add(icons)
        for name in record.get('animation_frames', []):
            if name not in components and name not in animated_art:
                resources.add('assets/flash_ui/' + name + '.png')
        if 'mask' in record and record['mask'] not in dynamic_masks:
            resources.add('assets/flash_ui/' + record['mask'] + '.png')
        if 'sound' in record and record['sound']:
            resources.add('assets/audio/' + record['sound'] + '.mp3')
    # Main's shared primitives use fixed UI names as well as graph art names.
    resources.update('assets/flash_ui/' + name + '.png' for name in ['adaptive_help', 'adaptive_help_icons'])
    for path in list((root / 'scripts').rglob('*.gd')) + list((root / 'scenes').rglob('*.tscn')) + list((root / 'shaders').rglob('*.gdshader')):
        resources.update(name for name in re.findall(r'res://((?:assets|fonts)/[^"\n]+\.(?:png|jpg|mp3|ttf))"', path.read_text()) if '%' not in name)
    # Keypad sounds are emitted by shared controls rather than stored in graphs.
    for path in (root / 'scripts').rglob('*.gd'):
        resources.update('assets/audio/' + name + '.mp3' for name in re.findall(r'sound_requested.emit\("([^"\n]+)"', path.read_text()))
    for graph_path in (root / 'data/story_graphs').rglob('*.json'):
        resources.update(re.findall(r'res://((?:assets|fonts)/[^"\n]+\.(?:png|jpg|mp3|ttf))"', graph_path.read_text()))
    candidates = {p for p in tracked if p.startswith(('assets/', 'fonts/')) and not p.endswith('.import') and (root / p).is_file()}
    # Font licensing files follow the font's lifetime; preserve all remaining licenses.
    if 'fonts/RobotoFlex-Variable.ttf' in resources:
        resources.add('fonts/RobotoFlex-OFL.txt')
    resources.update(p for p in candidates if p.endswith('.txt') and p != 'fonts/RobotoFlex-OFL.txt')
    unused = sorted(candidates - resources)
    missing = sorted(p for p in resources if not (root / p).is_file())
    orphan_imports = sorted(p for p in tracked if p.endswith('.import') and (root / p).is_file() and not (root / p[:-7]).is_file())
    return unused, missing, orphan_imports


if __name__ == '__main__':
    unused, missing, imports = audit()
    for label, paths in [('Unused resource', unused), ('Missing resource', missing), ('Orphan import', imports)]:
        for path in paths:
            print(f'{label}: {path}')
    print(f'{len(unused)} unused resources, {len(missing)} missing resources, {len(imports)} orphan imports')
    raise SystemExit(bool(unused or missing or imports))
