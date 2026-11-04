# GLB : textures PNG -> JPEG (qualite 88), meme rendu, fichier bien plus leger
import json, struct, io, sys
from PIL import Image
src, dst = sys.argv[1], sys.argv[2]
b = open(src,'rb').read()
L = struct.unpack_from('<I', b, 12)[0]; js = json.loads(b[20:20+L]); off = 20+L
bl = struct.unpack_from('<I', b, off)[0]; binc = b[off+8:off+8+bl]
views = js['bufferViews']
imgviews = {im['bufferView']: i for i, im in enumerate(js.get('images', []))}
new = bytearray()
for vi, v in enumerate(views):
    data = binc[v.get('byteOffset',0): v.get('byteOffset',0)+v['byteLength']]
    if vi in imgviews:
        im = Image.open(io.BytesIO(data)).convert('RGB'); o = io.BytesIO(); im.save(o, 'JPEG', quality=88, optimize=True); data = o.getvalue()
        js['images'][imgviews[vi]]['mimeType'] = 'image/jpeg'
    while len(new) % 4: new.append(0)
    v['byteOffset'] = len(new); v['byteLength'] = len(data); new += data
while len(new) % 4: new.append(0)
js['buffers'][0]['byteLength'] = len(new)
j = json.dumps(js, separators=(',',':')).encode()
while len(j) % 4: j += b' '
out = struct.pack('<III', 0x46546C67, 2, 12+8+len(j)+8+len(new)) + struct.pack('<I', len(j)) + b'JSON' + j + struct.pack('<I', len(new)) + b'BIN\x00' + new
open(dst,'wb').write(out)
