# Police "pinceau sec" facon horreur : Permanent Marker (Apache 2.0) + bords effiloches et eclaboussures seches.
import sys, os, json
import numpy as np
from PIL import Image, ImageDraw, ImageFont, ImageFilter
POLICE, SORTIE = sys.argv[1], sys.argv[2]
os.makedirs(SORTIE, exist_ok=True)
rng = np.random.default_rng(7)
TX = 256                     # image finale par caractere (puissance de 2)
G = 4                        # rendu 4x plus grand puis reduit (bords propres)

def bruit(h, w, sx, sy):
    n = rng.random((h, w)).astype(np.float32)
    im = Image.fromarray((n * 255).astype(np.uint8)).resize((w, h))
    im = im.filter(ImageFilter.GaussianBlur((sx + sy) / 2))
    a = np.asarray(im).astype(np.float32) / 255
    # trainees de pinceau : flou plus fort dans un sens
    im2 = Image.fromarray((a * 255).astype(np.uint8)).resize((max(1, w // sx), max(1, h // sy)), Image.BILINEAR).resize((w, h), Image.BICUBIC)
    b = np.asarray(im2).astype(np.float32) / 255
    return (b - b.mean()) / (b.std() + 1e-6)

def glyphe(c, couleur):
    W = TX * G
    # taille FIXE pour tous les caracteres (meme ligne de base) : la ponctuation garde sa vraie taille
    F = ImageFont.truetype(POLICE, int(W * 0.80))
    ref = Image.new('L', (W * 2, W * 2), 0)
    ImageDraw.Draw(ref).text((W // 2, W // 3), 'H', font=F, fill=255)
    rb = ref.getbbox()
    echelle = (W * 0.68) / (rb[3] - rb[1])          # un H prend 68 % de la hauteur
    m0 = Image.new('L', (W * 2, W * 2), 0)
    d = ImageDraw.Draw(m0)
    d.text((W // 2, W // 3), c, font=F, fill=255)
    bb = m0.getbbox() or (W, rb[1], W + 1, rb[3])
    g = m0.crop((bb[0], rb[1] - int(0.2 * (rb[3] - rb[1])), bb[2], rb[3] + int(0.25 * (rb[3] - rb[1]))))
    hh = max(1, int(g.height * echelle)); ww = max(1, int(g.width * echelle * 0.82))
    if ww > int(W * 0.94):
        f2 = W * 0.94 / ww; ww = int(ww * f2); hh = int(hh * f2)
    g = g.resize((ww, hh), Image.LANCZOS)
    m = Image.new('L', (W, W), 0)
    m.paste(g, ((W - ww) // 2, (W - hh) // 2))
    m = m.filter(ImageFilter.MinFilter(2 * G + 1))          # traits un peu plus fins
    a = np.asarray(m.filter(ImageFilter.GaussianBlur(G * 3))).astype(np.float32) / 255
    # bords effiloches : bruit en trainees verticales (coups de pinceau) + grain fin
    # fibres du pinceau dans les deux sens (traits horizontaux ET verticaux) + grain
    n = 0.45 * bruit(W, W, 3, 50) + 0.45 * bruit(W, W, 50, 3) + 0.25 * bruit(W, W, 2, 6) + 0.2 * bruit(W, W, 1, 1)
    pres = np.asarray(m.filter(ImageFilter.GaussianBlur(G * 10))).astype(np.float32) / 255
    n = n * np.clip(pres * 6, 0, 1)
    alpha = np.clip((a - 0.5 + 0.34 * n) * 6.5, 0, 1)
    # trous de pinceau sec a l'interieur
    tb = bruit(W, W, 2, 30)
    tb = np.asarray(Image.fromarray(np.clip((tb + 4) * 30, 0, 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(G * 2))).astype(np.float32) / 30 - 4
    trous = np.clip((tb - 1.3) * 1.5, 0, 1)
    alpha = alpha * (1 - 0.85 * trous * (a > 0.6))
    # quelques petites eclaboussures seches autour
    e = Image.new('L', (W, W), 0)
    de = ImageDraw.Draw(e)
    ys, xs = np.where(a > 0.5)
    if len(xs):
        for _ in range(rng.integers(2, 6)):
            k = rng.integers(len(xs))
            px = xs[k] + rng.normal(0, W * 0.08); py = ys[k] + rng.normal(0, W * 0.08)
            r = abs(rng.normal(0, G * 2.2)) + G
            de.ellipse([px - r, py - r, px + r, py + r], fill=255)
    alpha = np.maximum(alpha, np.asarray(e).astype(np.float32) / 255 * 0.9)
    rgba = np.zeros((W, W, 4), np.float32)
    rgba[..., :3] = np.array(couleur, np.float32)
    rgba[..., 3] = alpha * 255
    im = Image.fromarray(rgba.astype(np.uint8), 'RGBA').resize((TX, TX), Image.LANCZOS)
    # largeur utile (pour poser les lettres cote a cote)
    al = np.asarray(im.getchannel('A'))
    cols = np.where(al.max(0) > 40)[0]
    largeur = (cols.max() - cols.min() + 1) / TX if len(cols) else 0.25
    return im, round(float(largeur), 3)

if __name__ == '__main__' and len(sys.argv) > 3 and sys.argv[3] != 'TOUT':
    texte = sys.argv[3] if len(sys.argv) > 3 else 'THE'
    ims = [glyphe(c, (225, 222, 214))[0] for c in texte]
    c = Image.new('RGB', (TX * len(ims), TX), (25, 28, 26))
    for i, im in enumerate(ims):
        c.paste(im, (i * TX, 0), im)
    c.save(os.path.join(SORTIE, 'essai.jpg'))

# --- tout le jeu de caracteres : E_<nom>.png (normal, os) et E_<nom>_Clair.png (survol, blanc pur)
NOMS = {c: c for c in 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789'}
NOMS.update({'!': 'Excl', '?': 'Inter', '.': 'Point', ',': 'Virgule', ':': 'DeuxPoints', "'": 'Apos', '-': 'Tiret',
             '+': 'Plus', '%': 'Pourcent', '/': 'Slash', '(': 'ParenG', ')': 'ParenD', 'x': 'Fois', '#': 'Diese'})
def tout():
    largeurs = {}
    for c, nom in NOMS.items():
        im, l = glyphe(c, (205, 201, 190))
        im.save(os.path.join(SORTIE, f'E_{nom}.png'), optimize=True)
        im2, _ = glyphe(c, (255, 255, 255))
        im2.save(os.path.join(SORTIE, f'E_{nom}_Clair.png'), optimize=True)
        largeurs[c] = l
    json.dump({'noms': NOMS, 'largeurs': largeurs}, open(os.path.join(SORTIE, 'largeurs.json'), 'w'), indent=1, ensure_ascii=False)

if len(sys.argv) > 3 and sys.argv[3] == 'TOUT':
    tout()
