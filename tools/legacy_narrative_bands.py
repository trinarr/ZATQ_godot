"""Identify only audited Flash caption backdrops, preserving scene/transition art."""
from pathlib import Path
import json

# Source symbol plus authored bounds: farm photos share the same source as bands.
BANDS = {
    'Mov/Symbol 483': (0, 444, 800, 36),
    'Mov/Symbol 2584': (0, 0, 800, 36),
    'Mov/Symbol 2588': (0, 160, 800, 35),
    'Mov/Symbol 2592': (0, 320, 800, 60),
    'Mov.Mov/Symbol 506': (0, 414, 800, 66),
    'Mov.Mov/Symbol 825': (0, 0, 800, 117.5),
    'Mov/Symbol 1480': (0, 315, 800, 165),
    'Mov/Symbol 10266': (0, 361, 800, 119),
    'Mov/Symbol 10296': (0, 337, 800, 143),
}

def is_legacy_narrative_band(part):
    expected = BANDS.get(part.get('source'))
    rect = part.get('rect', [])
    return expected is not None and len(rect) == 4 and all(
        abs(a - b) < 0.02 for a, b in zip(rect, expected)
    )

def clean(root):
    """Remove static and animated copies, including every frame reference."""
    removed = 0
    for path in sorted((root / 'data').glob('episode*_*.json')):
        if path.name.endswith('_components.json'):
            data = json.loads(path.read_text())
            if not isinstance(data, dict):
                continue
            count = 0
            for art, parts in data.items():
                filtered = [p for p in parts if not is_legacy_narrative_band(p)]
                count += len(parts) - len(filtered)
                data[art] = filtered
            if count:
                path.write_text(json.dumps(data, ensure_ascii=False, indent=2) + '\n')
        elif path.name.endswith('_animations.json') and not path.name.endswith(('_text_animations.json', '_ui_animations.json')):
            data = json.loads(path.read_text())
            count = 0
            for spec in data.get('art', {}).values():
                keys = {k for k, p in spec['parts'].items() if is_legacy_narrative_band(p)}
                count += len(keys)
                for key in keys:
                    del spec['parts'][key]
                if keys:
                    for phase in ('intro', 'outro'):
                        spec[phase] = [[r for r in frame if r[0] not in keys] for frame in spec[phase]]
                    for name, frames in spec.get('variables', {}).items():
                        spec['variables'][name] = [[r for r in frame if r[0] not in keys] for frame in frames]
            if count:
                # Retain the compact catalog format used by the animation exporters.
                path.write_text(json.dumps(data, ensure_ascii=False, separators=(',', ':')) + '\n')
        else:
            continue
        if count:
            print(path.name, count)
        removed += count
    return removed

if __name__ == '__main__':
    print('Removed copies:', clean(Path(__file__).resolve().parents[1]))
