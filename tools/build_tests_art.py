"""Render the original test frame and navigation icons from supplied XFL."""
import argparse, copy, tempfile, zipfile
from pathlib import Path
from PIL import Image
from render_flash_ui import Renderer

ROOT=Path(__file__).resolve().parents[1]
class TestRenderer(Renderer):
    def text(self,element):return ''
    def symbol(self,name,*args,**kwargs):
        if self.hide_icons and name in ['Symbol 10','Symbol 12','Symbol 14']:return ''
        return super().symbol(name,*args,**kwargs)

def build(archive):
    with tempfile.TemporaryDirectory() as tmp:
        library=Path(tmp)
        with zipfile.ZipFile(archive) as z:
            for name in z.namelist():
                if '/ZombieApocalypse/LIBRARY/' in name and name.endswith(('.xml','.png','.jpg')):
                    target=library/name.split('/ZombieApocalypse/LIBRARY/',1)[1]
                    target.parent.mkdir(parents=True,exist_ok=True);target.write_bytes(z.read(name))
        art=ROOT/'assets/flash_ui'
        r=TestRenderer(library,art,ROOT/'fonts/flash');r.hide_icons=True
        r.render('tests_question.png',[('Symbol 24',0,0,0,{},set(['Choose%d'%i for i in range(1,9)]+['But1','But2','But3']))])
        r.hide_icons=False
        original=r.root('Symbol 24')
        from render_flash_ui import NS
        for name,symbol in [('menu',10),('restart',14),('continue',12)]:
            filename='tests_'+name+'_icon.png'
            only_icon=copy.deepcopy(original)
            for elements in only_icon.findall('.//x:DOMFrame/x:elements',NS):
                for element in list(elements):
                    if element.get('libraryItemName')!='Symbol '+str(symbol):elements.remove(element)
            r.cache['Symbol 24']=only_icon
            r.render(filename,[('Symbol 24',0,0,0,{},set())])
            with Image.open(art/filename) as im:
                assert im.getbbox(),filename
                im.crop(im.getbbox()).save(art/filename)
if __name__=='__main__':
    parser=argparse.ArgumentParser();parser.add_argument('archive',type=Path)
    build(parser.parse_args().archive)
