import trimesh, numpy as np, sys, cv2
from PIL import Image
ANGLE = float(sys.argv[1]) if len(sys.argv) > 1 else 0.0     # test : machoire fermee de ANGLE degres
OUT = sys.argv[2] if len(sys.argv) > 2 else 'final_brut.glb'
sc = trimesh.load('fang.glb'); m = list(sc.geometry.values())[0]
mat = m.visual.material
# --- STYLISE (moins realiste) : aplats doux, metal acier propre, rouge vif sature, dents ivoire
tex = np.asarray(mat.baseColorTexture.convert('RGB')).copy()
for _ in range(3): tex = cv2.bilateralFilter(tex, 9, 40, 9)          # enleve le grain photo, garde les formes
hsv = cv2.cvtColor(tex, cv2.COLOR_RGB2HSV).astype(np.float32)
h, s_, v = hsv[...,0], hsv[...,1], hsv[...,2]
rouge = np.clip((s_ - 60) / 70, 0, 1) * ((h < 14) | (h > 165))
rouge = cv2.GaussianBlur(rouge.astype(np.float32), (0,0), 1.5)
clair = np.clip((v - 150) / 60, 0, 1) * (s_ < 90)                    # dents / zones claires -> ivoire
# couleurs calculees en RGB (le melange en HSV donnait du rose)
g = np.clip((v - v.mean())*1.3 + 78, 18, 200)[...,None]/255
metal = g*np.array([255, 246, 236])                                    # metal sombre legerement chaud
ivoire = np.clip(v*1.0+25, 0, 240)[...,None]/255*np.array([255, 238, 205])
rouge_vif = np.clip(v*0.9+90, 120, 230)[...,None]/255*np.array([235, 22, 28])
out = metal*(1-clair[...,None]) + ivoire*clair[...,None]
out = out*(1-rouge[...,None]) + rouge_vif*rouge[...,None]
mat.baseColorTexture = Image.fromarray(np.clip(out,0,255).astype(np.uint8))
# relief adouci (moins "scan") et metal plus brillant
nm = np.asarray(mat.normalTexture.convert('RGB')).astype(np.float32)
nm = cv2.GaussianBlur(nm, (0,0), 2.5); nm[...,:2] = 128 + (nm[...,:2]-128)*0.6
mat.normalTexture = Image.fromarray(np.clip(nm,0,255).astype(np.uint8))
texb = np.asarray(mat.baseColorTexture); H, W = texb.shape[:2]
# --- clavier d'origine retire
A, B = -0.3385, -0.0913
c = m.triangles_center; d = c[:,1] - (A*c[:,2] + B)
X0, X1, Z0, Z1 = -0.212, 0.212, -0.19, 0.52
uvc = m.visual.uv[m.faces].mean(axis=1)
px = (uvc[:,0]*W).astype(int).clip(0,W-1); py = ((1-uvc[:,1])*H).astype(int).clip(0,H-1)
lum = texb[py,px].mean(1)
reg = (np.abs(c[:,0])<0.2)&(c[:,2]>-0.1)&(c[:,2]<0.4)
top = np.where(reg&(d>-0.012)&(d<0.005))[0]; base = np.where(reg&(d>-0.06)&(d<-0.035))[0]
# boutons : couleur UNIE (aucune tache) -> tous leurs UV sur un seul point d'une zone sombre et uniforme
moy = cv2.blur(texb.astype(np.float32), (15,15)); ec = np.sqrt(np.maximum(cv2.blur(texb.astype(np.float32)**2,(15,15)) - moy**2, 0)).mean(-1)
lm = moy.mean(-1)
def point_uni(cible):
    score = ec[py,px] + np.abs(lm[py,px] - cible) * 0.5
    i = np.argmin(score); return uvc[i]
