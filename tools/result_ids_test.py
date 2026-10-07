"""Check result text against Flash's array, preserving AS expression slots."""
import json
import re
from pathlib import Path
from story_graph_format import load_all

ROOT = Path(__file__).resolve().parents[1]


def source_results(source):
    raw = re.search(r'this.ResultArr = new <String>\[(.*?)\];', source, re.S)[1]
    # Split AS expressions only at top-level commas, outside quoted strings.
    entries, start, depth, quoted, escaped = [], 0, 0, False, False
    for index, char in enumerate(raw):
        if quoted:
            if escaped:
                escaped = False
            elif char == '\\':
                escaped = True
            elif char == '"':
                quoted = False
        elif char == '"':
            quoted = True
        elif char in '([':
            depth += 1
        elif char in ')]':
            depth -= 1
        elif char == ',' and depth == 0:
            entries.append(raw[start:index].strip())
            start = index + 1
    entries.append(raw[start:].strip())
    return entries


def run():
    catalog = json.loads((ROOT / 'data/flash_catalog.json').read_text())
    entries = source_results(catalog['actionscript']['ResultBad.as'])
    checked = 0
    for name, node in load_all(ROOT).items():
        if 'result_id' not in node:
            continue
        index = int(node['result_id'])
        expected = json.loads(entries[index - 1])
        assert node['text'] == expected, (name, index, node['text'], expected)
        checked += 1
    print(f'PASS: {checked} results match Flash IDs and texts across five episodes')


if __name__ == '__main__':
    run()
