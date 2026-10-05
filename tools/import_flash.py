#!/usr/bin/env python3
"""Rebuild provenance catalog and opening assets from the supplied ZIP. No SWF runtime."""
import argparse, hashlib, json, re, shutil, zipfile
from pathlib import Path
import xml.etree.ElementTree as ET
NS = {'x': 'http://ns.adobe.com/xfl/2008/'}

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('archive', type=Path)
    parser.add_argument('--output', type=Path, default=Path(__file__).resolve().parents[1])
    args = parser.parse_args()
    out = args.output
    with zipfile.ZipFile(args.archive) as z:
        names = z.namelist()
        doc = next(n for n in names if n.endswith('/ZombieApocalypse/DOMDocument.xml'))
        source = doc.removesuffix('ZombieApocalypse/DOMDocument.xml')
        library = source + 'ZombieApocalypse/LIBRARY/'
        catalog = []
        for name in names:
            if not name.startswith(library) or not name.endswith('.xml'): continue
            root = ET.fromstring(z.read(name))
            frames = []
            for layer in root.findall('./x:timeline/x:DOMTimeline/x:layers/x:DOMLayer', NS):
                for f in layer.findall('./x:frames/x:DOMFrame', NS):
                    frames.append({'layer': layer.get('name'), 'index': int(f.get('index', '0')), 'duration': int(f.get('duration','1')),
                        'texts': [c.text for c in f.findall('.//x:characters', NS) if c.text],
                        'symbols': [s.attrib for s in f.findall('.//x:DOMSymbolInstance',NS)],
                        'bitmaps': [b.get('bitmapPath') for b in f.findall('.//x:BitmapFill',NS)],
                        'actions': [s.text for s in f.findall('.//x:script',NS) if s.text]})
            catalog.append({'name': root.get('name'), 'class': root.get('linkageClassName',''), 'source': name, 'frames': frames})
        actions = {}
        for n in names:
            if n.startswith(source) and n.endswith('.as') and '/com/' not in n and '/flash/' not in n:
                actions[n[len(source):]] = z.read(n).decode('utf-8-sig')
        main_as = actions['ZombieApocalypse_fla/MainTimeline.as']
        flags = sorted(set(re.findall(r'(?:this|Main)\.([A-Za-z]\w*)', main_as)))
        data = {'source_archive': args.archive.name, 'sha256': hashlib.sha256(args.archive.read_bytes()).hexdigest(),
                'stage': {'width':800,'height':480,'fps':19}, 'symbols':catalog, 'actionscript':actions,
                'root_members_referenced':flags, 'status':'Reference catalog, not executable GDScript'}
        (out/'data').mkdir(parents=True,exist_ok=True)
        (out/'data/flash_catalog.json').write_text(json.dumps(data,ensure_ascii=False,indent=2),encoding='utf-8')
        images = ['Fon1_1.png','NewYork.png','LiftKnop.jpg','OnTheStreet.jpg']
        sounds = ['MainTheme','TVSwitchOn','TVSwitchOff','FootSteps','KeysTake','LiftOpenSound','LiftClosing','LiftButton']
        for kind, items in [('Images',images),('Sound',[s+'.mp3' for s in sounds])]:
            folder=out/'assets'/('images' if kind=='Images' else 'audio');folder.mkdir(parents=True,exist_ok=True)
            for item in items: (folder/item).write_bytes(z.read('assets/'+kind+'/'+item))
        for num in [2821,2823,2825,2827,2829,2831,2833,2868]:
            (out/'assets/images'/f'flash_{num}.png').write_bytes(z.read(library+f'Bitmap {num}.png'))
        print(f'Imported {len(catalog)} symbols, {len(actions)} ActionScript files; opening assets ready.')
if __name__ == '__main__': main()