uvTop = point_uni(42.0); uvBase = point_uni(26.0)
print('bouton', lm[int((1-uvTop[1])*H), int(uvTop[0]*W)], 'plaque', lm[int((1-uvBase[1])*H), int(uvBase[0]*W)])
suppr = (c[:,0]>X0)&(c[:,0]<X1)&(c[:,2]>Z0)&(c[:,2]<Z1)&(d>-0.09)&(d<0.02)
# --- machoire du haut : tout ce qui est au-dessus de la ligne de coupe, devant les tuyaux
ycut = np.where(c[:,2] < -0.05, 0.08, 0.0)
haut = (~suppr) & (c[:,1] > ycut) & (c[:,2] > -0.38)
bas = (~suppr) & (~haut)
PIV = np.array([0.0, 0.10, -0.30])                 # charniere (arriere bas de la tete)
def sous(mask, decal):
    g = m.copy(); g.update_faces(mask); g.remove_unreferenced_vertices(); g.vertices = g.vertices - decal; return g
corps = sous(bas, np.zeros(3)); gueule = sous(haut, PIV)
# --- plaque + touches (chaque touche = un objet, pivot au centre de sa base)
et = np.array([0, A, 1.0]); et /= np.linalg.norm(et)
en = np.array([0, 1.0, -A]); en /= np.linalg.norm(en)
ex = np.array([1.0, 0, 0]); O = np.array([0, A*Z0 + B, Z0]); L = (Z1-Z0)*np.sqrt(1+A*A); k = 1/np.sqrt(1+A*A)
def P(x, t, hh): return O + ex*x + et*t + en*hh
def boite(x0,x1,t0,t1,h0,h1,ins,uh,us,taille):
    V, F, UV = [], [], []
    pts = [(x0,t0,h0),(x1,t0,h0),(x1,t1,h0),(x0,t1,h0),(x0+ins,t0+ins,h1),(x1-ins,t0+ins,h1),(x1-ins,t1-ins,h1),(x0+ins,t1-ins,h1)]
    for q,u in [([4,5,6,7],uh),([0,1,5,4],us),([1,2,6,5],us),([2,3,7,6],us),([3,0,4,7],us),([3,2,1,0],us)]:
        b = len(V)
        for j,i in enumerate(q):
            V.append(P(*pts[i])); du = [(-1,-1),(1,-1),(1,1),(-1,1)][j]; UV.append([u[0]+du[0]*taille, u[1]+du[1]*taille])
        F.extend([[b,b+2,b+1],[b,b+3,b+2]])        # sens corrige : normales vers l'exterieur
    return np.array(V), np.array(F), np.array(UV)
def objet(V, F, UV, piv):
    return trimesh.Trimesh(V - piv, F, process=False, visual=trimesh.visual.TextureVisuals(uv=UV, material=mat))
hb, ht = -0.09*k, -0.03*k
out = trimesh.Scene()
out.add_geometry(corps, node_name='Corps', geom_name='Corps')
V,F,UV = boite(X0, X1, 0, L, hb, ht, 0.004, uvBase, uvBase, 0.0)
out.add_geometry(objet(V,F,UV,np.zeros(3)), node_name='Plaque', geom_name='Plaque')
R = trimesh.transformations.rotation_matrix(np.radians(ANGLE), [1,0,0])
T = trimesh.transformations.translation_matrix(PIV) @ R
out.add_geometry(gueule, node_name='Gueule', geom_name='Gueule', transform=T)
nc, nr, marge, jeu = 4, 6, 0.016, 0.014
lw = (X1-X0-2*marge-(nc-1)*jeu)/nc; lt = (L-2*marge-(nr-1)*jeu)/nr
n = 0
for r in range(nr):
    for q in range(nc):
        n += 1
        x0 = X0+marge+q*(lw+jeu); t0 = marge+r*(lt+jeu)
        V,F,UV = boite(x0, x0+lw, t0, t0+lt, ht-0.002, ht+0.03*k, 0.007, uvTop, uvTop, 0.0)
        piv = P(x0+lw/2, t0+lt/2, ht)
        out.add_geometry(objet(V,F,UV,piv), node_name=f'Bouton_{n:02d}', geom_name=f'Bouton_{n:02d}', transform=trimesh.transformations.translation_matrix(piv))
out.export(OUT)
print('ok', len(corps.faces), len(gueule.faces), n)
