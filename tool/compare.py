# Builds docs-shots/compare-<name>.png: engine screen render (left) vs PDF (right).
import subprocess, sys
from PIL import Image, ImageDraw
D='/workspace/docs-shots'
for n in sys.argv[1:]:
    subprocess.run(['pdftoppm','-r','144','-png','-f','1','-l','1','-singlefile',f'{D}/compare-{n}.pdf',f'/tmp/arx/pdf-{n}'],check=True)
    a=Image.open(f'{D}/compare-{n}-screen.png').convert('RGBA'); bg=Image.new('RGBA',a.size,'white'); a=Image.alpha_composite(bg,a).convert('RGB')
    b=Image.open(f'/tmp/arx/pdf-{n}.png').convert('RGB').resize(a.size)
    c=Image.new('RGB',(a.width*2+30,a.height+30),'#ddd'); c.paste(a,(10,25)); c.paste(b,(a.width+20,25))
    d=ImageDraw.Draw(c); d.text((10,6),'EKRAN (redaktor sehife gorunusu)',fill='black'); d.text((a.width+20,6),'PDF ixrac',fill='black')
    c.save(f'{D}/compare-{n}.png')
