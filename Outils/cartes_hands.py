# Images des 6 cartes du bluff (provisoires, a remplacer par les tiennes en gardant les noms).
# Usage : python3 Outils/cartes_hands.py chemin/vers/TitanOne-Regular.ttf  -> Textures/CartesHands/*.png
import sys, math
from PIL import Image, ImageDraw, ImageFont, ImageFilter

POLICE = sys.argv[1]
W, H = 512, 768
CARTES = [
    ("Carte_Defuse", "DEFUSE", "TRAP WON'T\nBITE", (40, 120, 255), (10, 40, 140), "bouclier"),
    ("Carte_Peek", "PEEK", "SEE 1 SAFE\nBUTTON", (40, 200, 90), (8, 90, 40), "oeil"),
    ("Carte_Pass", "PASS", "SKIP YOUR\nTURN", (150, 150, 165), (60, 60, 75), "fleches"),
    ("Carte_Reverse", "REVERSE", "REVERSE\nORDER", (170, 70, 255), (70, 20, 140), "tour"),
    ("Carte_Jam", "JAM", "NEXT PRESSES\n2 BUTTONS", (255, 150, 30), (150, 60, 0), "x2"),
    ("Carte_Steal", "STEAL", "TAKE A\nCARD", (240, 50, 60), (120, 10, 20), "main"),
]

def degrade(c1, c2):
    im = Image.new("RGB", (W, H))
    d = ImageDraw.Draw(im)
    for y in range(H):
        t = y / (H - 1)
        d.line([(0, y), (W, y)], fill=tuple(int(c1[i] * (1 - t) + c2[i] * t) for i in range(3)))
    return im

def centre(d, txt, y, taille, police, couleur=(255, 255, 255), contour=8):
    f = ImageFont.truetype(police, taille)
    for k, ligne in enumerate(txt.split("\n")):
        l = d.textlength(ligne, font=f)
        d.text(((W - l) / 2, y + k * taille * 1.05), ligne, font=f, fill=couleur, stroke_width=contour, stroke_fill=(15, 15, 25))

def icone(d, nom, cx, cy, r, police):
    blanc, noir = (255, 255, 255), (15, 15, 25)
    if nom == "bouclier":
        pts = [(cx - r, cy - r * 0.8), (cx, cy - r), (cx + r, cy - r * 0.8), (cx + r * 0.85, cy + r * 0.3), (cx, cy + r), (cx - r * 0.85, cy + r * 0.3)]
        d.polygon(pts, fill=blanc, outline=noir, width=10)
        d.line([(cx - r * 0.4, cy), (cx - r * 0.05, cy + r * 0.35), (cx + r * 0.45, cy - r * 0.35)], fill=(40, 120, 255), width=22)
    elif nom == "oeil":
        d.ellipse([cx - r, cy - r * 0.55, cx + r, cy + r * 0.55], fill=blanc, outline=noir, width=10)
        d.ellipse([cx - r * 0.4, cy - r * 0.4, cx + r * 0.4, cy + r * 0.4], fill=(30, 160, 70), outline=noir, width=8)
        d.ellipse([cx - r * 0.16, cy - r * 0.16, cx + r * 0.16, cy + r * 0.16], fill=noir)
    elif nom == "fleches":
        for dx in (-r * 0.45, r * 0.25):
            pts = [(cx + dx - r * 0.35, cy - r * 0.7), (cx + dx + r * 0.35, cy), (cx + dx - r * 0.35, cy + r * 0.7)]
            d.line(pts, fill=blanc, width=40, joint="curve")
    elif nom == "tour":
        d.arc([cx - r, cy - r, cx + r, cy + r], 200, 520, fill=blanc, width=34)
        a = math.radians(160)
        px, py = cx + r * math.cos(a), cy + r * math.sin(a)
        d.polygon([(px - 40, py - 10), (px + 40, py - 10), (px, py + 45)], fill=blanc)
    elif nom == "x2":
        centre(d, "x2", cy - r * 0.75, int(r * 1.5), police, blanc, 10)
    elif nom == "main":
        d.ellipse([cx - r * 0.55, cy - r * 0.2, cx + r * 0.55, cy + r * 0.85], fill=blanc, outline=noir, width=10)
        for k in range(4):
            x = cx - r * 0.5 + k * r * 0.33
            d.rounded_rectangle([x, cy - r * 0.9, x + r * 0.25, cy + r * 0.2], radius=20, fill=blanc, outline=noir, width=8)
        d.rounded_rectangle([cx - r * 0.95, cy - r * 0.1, cx - r * 0.45, cy + r * 0.2], radius=20, fill=blanc, outline=noir, width=8)

for fichier, titre, aide, c1, c2, nom in CARTES:
    fond = degrade(c1, c2)
    masque = Image.new("L", (W, H), 0)
    ImageDraw.Draw(masque).rounded_rectangle([0, 0, W - 1, H - 1], radius=48, fill=255)
    im = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    im.paste(fond, (0, 0), masque)
    d = ImageDraw.Draw(im)
    d.rounded_rectangle([6, 6, W - 7, H - 7], radius=44, outline=(255, 255, 255), width=12)
    d.rounded_rectangle([22, 22, W - 23, H - 23], radius=34, outline=(15, 15, 25), width=6)
    centre(d, titre, 60, 92 if len(titre) <= 6 else 78, POLICE)
    d.ellipse([W / 2 - 150, 230, W / 2 + 150, 530], fill=tuple(max(0, v - 40) for v in c2) + (255,), outline=(255, 255, 255), width=10)
    icone(d, nom, W / 2, 380, 110, POLICE)
    centre(d, aide, 575, 52, POLICE, contour=6)
    im.save(f"Textures/CartesHands/{fichier}.png")
    print(fichier)
