# Usage : python3 -I Outils/detourer_cartes.py dossier_des_images dossier_de_sortie  (33.webp ... 38.webp -> Relique_*.png 1024x1024)
import sys, os
import numpy as np
from PIL import Image, ImageFilter
src, out = sys.argv[1], sys.argv[2]
noms = {33: 'Relique_Bouclier', 34: 'Relique_Serrure', 35: 'Relique_Sablier', 36: 'Relique_Chaine', 37: 'Relique_Etau', 38: 'Relique_Corbeau'}

def dil(m):
    n = m.copy()
    n[1:] |= m[:-1]; n[:-1] |= m[1:]; n[:, 1:] |= m[:, :-1]; n[:, :-1] |= m[:, 1:]
    return n

for k, nom in noms.items():
    im = Image.open(os.path.join(src, f'{k}.webp')).convert('RGB')
    a = np.asarray(im).astype(int)
    # couleur du fond (bords de l'image)
    bord = np.concatenate([a[:8].reshape(-1, 3), a[-8:].reshape(-1, 3), a[:, :8].reshape(-1, 3), a[:, -8:].reshape(-1, 3)])
    # fond : tres sombre ET lisse (la carte, meme sombre, est texturee : rouille, papier)
    g = np.asarray(im.convert('L')).astype(float)
    flou = np.asarray(Image.fromarray(g.astype(np.uint8)).filter(ImageFilter.BoxBlur(3))).astype(float)
    flou2 = np.asarray(Image.fromarray(np.clip(g * g / 255.0, 0, 255).astype(np.uint8)).filter(ImageFilter.BoxBlur(3))).astype(float) * 255.0
    ecart = np.sqrt(np.maximum(0, flou2 - flou * flou))
    passable = (a.max(-1) < 26) & (ecart < 3.0)
    # remplissage depuis les bords : tout ce qu'on atteint sur du "fond" = fond
    dehors = np.zeros(passable.shape, bool)
    dehors[0, :] = dehors[-1, :] = dehors[:, 0] = dehors[:, -1] = True
    dehors &= passable
    while True:
        n = dil(dehors) & passable
        if (n == dehors).all():
            break
        dehors = n
    carte = ~dehors
    # on ne garde que le gros morceau (la carte) : remplissage depuis le centre
    h, w = carte.shape
    garde = np.zeros_like(carte); garde[h // 2, w // 2] = True
    while True:
        n = dil(garde) & carte
        if (n == garde).all():
            break
        garde = n
    # le cadre metallique sombre et lisse etait parfois pris pour du fond (encoches dans le bord) :
    # on bouche, ligne par ligne ET colonne par colonne, tout ce qui est entre le premier et le dernier pixel de la carte
    lignes = np.zeros_like(garde)
    for y in range(h):
        xs = np.where(garde[y])[0]
        if len(xs):
            lignes[y, xs[0]:xs[-1] + 1] = True
    colonnes = np.zeros_like(garde)
    for x in range(w):
        ys = np.where(garde[:, x])[0]
        if len(ys):
            colonnes[ys[0]:ys[-1] + 1, x] = True
    plein = lignes | colonnes
    alpha = Image.fromarray((plein * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(0.7))
    rgba = im.convert('RGBA'); rgba.putalpha(alpha)
    bb = alpha.point(lambda v: 255 if v > 10 else 0).getbbox()
    rgba = rgba.crop(bb)
    # carte entiere, non deformee, centree dans une image 1024 x 1024 transparente
    T, m = 1024, 8
    s = min((T - 2 * m) / rgba.width, (T - 2 * m) / rgba.height)
    rgba = rgba.resize((round(rgba.width * s), round(rgba.height * s)), Image.LANCZOS)
    c = Image.new('RGBA', (T, T), (0, 0, 0, 0))
    c.paste(rgba, ((T - rgba.width) // 2, (T - rgba.height) // 2), rgba)
    c.save(os.path.join(out, nom + '.png'), optimize=True)
    print(nom, bb, rgba.size, os.path.getsize(os.path.join(out, nom + '.png')) // 1024, 'KB')
