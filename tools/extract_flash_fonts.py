import struct,zlib
from pathlib import Path
from fontTools.fontBuilder import FontBuilder
from fontTools.pens.ttGlyphPen import TTGlyphPen

class Bits:
 def __init__(self,data):self.data=data;self.pos=0
 def u(self,n):
  v=0
  for _ in range(n): v=(v<<1)|((self.data[self.pos//8]>>(7-self.pos%8))&1);self.pos+=1
  return v
 def s(self,n):
  v=self.u(n);return v-(1<<n) if n and v&(1<<(n-1)) else v
 def align(self):self.pos=(self.pos+7)//8*8

def glyph(data,scale):
 b=Bits(data);fill=b.u(4);line=b.u(4);p=TTGlyphPen(None);x=y=0;opened=False
 def pt(x,y):return (round(x/scale),round(-y/scale))
 while True:
  edge=b.u(1)
  if not edge:
   state=b.u(5)
   if not state:break
   if state&1:
    n=b.u(5);x=b.s(n);y=b.s(n)
    if opened:p.closePath()
    p.moveTo(pt(x,y));opened=True
   if state&2:b.u(fill)
   if state&4:b.u(fill)
   if state&8:b.u(line)
   if state&16:raise ValueError('font newstyles')
  else:
   straight=b.u(1);n=b.u(4)+2
   if not opened:p.moveTo(pt(x,y));opened=True
   if straight:
    if b.u(1):x+=b.s(n);y+=b.s(n)
    elif b.u(1):y+=b.s(n)
    else:x+=b.s(n)
    p.lineTo(pt(x,y))
   else:
    cx=x+b.s(n);cy=y+b.s(n);x=cx+b.s(n);y=cy+b.s(n);p.qCurveTo(pt(cx,cy),pt(x,y))
 if opened:p.closePath()
 return p.glyph()

def extract(swf,out):
 d=Path(swf).read_bytes();d=d[:8]+zlib.decompress(d[8:]) if d[:3]==b'CWS' else d
 b=Bits(d[8:]);n=b.u(5);[b.s(n) for _ in range(4)];b.align();pos=8+b.pos//8+4
 out=Path(out);out.mkdir(parents=True,exist_ok=True);result={}
 while pos+2<len(d):
  t=struct.unpack_from('<H',d,pos)[0];pos+=2;code=t>>6;length=t&63
  if length==63:length=struct.unpack_from('<I',d,pos)[0];pos+=4
  data=d[pos:pos+length];pos+=length
  if code not in [48,75]:continue
  fid,flags,lang,nlen=struct.unpack_from('<HBBB',data,0);name=data[5:5+nlen].decode('utf-8',errors='replace').rstrip('\x00');q=5+nlen;count=struct.unpack_from('<H',data,q)[0];q+=2
  if not count or name.startswith(('GraffitiC1','DS Crystal','SegoeScript','Segoe Script','B52','Verdana','Lucida Console')):continue # Replaced by licensed fonts; do not recreate them.
  base=q;fmt='<I' if flags&8 else '<H';sz=4 if flags&8 else 2
  offsets=[struct.unpack_from(fmt,data,q+i*sz)[0] for i in range(count+1)];q+=sz*(count+1)
  codes_pos=base+offsets[-1];codesz=2 if flags&4 else 1
  codes=[struct.unpack_from('<H' if codesz==2 else '<B',data,codes_pos+i*codesz)[0] for i in range(count)]
  scale=20 if code==75 else 1
  order=['.notdef']+[f'g{i}' for i in range(count)]
  gs={'.notdef':TTGlyphPen(None).glyph()}
  for i in range(count):gs[f'g{i}']=glyph(data[base+offsets[i]:base+offsets[i+1]],scale)
  advances=[600]*count;ascent=900;descent=-250
  if flags&128:
   q=codes_pos+count*codesz
   a,ds,leading=struct.unpack_from('<hhh',data,q);q+=6;ascent=round(a/scale);descent=-round(ds/scale)
   advances=[round(struct.unpack_from('<h',data,q+i*2)[0]/scale) for i in range(count)]
  metrics={'.notdef':(600,0)}
  for i in range(count):
   g=gs[f'g{i}'];g.recalcBounds(gs);metrics[f'g{i}']=(max(1,advances[i]),getattr(g,'xMin',0))
  fb=FontBuilder(1024,isTTF=True);fb.setupGlyphOrder(order);fb.setupCharacterMap({c:f'g{i}' for i,c in enumerate(codes)});fb.setupGlyf(gs);fb.setupHorizontalMetrics(metrics);fb.setupHorizontalHeader(ascent=ascent,descent=descent)
  family=f'FlashFont{fid}';fb.setupNameTable({'familyName':family,'styleName':'Regular','uniqueFontIdentifier':family,'fullName':family,'psName':family});fb.setupOS2(sTypoAscender=ascent,sTypoDescender=descent,usWinAscent=max(ascent,1024),usWinDescent=max(-descent,300));fb.setupPost();fb.setupMaxp();fb.save(out/f'font_{fid}.ttf');result[fid]={'name':name,'path':str(out/f'font_{fid}.ttf'),'glyphs':count};print(fid,name,count)
 return result
if __name__=='__main__':
 import sys
 extract(sys.argv[1],sys.argv[2])
