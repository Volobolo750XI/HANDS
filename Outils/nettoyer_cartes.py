# Cartes : plus de rouille (couleurs orange/brun -> metal gris) et le sang assombri (rouges -> brun tres fonce).
# Les boutons rouges de JAM (dans le medaillon) ne sont pas touches.
import sys, os
import numpy as np
from PIL import Image, ImageEnhance
src, out = sys.argv[1], sys.argv[2]
for nom in ['Carte_Defuse', 'Carte_Peek', 'Carte_Pass', 'Carte_Reverse', 'Carte_Jam', 'Carte_Steal']:
    im = Image.open(os.path.join(src, nom + '.png')).convert('RGBA')
    a = np.asarray(im).astype(float)
    rgb = a[..., :3] / 255.0
    mx, mn = rgb.max(-1), rgb.min(-1)
    d = mx - mn + 1e-6
    r, g, b = rgb[..., 0], rgb[..., 1], rgb[..., 2]
    h = np.where(mx == r, ((g - b) / d) % 6, np.where(mx == g, (b - r) / d + 2, (r - g) / d + 4)) * 60.0
    sat = np.where(mx > 0, d / (mx + 1e-6), 0)
    lum = rgb @ np.array([0.299, 0.587, 0.114])
    gris = np.repeat(lum[..., None], 3, -1)
    # ROUILLE : orange / brun -> gris metal (meme luminosite, un peu plus sombre)
    # toutes les teintes chaudes (rose-brun, rouge, orange, brun) : de -50 a +55 degres
    hc = np.where(h > 180, h - 360, h)
    chaud = np.clip((hc + 50) / 10, 0, 1) * np.clip((55 - hc) / 10, 0, 1)
    rouille = np.clip((sat - 0.04) / 0.06, 0, 1) * chaud
    # SANG : rouges -> brun tres fonce
    rouge = np.clip((sat - 0.22) / 0.15, 0, 1) * np.clip(1 - np.abs(hc) / 28, 0, 1)
    if nom == 'Carte_Jam':
        H, W = lum.shape
        yy, xx = np.mgrid[0:H, 0:W]
        dans = ((xx - 515) ** 2 + (yy - 520) ** 2) < 230 ** 2
        rouge = rouge * ~dans
        rouille = rouille * ~dans
    res = rgb * (1 - rouille[..., None]) + gris * 0.92 * rouille[..., None]
    sombre = np.stack([lum * 0.50, lum * 0.45, lum * 0.45], -1)
    res = res * (1 - rouge[..., None]) + sombre * rouge[..., None]
    a[..., :3] = np.clip(res * 255, 0, 255)
    n = Image.fromarray(a.astype(np.uint8))
    n.save(os.path.join(out, nom + '.png'), optimize=True)
    al = n.getchannel('A')
    s = ImageEnhance.Brightness(n.convert('RGB')).enhance(1.28).convert('RGBA'); s.putalpha(al)
    s.save(os.path.join(out, nom + '_Survol.png'), optimize=True)
    print(nom)
