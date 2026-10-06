"""Extract the authored menu keyframes; no easing or bitmap duplication.
Usage: python tools/build_menu_animations.py /path/to/XFL/LIBRARY
The Flash document runs at 19 fps (MainTimeline.as SWF metadata).
"""
import argparse
import json
import xml.etree.ElementTree as ET
from pathlib import Path

NS = {'x': 'http://ns.adobe.com/xfl/2008/'}
ROOT = Path(__file__).resolve().parents[1]


def layers(library, symbol):
    return ET.parse(library / f'Symbol {symbol}.xml').getroot().findall(
        './x:timeline/x:DOMTimeline/x:layers/x:DOMLayer', NS)


def sample(layer, index):
    frames = [f for f in layer.findall('x:frames/x:DOMFrame', NS)
              if int(f.get('index', 0)) <= index]
    return frames[-1].find('x:elements/x:DOMSymbolInstance', NS) if frames else None


def extract(library):
    logo = []
    for layer in layers(library, 132):
        if layer.get('name') == 'Script Layer':
            continue
        final = sample(layer, 8)
        alpha = []
        for frame in range(9):
            element = sample(layer, frame)
            color = element.find('x:color/x:Color', NS) if element is not None else None
            alpha.append(0.0 if element is None else float(color.get('alphaMultiplier', 1)) if color is not None else 1.0)
        logo.append({'source': 'Symbol 132/' + final.get('libraryItemName'), 'alpha': alpha})
    panels = {}
    for name, symbol, last in [('help', 147, 6), ('selector', 212, 4)]:
        layer = next(l for l in layers(library, symbol) if l.get('name') == 'Layer 2')
        positions = []
        for frame in range(last + 1):
            m = sample(layer, frame).find('x:matrix/x:Matrix', NS)
            positions.append([float(m.get('tx', 0)), float(m.get('ty', 0))])
        destination = positions[-1]
        panels[name] = {'source': f'Symbol {symbol}/Mov', 'start_frame': 1,
                        'offsets': [[x-destination[0], y-destination[1]] for x, y in positions]}
    return {'fps': 19, 'logo': {'source': 'LogoMov / Symbol 132', 'frames': 9, 'tracks': logo},
            'panels': panels}


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('library', type=Path)
    args = parser.parse_args()
    path = ROOT / 'data/menu_animations.json'
    path.write_text(json.dumps(extract(args.library), indent=2) + '\n')
    print('PASS: LogoMov, InfoMov and EpisodesMov authored frames exported')
