"""Export Flash display-list children as trimmed, shared Godot textures.

Text and brush fills stay native. Positions use Flash coordinates; no runtime
Flash interpreter is required. Identical RGBA payloads share a single resource.
"""
import copy
import hashlib
import json
import tempfile
import xml.etree.ElementTree as ET
from pathlib import Path
from PIL import Image
from render_flash_ui import NS


def is_component_screen(name):
    return name in ('adaptive_menu', 'adaptive_menu_off') or name.startswith('adaptive_selector_')


def menu_plans():
    def s(n, f=0, x=0, y=0, o=None, h=None):
        return (f'Symbol {n}', f, x, y, o or {}, h or set())
    plans = {'adaptive_menu': [s(118), s(132, 8, 415, 70)],
             'adaptive_menu_off': [s(118, o={'SndCheck': 1}), s(132, 8, 415, 70)]}
    for i in range(12):
        plans[f'adaptive_selector_{i}'] = [s(211, o={
            'EpImg': i, 'LeftOpt': 2 if i in [1, 3, 6, 8, 10] else 0,
            'RightOpt': 1 if i in [1, 3, 6, 8, 10] else 0,
            'But3': 1, 'But4': 1, 'But1': 1, 'But2': 1},
            h={'NameTxt', 'EpOptions', 'InfoOpt', 'AnsNumb', 'txtWins', 'txtLoses'})]
    return plans


def export_components(renderer, plans, root):
    root = Path(root)
    destination = root / 'assets/flash_ui/components'
    destination.mkdir(parents=True, exist_ok=True)
    manifest = {}
    used = set()
    original_output = renderer.out
    with tempfile.TemporaryDirectory() as tmp:
        renderer.out = Path(tmp)
        for screen, items in plans.items():
            if not is_component_screen(screen):
                continue
            parts = []
            for symbol, frame, x, y, overrides, hidden in items:
                frame = renderer.display_frame(symbol, frame)
                layers = renderer.root(symbol).findall('./x:timeline/x:DOMTimeline/x:layers/x:DOMLayer', NS)
                # Same bottom-to-top ordering as the original renderer.
                for layer in reversed(layers):
                    frames = [f for f in layer.findall('x:frames/x:DOMFrame', NS)
                              if int(f.get('index', '0')) <= frame]
                    if not frames:
                        continue
                    for element in frames[-1].findall('x:elements/*', NS):
                        if element.tag.endswith(('DOMStaticText', 'DOMDynamicText')):
                            continue
                        # Render one original child with its transform, opacity,
                        # selected frame and inherited hide/override rules intact.
                        document = ET.Element('DOMSymbolItem')
                        timeline = ET.SubElement(ET.SubElement(document, '{%s}timeline' % NS['x']), '{%s}DOMTimeline' % NS['x'])
                        ls = ET.SubElement(timeline, '{%s}layers' % NS['x'])
                        l = ET.SubElement(ls, '{%s}DOMLayer' % NS['x'])
                        fs = ET.SubElement(l, '{%s}frames' % NS['x'])
                        f = ET.SubElement(fs, '{%s}DOMFrame' % NS['x'], index='0')
                        es = ET.SubElement(f, '{%s}elements' % NS['x'])
                        es.append(copy.deepcopy(element))
                        renderer.cache['__component__'] = document
                        renderer.render('part.png', [('__component__', 0, x, y, overrides, hidden)])
                        with Image.open(renderer.out / 'part.png') as source:
                            image = source.convert('RGBA')
                            bounds = image.getchannel('A').getbbox()
                            if bounds is None:
                                continue
                            image = image.crop(bounds)
                            digest = hashlib.sha256(str(image.size).encode() + image.tobytes()).hexdigest()[:20]
                            filename = 'part_' + digest + '.png'
                            path = destination / filename
                            if filename not in used:
                                image.save(path, optimize=True)
                            used.add(filename)
                            parts.append({'texture': 'components/' + filename,
                                          'rect': [bounds[0]/2, bounds[1]/2, image.width/2, image.height/2],
                                          'layer': 'background' if not parts else 'foreground',
                                          'source': symbol + '/' + (element.get('name') or element.get('libraryItemName') or layer.get('name', 'shape'))})
            manifest[screen] = parts
    renderer.out = original_output
    for path in destination.glob('part_*.png'):
        if path.name not in used:
            path.unlink()
            Path(str(path) + '.import').unlink(missing_ok=True)
    (root / 'data/ui_components.json').write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + '\n')
    # Retire both legacy opaque screenshots and the adaptive full-screen layers.
    for screen in manifest:
        legacy = screen.removeprefix('adaptive_')
        for name in (screen, legacy, screen + '_icons'):
            for suffix in ('.png', '.png.import'):
                (root / 'assets/flash_ui' / (name + suffix)).unlink(missing_ok=True)
    return manifest


if __name__ == '__main__':
    import argparse
    from build_localized_ui import CleanRenderer
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('library', type=Path)
    args = parser.parse_args()
    root = Path(__file__).resolve().parents[1]
    renderer = CleanRenderer(args.library, root / 'assets/flash_ui', root / 'fonts/flash')
    renderer.omit_brushes = True
    export_components(renderer, menu_plans(), root)
