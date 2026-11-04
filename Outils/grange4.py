import numpy as np, trimesh, cv2
from PIL import Image
rng = np.random.default_rng(7)
T = trimesh.transformations
def bruit(n, sy, sx=None):
    sx = sx or sy; b = rng.random((n//sy+2, n//sx+2)).astype(np.float32)
    return cv2.resize(b, (n, n), interpolation=cv2.INTER_CUBIC)
def bois(c1, c2, n=2048, nb=5, joints=True, use=0.5):
    def an(sy, sx): return bruit(n, sy, sx)
    warp = an(256, 24)*8 + an(64, 8)*1.5
    xx = np.linspace(0, 1, n)[None, :].repeat(n, 0)
    anneaux = np.sin((xx*70 + warp)*np.pi)*0.5 + 0.5                     # cernes du bois
    fibres = an(512, 1)*0.6 + an(256, 2)*0.4                              # fibres fines dans le sens du fil
    t = np.clip(0.38*anneaux + 0.37*fibres + 0.25*an(128, 16), 0, 1)
    img = np.array(c1, np.float32)*(1-t[...,None]) + np.array(c2, np.float32)*t[...,None]
    img *= (0.8 + 0.4*an(512, 64))[..., None]                              # grandes variations de teinte
    sale = np.clip(bruit(n, 96)*1.7 - 0.8, 0, 1)[..., None]*use
    img = img*(1-0.5*sale) + np.array((60, 58, 52))*0.5*sale              # bois grise / sale par endroits
    for _ in range(int(14*n/1024)):                                        # fentes sombres le long du fil
        x = int(rng.integers(0, n)); y0 = int(rng.integers(0, n)); l = int(rng.integers(n//20, n//4))
        xs = (x + np.cumsum(rng.normal(0, 0.4, l))).astype(int) % n
        img[(y0 + np.arange(l)) % n, xs] *= 0.3
    for k in range(nb):
        x0 = k*n//nb; img[:, x0:x0+n//nb] *= 0.85 + 0.3*rng.random()
        if joints: img[:, x0:x0+6] *= 0.25
    for _ in range(nb*2):
        x, y = rng.integers(40, n-40, 2); rx, ry = int(rng.integers(8, 22)), int(rng.integers(18, 50))
        cv2.ellipse(img, (int(x), int(y)), (rx+6, ry+10), 0, 0, 360, tuple(float(v)*0.7 for v in c1), -1)
        cv2.ellipse(img, (int(x), int(y)), (rx, ry), 0, 0, 360, (28, 20, 14), -1)
    return np.clip(cv2.GaussianBlur(img, (3, 3), 0), 0, 255).astype(np.uint8)
def uni(c, var, n=1024, s=16):
    g = bruit(n,s)*0.5 + bruit(n,2)*0.3 + bruit(n,64)*0.2
    return np.clip(np.array(c,np.float32)[None,None]*(1-var+2*var*g[...,None]), 0, 255).astype(np.uint8)
def paille(base=(105,80,36), n=1024, nb=14000):
    img = np.zeros((n,n,3),np.float32)+base
    img *= (0.7+0.6*bruit(n,64))[...,None]
    for _ in range(nb):
        x,y = rng.integers(0,n,2); a = rng.random()*np.pi; L = rng.integers(12,55)
        col = (np.array((215,175,95))*(0.5+0.65*rng.random())).tolist()
        cv2.line(img,(int(x),int(y)),(int(x+L*np.cos(a)),int(y+L*np.sin(a))),col,int(rng.integers(1,3)))
    return np.clip(img,0,255).astype(np.uint8)
def normale(img, force=3.0):
    h = cv2.GaussianBlur(cv2.cvtColor(img, cv2.COLOR_RGB2GRAY).astype(np.float32)/255, (0,0), 1.2)
    dx = cv2.Sobel(h, cv2.CV_32F, 1, 0, ksize=3)*force; dy = cv2.Sobel(h, cv2.CV_32F, 0, 1, ksize=3)*force
    nz = 1/np.sqrt(dx*dx+dy*dy+1)
    return np.clip(np.dstack([(-dx*nz+1)/2, (dy*nz+1)/2, (nz+1)/2])*255, 0, 255).astype(np.uint8)
def mat(img, rough=0.88, metal=0.0, nom='', force=3.0):
    g = cv2.cvtColor(img, cv2.COLOR_RGB2GRAY).astype(np.float32)/255
    r = np.clip(0.7 + 0.3*(1 - g/ max(g.mean()*2, 1e-3)), 0.45, 1.0)
    mr = np.dstack([np.zeros_like(r), r, np.full_like(r, metal)]); mr = (mr*255).astype(np.uint8)
    return trimesh.visual.material.PBRMaterial(name=nom, baseColorTexture=Image.fromarray(img), normalTexture=Image.fromarray(normale(img, force)),
        metallicRoughnessTexture=Image.fromarray(mr), roughnessFactor=1.0 if rough > 0.8 else rough/0.85, metallicFactor=1.0 if metal > 0 else 0.0)
M = {'planche': mat(bois((46,34,24),(92,68,46),nb=1), nom='Planche'),
     'vieux': mat(bois((58,52,44),(105,92,76),nb=1,use=1.0), nom='BoisGris'),
     'poutre': mat(bois((38,27,18),(78,56,36),nb=1,joints=False), nom='Poutre'),
     'sol': mat(uni((70,58,44),0.35), 0.95, nom='Terre', force=5),
     'beton': mat(uni((66,60,52),0.3,s=8), 0.9, nom='Beton', force=4),
     'paille': mat(paille(), 1.0, nom='Paille', force=6),
     'boue': mat(uni((52,38,26),0.4,s=32), 0.6, nom='Boue', force=6),
     'fer': mat(uni((58,56,54),0.35,s=8), 0.55, 0.85, nom='FerRouille', force=2),
     'table': mat(bois((88,58,36),(140,98,62),nb=6,use=0.4), 0.7, nom='Table'),
     'lumiere': trimesh.visual.material.PBRMaterial(name='Lumiere', baseColorFactor=(255,200,120,255), emissiveFactor=(1.0,0.62,0.25))}
TU = 1.5
def boite(sx, sy, sz, m):
    h = np.array([sx/2, sy/2, sz/2]); bv = min(0.015, 0.22*h.min()*2)
    pts = []
    for cs in np.array(np.meshgrid([-1,1],[-1,1],[-1,1])).reshape(3,-1).T:
        for ax in range(3):
            p = cs*h; q = p.copy()
            for o in range(3):
                if o != ax: q[o] -= cs[o]*bv
            pts.append(q)
    t = trimesh.convex.convex_hull(np.array(pts)); t.unmerge_vertices()
    fn = t.face_normals; ax = np.abs(fn).argmax(1)
    V = t.vertices; uv = np.zeros((len(V), 2))
    for f, a_ in zip(t.faces, ax):
        autres = [o for o in range(3) if o != a_]
        vv, uu = (autres if h[autres[0]] >= h[autres[1]] else autres[::-1])
        uv[f, 0] = (V[f, uu] + h[uu])/TU*0.25; uv[f, 1] = (V[f, vv] + h[vv])/TU
    uv += rng.random(2)*5
    t.visual = trimesh.visual.TextureVisuals(uv=uv, material=M[m]); return t
def place(t, x, y, z, rx=0, ry=0, rz=0):
    t.apply_transform(T.euler_matrix(rx, ry, rz, 'sxyz')); t.apply_translation([x,y,z]); return t
def B(x,y,z,sx,sy,sz,m,rx=0,ry=0,rz=0): return place(boite(sx,sy,sz,m),x,y,z,rx,ry,rz)
def sol(sx, sz, m, x, y, z, tu=2.0):
    t = B(x,y,z,sx,0.06,sz,m); v=t.vertices; t.visual.uv = np.c_[v[:,0], v[:,2]]/tu; return t
def cyl(r, h, m, sec=24, tu=1.0):
    t = trimesh.creation.cylinder(radius=r, height=h, sections=sec); t.unmerge_vertices()
    V = t.vertices; uv = np.zeros((len(V), 2)); cap = np.abs(t.face_normals[:, 2]) > 0.7
    for f, c_ in zip(t.faces, cap):
        if c_: uv[f] = V[f, :2]/tu                                    # dessus / dessous : planches droites
        else:
            a = np.unwrap(np.arctan2(V[f, 1], V[f, 0])); uv[f] = np.c_[a*r/tu, V[f, 2]/tu]
    t.visual = trimesh.visual.TextureVisuals(uv=uv, material=M[m]); return t
P = {}
def add(nom, t): P.setdefault(nom, []).append(t)
N, PW, PD, ALLEE = 8, 3.0, 3.6, 6.0
L = N*PW + 6.0; W = 2*PD + ALLEE; HM = 3.4; X0 = -N*PW/2
# sols : allee en beton use, enclos en terre + paille / boue
add('Sol', sol(L, ALLEE, 'beton', 0, -0.03, 0, 3.0))
for sg in (-1,1):
    add('Sol', sol(L, PD, 'sol', 0, -0.03, sg*(ALLEE/2+PD/2), 2.5))
    for i in range(N):
        x = X0 + PW*(i+0.5); m = 'boue' if rng.random() < 0.35 else 'paille'
        add('Litiere', sol(PW-0.15, PD-0.3, m, x+rng.normal(0,0.05), 0.01+rng.random()*0.01, sg*(ALLEE/2+PD/2+0.1), 2.0))
# murs : planches verticales une par une (largeurs et teintes differentes, petits jours entre elles)
def mur_long(z, sg):
    x = -L/2
    while x < L/2:
        w = rng.uniform(0.18, 0.3); m = 'vieux' if rng.random() < 0.3 else 'planche'
        add('Murs', B(x+w/2, (HM+0.4)/2, z, w-0.012, HM+0.4+rng.uniform(-0.03,0.03), 0.035, m, 0, rng.normal(0,0.01), rng.normal(0,0.006)))
        x += w
    for y in (0.4, 1.7, 3.0): add('Murs', B(0, y, z-sg*0.08, L, 0.16, 0.08, 'poutre'))
for sg in (-1,1): mur_long(sg*W/2, sg)
for sg in (-1,1):
    z = -W/2
    while z < W/2:
        w = rng.uniform(0.18, 0.3); hz = HM + 2.9*(1-abs(z+w/2)/(W/2)) + 0.25
        if True:                      # grande porte au bout de l'allee
            add('Murs', B(sg*L/2, hz/2, z+w/2, 0.035, hz, w-0.012, 'vieux' if rng.random()<0.3 else 'planche'))
        z += w
# charpente : fermes tous les 3 m (entrait, arbaletriers, poincon, jambes de force), pannes, toit en planches
pente = np.arctan2(2.6, W/2); lr = np.hypot(W/2, 2.6)
for x in np.arange(-L/2+1.5, L/2, 3.0):
    add('Charpente', B(x, HM, 0, 0.2, 0.26, W, 'poutre'))
    add('Charpente', B(x, HM+1.3, 0, 0.16, 2.6, 0.16, 'poutre'))
    for sg in (-1,1):
        add('Charpente', B(x, HM+1.3, sg*W/4, 0.18, 0.22, lr, 'poutre', sg*pente))
        add('Charpente', B(x, HM-0.55, sg*(W/2-0.45), 0.14, 1.1, 0.14, 'poutre', sg*0.75))
        add('Charpente', B(x, HM/2, sg*(W/2-0.12), 0.22, HM, 0.22, 'poutre'))
for sg in (-1,1):
    for f in (0.25, 0.55, 0.85):
        add('Charpente', B(0, HM+2.6*(1-f)+0.14, sg*f*W/2, L, 0.14, 0.12, 'poutre'))
    add('Toit', B(0, HM+1.3+0.22, sg*W/4, L+0.4, 0.04, lr+0.3, 'vieux', sg*pente))
add('Charpente', B(0, HM+2.62, 0, L, 0.22, 0.22, 'poutre'))
add('Toit', B(0, HM+2.86, 0, L+0.4, 0.06, 0.7, 'vieux'))
# enclos : poteaux, lisses, planches basses, portillon en Z sur l'allee, charnieres, auge en fer
for sg in (-1,1):
    zf = sg*ALLEE/2
    for i in range(N+1):
        x = X0 + PW*i
        add('Enclos', B(x, 0.65, zf, 0.14, 1.3, 0.14, 'poutre'))
        add('Enclos', B(x, 0.55, sg*(ALLEE/2+PD/2), 0.06, 1.1, PD, 'vieux'))      # separation entre enclos
        for y in (0.45, 0.85): add('Enclos', B(x, y, sg*(ALLEE/2+PD/2), 0.1, 0.1, PD, 'poutre'))
    for i in range(N):
        x = X0 + PW*(i+0.5)
        gx = x - 0.35                                                            # portillon 1,4 m
        for y in (0.3, 0.75, 1.15): add('Enclos', B(gx, y, zf, 1.4, 0.11, 0.05, 'vieux'))
        add('Enclos', B(gx, 0.72, zf+sg*0.04, 1.55, 0.1, 0.04, 'vieux', 0, 0, 0.58))
        for y in (0.3, 1.15): add('Ferrures', B(gx-0.6, y, zf-sg*0.03, 0.18, 0.05, 0.02, 'fer'))
        for y in (0.35, 0.8, 1.2): add('Enclos', B(x+0.83, y, zf, 1.3, 0.12, 0.05, 'planche'))
        add('Enclos', B(x+0.83, 0.25, zf, 1.3, 0.5, 0.04, 'planche'))
        au = cyl(0.22, 1.1, 'fer', 16); au.apply_transform(T.rotation_matrix(np.pi/2,[0,1,0])); place(au, x+0.8, 0.2, zf+sg*0.4); add('Auges', au)
        if rng.random() < 0.5:
            s = cyl(0.17, 0.32, 'fer', 14); place(s, x+rng.uniform(-1,1), 0.16, sg*(ALLEE/2+PD-0.5), -np.pi/2); add('Seaux', s)
for sg in (-1,1):
    for i in range(N):
        for _ in range(int(rng.integers(1,3))):
            tas = trimesh.creation.icosphere(2, 1.0); v = tas.vertices
            v *= (1 + 0.18*np.sin(v[:,0]*7+rng.random()*6)*np.cos(v[:,2]*6))[:,None]
            tas.vertices = v*np.array([rng.uniform(0.6,1.1), rng.uniform(0.18,0.3), rng.uniform(0.5,0.9)])
            tas.vertices[:,1] = np.maximum(tas.vertices[:,1], 0)
            tas.visual = trimesh.visual.TextureVisuals(uv=np.c_[tas.vertices[:,0], tas.vertices[:,2]+tas.vertices[:,1]]/1.5, material=M['paille'])
            place(tas, X0+PW*(i+0.5)+rng.uniform(-0.8,0.8), 0.0, sg*(ALLEE/2+PD/2+rng.uniform(0,1.0)), 0, rng.random()*3); add('Litiere', tas)
# bottes de foin au fond + quelques tonneaux
for k in range(14):
    x = -L/2+0.8+(k%4)*1.05; z = -W/2+0.8+(k//8)*0.6 + (k%2)*0.6; y = 0.25+0.5*((k//4)%2)
    add('Foin', B(x, y, z+rng.normal(0,0.04), 1.0, 0.48, 0.55, 'paille', 0, rng.normal(0,0.08)))
for (x,z) in [(L/2-1.2, W/2-0.6), (L/2-1.8, W/2-0.7), (-L/2+1.0, W/2-0.7)]:
    t = cyl(0.32, 0.9, 'planche', 18); place(t, x, 0.45, z, -np.pi/2); add('Tonneaux', t)
    for y in (0.15, 0.75): r = cyl(0.335, 0.05, 'fer', 18); place(r, x, y, z, -np.pi/2); add('Tonneaux', r)
# SALLE DU FOND (fermee) : cloison avec une ouverture sur l'allee, plafond bas a poutres serrees,
# grosse table ronde (rebord en fer riveté), chaises au dossier arrondi
XS = L/2 - 7.0                    # cloison
TX = L/2 - 3.6                    # centre de la table
z = -W/2
while z < W/2:
    w = rng.uniform(0.18, 0.3)
    if abs(z + w/2) > 1.3:
        add('Salle', B(XS, (HM+0.4)/2, z+w/2, 0.04, HM+0.4, w-0.01, 'vieux' if rng.random()<0.4 else 'planche'))
    z += w
add('Salle', B(XS, 2.45, 0, 0.25, 0.25, 2.8, 'poutre'))                 # linteau de l'ouverture
for sg in (-1,1): add('Salle', B(XS, 1.2, sg*1.35, 0.22, 2.4, 0.22, 'poutre'))
for k in range(9):                                                      # poutres basses serrees
    add('Salle', B(XS+0.5+k*0.8, 2.75, 0, 0.18, 0.24, W, 'poutre'))
for k in range(5):
    add('Salle', B(XS+3.5, 2.95, -W/2+1.3+k*2.6, 7.0, 0.16, 0.16, 'poutre'))
add('Salle', B(XS+3.5, 3.08, 0, 7.0, 0.04, W, 'vieux'))                # plafond
add('Salle', sol(7.0, W, 'planche', XS+3.5, -0.02, 0, 1.5))            # plancher
def C(r, h, m, x, y, z, sec=40, tu=1.2): t = cyl(r, h, m, sec, tu); return place(t, x, y, z, -np.pi/2)
add('Table', C(1.5, 0.09, 'table', TX, 0.92, 0)); add('Table', C(1.58, 0.14, 'fer', TX, 0.9, 0)); add('Table', C(1.49, 0.1, 'table', TX, 0.93, 0))
for k in range(36):                                                     # rivets
    a = k*2*np.pi/36; add('Table', C(0.025, 0.03, 'fer', TX+1.585*np.cos(a), 0.9, 1.585*np.sin(a), 8))
for k in range(8):                                                      # pied massif a 8 pans + renforts
    a = k*np.pi/4; add('Table', B(TX+0.32*np.cos(a), 0.45, 0.32*np.sin(a), 0.18, 0.86, 0.22, 'poutre', 0, -a, 0))
add('Table', C(0.42, 0.88, 'poutre', TX, 0.45, 0, 8)); add('Table', C(0.95, 0.1, 'poutre', TX, 0.05, 0, 24)); add('Table', C(0.98, 0.04, 'fer', TX, 0.11, 0, 24))
for k in range(5):
    a = k*2*np.pi/5 + 0.3; cx, cz = TX + 2.2*np.cos(a), 2.2*np.sin(a); r = np.pi/2 - a
    parts = [B(0,0.47,0,0.52,0.06,0.5,'table')]
    for dx in (-0.22,0.22):
        for dz in (-0.21,0.21): parts.append(B(dx,0.24 if dz<0 else 0.62,dz,0.06,0.48 if dz<0 else 1.24,0.06,'poutre'))
    for q in range(7):                                                  # dossier arrondi (arc)
        t = q/6; px_ = -0.25+0.5*t; py_ = 1.05+0.16*np.sin(np.pi*t)
        parts.append(B(px_, py_, 0.21, 0.09, 0.1, 0.05, 'table', 0, 0, (0.5-t)*0.9))
    parts.append(B(0, 0.85, 0.21, 0.44, 0.08, 0.04, 'table'))
    for p_ in parts: p_.apply_transform(T.rotation_matrix(r,[0,1,0])); p_.apply_translation([cx,0,cz]); add('Chaises', p_)
add('Lanternes', C(0.01, 0.5, 'fer', TX, 2.5, 0, 6)); add('Lanternes', C(0.13, 0.26, 'lumiere', TX, 2.12, 0, 12))
add('Lanternes', C(0.18, 0.04, 'fer', TX, 2.27, 0, 12)); add('Lanternes', C(0.15, 0.03, 'fer', TX, 1.98, 0, 12))
# lanternes le long de l'allee
for x in np.arange(-L/2+3, L/2-7.5, 6.0):
    add('Lanternes', C(0.01, 0.9, 'fer', x, HM-0.45, 0, 6)); add('Lanternes', C(0.11, 0.24, 'lumiere', x, HM-1.0, 0, 12))
    add('Lanternes', C(0.15, 0.04, 'fer', x, HM-0.86, 0, 12)); add('Lanternes', C(0.13, 0.03, 'fer', x, HM-1.13, 0, 12))
sc = trimesh.Scene()
for nom, ts in P.items():
    pm = {}
    for t in ts: pm.setdefault(t.visual.material.name, []).append(t)
    for mn, l in pm.items(): sc.add_geometry(trimesh.util.concatenate(l), node_name=f'{nom}_{mn}', geom_name=f'{nom}_{mn}')
sc.export('grange_brut.glb'); print('ok', sum(len(g.faces) for g in sc.geometry.values()), 'L', L, 'W', W)
