"""Preserve hidden caption prefixes separately from their authored alpha.
A hidden prefix may retain alpha=1 until visibility is enabled at alpha=0.
The following entrance fade, frame times, poses and outros are kept.
"""
import argparse
import json
from pathlib import Path
ROOT = Path(__file__).resolve().parents[1]


def normalize_intro(track):
    rows = track.get('intro', [])
    changed = []
    for text in track.get('anchors', {}):
        alpha = [next((record[2][3] for record in row if record[0] == text), None) for row in rows]
        start = 0
        while start < len(alpha) and alpha[start] == 1:
            start += 1
        if start == 0 or start == len(alpha) or alpha[start] != 0:
            continue
        # Require a real rising fade, not an intentional opaque/hidden blink.
        fade = alpha[start:]
        positive = next((i for i, value in enumerate(fade) if value != 0), len(fade))
        if positive == len(fade) or fade[positive] is None or not 0 < fade[positive] < 1:
            continue
        previous = 0
        complete = False
        for value in fade:
            if value is None or value < previous:
                break
            if value == 1:
                complete = True
                break
            previous = value
        if not complete:
            continue
        pending = [record for row in rows[:start] for record in row
                   if record[0] == text and (len(record) < 4 or record[3])]
        if not pending:
            continue
        for record in pending:
            if len(record) < 4:
                record.append(False)
            else:
                record[3] = False
        changed.append(text)
    return changed


def migrate(root=ROOT, check=False):
    total = 0
    for path in sorted((root / 'data').glob('episode*_text_animations.json')):
        document = json.loads(path.read_text())
        animation = json.loads(path.with_name(path.name.replace('_text_', '_')).read_text())
        count = 0
        for art, track in document.items():
            if animation.get('art', {}).get(art, {}).get('qte', False):
                continue
            count += len(normalize_intro(track))
        if count:
            if not check:
                path.write_text(json.dumps(document, separators=(',', ':'), ensure_ascii=False) + '\n')
            print(f'{path.name}: {count} caption visibility prefixes'+(' found' if check else ' fixed'))
        total += count
    return total


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--check', action='store_true')
    args = parser.parse_args()
    total = migrate(check=args.check)
    print(f'{total} caption visibility prefixes'+(' found' if args.check else ' fixed'))
    raise SystemExit(bool(total) if args.check else 0)
