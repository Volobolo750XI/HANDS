from PIL import Image, ImageDraw, ImageFilter
import random, math, sys
OUT=sys.argv[1]
S=4
CONT=(38,20,10,255)
def canvas(w,h): return Image.new('RGBA',(w*S,h*S),(0,0,0,0))
def fin(im,name):
    w,h=im.size; im.resize((w//S,h//S),Image.LANCZOS).save(f'{OUT}/{name}.png')
def rr(d,box,r,fill=None,outline=None,width=0):
    d.rounded_rectangle([c*S for c in box],radius=r*S,fill=fill,outline=outline,width=width*S)

def bois(w,h,base,fonce,clair,planches,r,cadre=True):
    im=canvas(w,h); d=ImageDraw.Draw(im)
    rr(d,(0,0,w,h),r,fill=CONT)
    m=8
    rr(d,(m,m,w-m,h-m),r-6,fill=base)
    # planches
    mask=canvas(w,h); dm=ImageDraw.Draw(mask); rr(dm,(m,m,w-m,h-m),r-6,fill=(255,255,255,255))
    pl=canvas(w,h); dp=ImageDraw.Draw(pl)
    ph=(h-2*m)/planches
    random.seed(w*h)
    for i in range(planches):
        y0=m+i*ph; y1=y0+ph
        c=tuple(min(255,max(0,v+random.randint(-10,10))) for v in base[:3])+(255,)
        dp.rectangle([0,y0*S,w*S,y1*S],fill=c)
        dp.rectangle([0,y0*S,w*S,(y0+ph*0.18)*S],fill=clair)     # reflet en haut de la planche
        dp.line([0,y1*S,w*S,y1*S],fill=CONT,width=4*S)
        # veines
        for k in range(3):
            yy=y0+ph*(0.35+0.2*k)+random.uniform(-3,3); x0=random.uniform(0,w*0.5)
            dp.line([x0*S,yy*S,(x0+random.uniform(w*0.2,w*0.5))*S,yy*S],fill=fonce,width=2*S)
        # noeud
        nx=random.uniform(w*0.15,w*0.85); ny=y0+ph*0.55
        dp.ellipse([(nx-14)*S,(ny-6)*S,(nx+14)*S,(ny+6)*S],outline=fonce,width=3*S)
    im.paste(pl,(0,0),mask)
    d=ImageDraw.Draw(im)
    rr(d,(m,m,w-m,h-m),r-6,outline=CONT,width=6)
    return im

def clou(d,x,y,r=9):
    d.ellipse([(x-r)*S,(y-r)*S,(x+r)*S,(y+r)*S],fill=(150,150,160,255),outline=CONT,width=3*S)
    d.ellipse([(x-r*0.45)*S,(y-r*0.6)*S,(x+r*0.1)*S,(y-r*0.05)*S],fill=(235,235,240,255))

def coin(d,x,y,sx,sy,t=70):
    pts=[(x,y),(x+sx*t,y),(x+sx*t,y+sy*24),(x+sx*24,y+sy*24),(x+sx*24,y+sy*t),(x,y+sy*t)]
    d.polygon([(a*S,b*S) for a,b in pts],fill=(120,125,135,255),outline=CONT)
    d.line([(a*S,b*S) for a,b in pts+[pts[0]]],fill=CONT,width=5*S)
    clou(d,x+sx*14,y+sy*14,7); clou(d,x+sx*52,y+sy*12,6); clou(d,x+sx*12,y+sy*52,6)

# 1. FOND DE LA BOUTIQUE
W,H=1600,900
im=bois(W,H,(150,92,48,255),(110,62,30,255),(176,115,64,255),9,46)
d=ImageDraw.Draw(im)
# zone interieure sombre pour le contenu
rr(d,(70,150,W-70,H-60),26,fill=(28,18,12,235),outline=CONT,width=7)
rr(d,(78,158,W-78,H-68),22,outline=(80,52,30,255),width=3)
for (x,y,sx,sy) in [(14,14,1,1),(W-14,14,-1,1),(14,H-14,1,-1),(W-14,H-14,-1,-1)]: coin(d,x,y,sx,sy)
for x in range(160,W-150,180): clou(d,x,40,7); clou(d,x,H-32,7)
fin(im,'Fond_Boutique')

# 2. BANNIERE (ruban rouge)
W,H=1024,256
im=canvas(W,H); d=ImageDraw.Draw(im)
def poly(p,fill): d.polygon([(a*S,b*S) for a,b in p],fill=fill); d.line([(a*S,b*S) for a,b in p+[p[0]]],fill=CONT,width=7*S,joint='curve')
poly([(20,70),(190,70),(190,215),(20,215),(75,142)],(150,22,28,255))
poly([(W-20,70),(W-190,70),(W-190,215),(W-20,215),(W-75,142)],(150,22,28,255))
poly([(150,190),(190,215),(190,190)],(90,10,15,255)); poly([(W-150,190),(W-190,215),(W-190,190)],(90,10,15,255))
poly([(150,30),(W-150,30),(W-150,190),(150,190)],(214,40,44,255))
d.rectangle([156*S,38*S,(W-156)*S,70*S],fill=(240,96,92,255))
d.line([162*S,170*S,(W-162)*S,170*S],fill=(170,26,30,255),width=6*S)
d.line([(150*S,30*S),((W-150)*S,30*S),((W-150)*S,190*S),(150*S,190*S),(150*S,30*S)],fill=CONT,width=8*S)
fin(im,'Banniere')

# 3. CARTE D'OBJET
W,H=512,640
im=canvas(W,H); d=ImageDraw.Draw(im)
rr(d,(4,4,W-4,H-4),40,fill=CONT)
rr(d,(14,14,W-14,H-14),32,fill=(214,160,96,255))
rr(d,(14,14,W-14,60),32,fill=(238,190,124,255))
rr(d,(40,40,W-40,H-40),24,fill=(40,28,22,255),outline=CONT,width=6)
rr(d,(48,48,W-48,130),18,fill=(64,46,34,255))
for (x,y) in [(28,28),(W-28,28),(28,H-28),(W-28,H-28)]: clou(d,x,y,8)
fin(im,'Carte_Objet')

# 4. ONGLETS
def onglet(nom,base,clair):
    W,H=512,160
    im=canvas(W,H); d=ImageDraw.Draw(im)
    rr(d,(4,4,W-4,H-4),48,fill=CONT)
    rr(d,(14,14,W-14,H-14),40,fill=base)
    rr(d,(26,20,W-26,64),26,fill=clair)
    d.line([40*S,(H-30)*S,(W-40)*S,(H-30)*S],fill=tuple(max(0,v-40) for v in base[:3])+(255,),width=6*S)
    fin(im,nom)
onglet('Onglet',(140,88,46,255),(176,118,66,255))
onglet('Onglet_Actif',(255,196,40,255),(255,234,140,255))

# 5. BOUTON FERMER
W=256
im=canvas(W,W); d=ImageDraw.Draw(im)
d.ellipse([6*S,6*S,(W-6)*S,(W-6)*S],fill=CONT)
d.ellipse([18*S,18*S,(W-18)*S,(W-18)*S],fill=(220,44,44,255))
d.ellipse([40*S,28*S,(W-60)*S,110*S],fill=(246,120,112,255))
for a,b,c,e in [(80,80,176,176),(176,80,80,176)]:
    d.line([a*S,b*S,c*S,e*S],fill=CONT,width=46*S)
for a,b,c,e in [(80,80,176,176),(176,80,80,176)]:
    d.line([a*S,b*S,c*S,e*S],fill=(255,255,255,255),width=28*S)
fin(im,'Bouton_Fermer')

# 6. CADRE DES DENTS (en haut a droite)
W,H=512,140
im=canvas(W,H); d=ImageDraw.Draw(im)
rr(d,(4,4,W-4,H-4),60,fill=CONT)
rr(d,(14,14,W-14,H-14),52,fill=(40,28,22,240))
rr(d,(24,20,W-24,52),24,fill=(70,52,40,255))
fin(im,'Cadre_Dents')
print('ok')
