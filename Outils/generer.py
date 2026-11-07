import sys,math,numpy as np,trimesh,itertools
sys.path.insert(0,'/tmp/claude-0/-home-user/98b25f03-d56a-5dd2-b81e-ebf48c661066/scratchpad/mains')
exec(open('main_mh.py').read())
import mains
from PIL import Image, ImageFilter

DOIGTS=(2,3,4,5)
def poing(sauf=()):
    P={}
    for f in DOIGTS:
        if f in sauf: continue
        P[f'finger{f}-1.R']=(85,); P[f'finger{f}-2.R']=(95,); P[f'finger{f}-3.R']=(60,)
    return P

def bout(b):
    R,t=DERNIER_G[b]; return R@tail[b]+t

def chercher_pouce(base, cible_os, rond=False):
    """cherche les angles du pouce pour que son bout touche le bout de cible_os.
    rond=True : on prefere un pouce peu plie (le rond du OK reste bien ouvert)"""
    best=None
    for a1,e1,a2,a3,tw in itertools.product(range(-10,61,10),range(-40,41,10),range(0,71,10),range(0,61,15),(-30,-15,0,15,30)):
        A=dict(base); A['finger1-1.R']=(a1,e1,tw); A['finger1-2.R']=(a2,); A['finger1-3.R']=(a3,)
        pose_mesh_light(A)
        d=np.linalg.norm(bout('finger1-3.R')-bout(cible_os))
        cout=d+((a2+a3)*0.0015 if rond else 0)
        if best is None or cout<best[0]: best=(cout,A)
    return best

def pose_mesh_light(angles):
    # seulement le squelette (rapide) : meme calcul que pose_mesh sans la peau
    G={}
    def glob(b):
        if b in G: return G[b]
        p=B[b]['parent']
        Rp,tp=glob(p) if p in OS else (np.eye(3),np.zeros(3))
        L=np.eye(3)
        if b in angles:
            a=angles[b]; d=tail[b]-head[b]; d/=np.linalg.norm(d)
            L=rot(np.cross(d,-PALM),a[0])
            if len(a)>1 and a[1]: L=rot(PALM,a[1])@L
            if len(a)>2 and a[2]: L=rot(d,a[2])@L
        R=Rp@L; h=head[b]; t=Rp@h+tp-R@h
        G[b]=(R,t); return G[b]
    for b in OS: glob(b)
    global DERNIER_G; DERNIER_G=G

def construire(angles):
    pos,faces,uv=main_maillage(angles)
    m=trimesh.Trimesh(pos,faces,process=False)
    m.visual=trimesh.visual.TextureVisuals(uv=uv)
    m.merge_vertices(merge_tex=False,merge_norm=True)
    parts=m.split(only_watertight=False); m=max(parts,key=lambda q:len(q.faces))
    # coupe nette de l'avant-bras a 7 cm sous le poignet
    keep=(m.vertices[m.faces][:,:,2]>-7.0).all(1)
    m.update_faces(keep); m.remove_unreferenced_vertices()
    # lissage : 2 subdivisions (les UV suivent) + filtre de Taubin (garde le volume)
    for _ in range(2):
        m=m.subdivide()
    # lissage sur la forme SOUDEE (sinon les coutures de texture s'ouvrent), puis on recopie les positions
    cle=np.round(m.vertices,4)
    uniq,inv=np.unique(cle,axis=0,return_inverse=True)
    inv=inv.reshape(-1)
    mw=trimesh.Trimesh(uniq,inv[m.faces],process=False)
    trimesh.smoothing.filter_taubin(mw,lamb=0.5,nu=-0.53,iterations=12)
    m.vertices=mw.vertices[inv]
    return m

# ---------- texture de peau (dans l'espace UV) ----------
def texture_peau(m, taille=2048):
    rng=np.random.default_rng(7)
    H=taille
    def bruit(echelle,amp):
        n=rng.normal(size=(H//echelle+2,H//echelle+2))
        im=Image.fromarray(((n-n.min())/(np.ptp(n))*255).astype(np.uint8)).resize((H,H),Image.BICUBIC)
        return (np.asarray(im)/255.0-0.5)*amp
    base=np.array([206,196,188],float)/255
    t=np.ones((H,H,3))*base
    t+= (bruit(256,0.10)+bruit(64,0.05))[...,None]*np.array([1.0,0.9,0.85])   # marbrures
    t+= bruit(4,0.05)[...,None]                                               # pores
    t-= np.clip(bruit(2,0.06),0,None)[...,None]*0.6                           # micro-salete
    # taches bleutees / grises (peau malade, discret)
    tache=np.clip(bruit(128,0.5),0,None)
    t-= tache[...,None]*np.array([0.06,0.04,0.0])
    img=Image.fromarray((np.clip(t,0,1)*255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(0.6))
    return img

def couleurs_sommets(m):
    # pour l'apercu : texture echantillonnee aux UV des sommets + ongles + articulations
    return None

def rendu(m, tex, out, yaw, pitch=8, size=900, fond=(40,38,42)):
    # echantillonne la texture par sommet (apercu)
    T=np.asarray(tex).astype(float)
    uv=m.visual.uv
    px=np.clip((uv[:,0]*(T.shape[1]-1)).astype(int),0,T.shape[1]-1)
    py=np.clip(((1-uv[:,1])*(T.shape[0]-1)).astype(int),0,T.shape[0]-1)
    col=T[py,px]
    mm=m.copy(); mm.visual=trimesh.visual.ColorVisuals(mm,vertex_colors=np.c_[col,np.full(len(col),255)].astype(np.uint8))
    mains.render(mm,out,yaw=yaw,pitch=pitch,size=size)

POSES={}
POSES['Ouverte']={f'finger{f}-1.R':(0,e) for f,e in zip(DOIGTS,(4,0,-4,-8))}
POSES['Pouce']=dict(poing(), **{'finger1-1.R':(-10,10),'finger1-2.R':(0,),'finger1-3.R':(0,)})
POSES['Pointe']=poing(sauf=(2,))
POSES['OK']={'finger2-1.R':(32,),'finger2-2.R':(48,),'finger2-3.R':(32,),
             'finger3-1.R':(4,2),'finger3-2.R':(6,),'finger4-1.R':(8,-6),'finger4-2.R':(10,),
             'finger5-1.R':(14,-14),'finger5-2.R':(14,),'finger5-3.R':(8,)}

if __name__=='__main__':
    # le pouce du OK touche le bout de l'index ; celui du doigt pointe se pose sur le majeur replie
    d,A=chercher_pouce(POSES['OK'],'finger2-3.R',rond=True); POSES['OK']=A; print('OK : ecart pouce-index',round(d,3))
    best=min((chercher_pouce(POSES['Pointe'],c) for c in ('finger3-1.R','finger3-2.R','finger2-1.R')),key=lambda x:x[0])
    POSES['Pointe']=best[1]; print('Pointe : ecart',round(best[0],3))
    tex=texture_peau(None)
    tex.save('peau.png')
    for nom in (sys.argv[1:] or POSES):
        m=construire(POSES[nom])
        if nom=='Pouce':
            pose_mesh_light(POSES[nom])
            wr=head['wrist.R']
            z=tail['metacarpal2.R']+tail['metacarpal3.R']-2*wr; z/=np.linalg.norm(z)
            y=PALM-(PALM@z)*z; y/=np.linalg.norm(y)
            x=np.cross(y,z); Rm=np.stack([x,y,z])
            dpo=Rm@(bout('finger1-3.R')-DERNIER_G['finger1-2.R'][0]@head['finger1-2.R']-DERNIER_G['finger1-2.R'][1])
            dpo=dpo/np.linalg.norm(dpo)
            # rotation qui amene la direction du pouce sur +Z
            ax=np.cross(dpo,[0,0,1.0]); ang=math.degrees(math.acos(np.clip(dpo[2],-1,1)))
            if np.linalg.norm(ax)>1e-6:
                m.apply_transform(trimesh.transformations.rotation_matrix(math.radians(ang),ax/np.linalg.norm(ax)))
        m.export(f'MH_{nom}.glb')
        for i,y in enumerate((-35,60,150)):
            rendu(m,tex,f'r_{nom}_{i}.png',y,size=450)
        c=Image.new('RGB',(1350,450))
        for i in range(3): c.paste(Image.open(f'r_{nom}_{i}.png'),(i*450,0))
        c.save(f'planche_{nom}.png'); print(nom,len(m.faces))

# ================= TEXTURE REALISTE =================
from scipy.ndimage import gaussian_filter
from scipy.spatial import cKDTree

def attributs(m, angles):
    """par sommet : creux, ongle, articulation, paume (cote paume = 1), bout des doigts"""
    cle=np.round(m.vertices,4); uniq,inv=np.unique(cle,axis=0,return_inverse=True); inv=inv.reshape(-1)
    mw=trimesh.Trimesh(uniq,inv[m.faces],process=False)
    nb=mw.vertex_neighbors
    moy=np.array([mw.vertices[n].mean(0) if len(n) else mw.vertices[i] for i,n in enumerate(nb)])
    lap=((moy-mw.vertices)*mw.vertex_normals).sum(1)
    creux=np.clip(lap/0.05,0,1)
    P,Ws=pose_mesh(angles)
    G=DERNIER_G
    wr=head['wrist.R']
    z=tail['metacarpal2.R']+tail['metacarpal3.R']-2*wr; z/=np.linalg.norm(z)
    y=-PALM-(-PALM@z)*z; y/=np.linalg.norm(y); y=-y; x=np.cross(y,z); Rm=np.stack([x,y,z])
    Pc=(P-wr)@Rm.T*10.0
    kd=cKDTree(Pc); _,idx=kd.query(mw.vertices)
    n=len(mw.vertices)
    # l'os principal de chaque sommet -> la direction de SA paume une fois pose
    meilleur=np.full(len(V),-1.0); os_de=np.empty(len(V),dtype=object)
    for b in OS:
        if b not in W: continue
        for vi,w in W[b]:
            if w>meilleur[vi]: meilleur[vi]=w; os_de[vi]=b
    paume_dir={b:(G[b][0]@PALM)@Rm.T for b in OS}
    paume=np.zeros(n)
    nrm=mw.vertex_normals
    for k in range(n):
        b=os_de[idx[k]]
        if b is None: continue
        pd=paume_dir[b]; pd=pd/np.linalg.norm(pd)
        paume[k]=np.clip(0.5+1.4*(nrm[k]@pd),0,1)
    ongle=np.zeros(n); artic=np.zeros(n); bouts=np.zeros(n)
    for f in (1,2,3,4,5):
        b=f'finger{f}-3.R'
        wb=np.zeros(len(V)); ii=np.array([q[0] for q in W[b]]); wb[ii]=[q[1] for q in W[b]]
        R,t=G[b]
        bout_c=((R@tail[b]+t)-wr)@Rm.T*10.0
        dos=(R@(-PALM))@Rm.T; dos/=np.linalg.norm(dos)
        d_bout=np.linalg.norm(mw.vertices-bout_c,axis=1)
        o=(wb[idx]>0.6)*np.clip(((nrm@dos)-0.35)/0.3,0,1)*np.clip((1.45-d_bout)/0.35,0,1)
        ongle=np.maximum(ongle,o)
        bouts=np.maximum(bouts,np.clip((1.6-d_bout)/1.6,0,1))
    for b in [f'finger{f}-{k}.R' for f in (1,2,3,4,5) for k in (1,2,3)]:
        R,t=G[b]; j=((R@head[b]+t)-wr)@Rm.T*10.0
        d=np.linalg.norm(mw.vertices-j,axis=1)
        artic=np.maximum(artic,np.clip((0.7-d)/0.7,0,1))
    return creux[inv],ongle[inv],artic[inv],paume[inv],bouts[inv]

def peindre(m, angles, H=2048):
    creux,ongle,artic,paume,bouts=attributs(m,angles)
    uv=m.visual.uv
    px=np.clip((uv[:,0]*(H-1)).astype(int),0,H-1); py=np.clip(((1-uv[:,1])*(H-1)).astype(int),0,H-1)
    def splat(val,flou=4):
        acc=np.zeros((H,H)); cnt=np.zeros((H,H))
        np.add.at(acc,(py,px),val); np.add.at(cnt,(py,px),1)
        acc=gaussian_filter(acc,flou); cnt=gaussian_filter(cnt,flou)
        return np.where(cnt>1e-4,acc/np.maximum(cnt,1e-4),0)
    C=splat(creux,3); O=splat(ongle,3); A=splat(artic); Pm=splat(paume,6); Bt=splat(bouts,6)
    rng=np.random.default_rng(11)
    def bruit(echelle,amp):
        n=rng.normal(size=(H//echelle+2,H//echelle+2))
        im=Image.fromarray(((n-n.min())/(np.ptp(n))*255).astype(np.uint8)).resize((H,H),Image.BICUBIC)
        return (np.asarray(im)/255.0-0.5)*amp
    # PEAU REELLE : beige un peu froid (dos de la main), paume plus claire et plus rosee
    dos_col=np.array([196,168,150])/255
    paume_col=np.array([214,180,162])/255
    t=dos_col*(1-Pm[...,None])+paume_col*Pm[...,None]
    # variations naturelles : zones plus rouges / plus jaunes / plus froides
    t+=bruit(160,0.10)[...,None]*np.array([0.9,0.5,0.35])
    t+=bruit(48,0.05)[...,None]*np.array([0.6,0.65,0.7])
    # rougeur : articulations, bout des doigts, plis
    rouge=np.array([0.10,-0.01,-0.03])
    t+=(A*0.55+Bt*0.45)[...,None]*rouge
    # veines bleu-vert tres discretes sur le dos de la main
    v=np.abs(bruit(90,1.0)); veine=np.clip((0.035-v)/0.035,0,1)*(1-Pm)*(1-Bt)
    t+=veine[...,None]*np.array([-0.05,-0.01,0.03])
    # pores + grain de peau + petites taches de rousseur
    t*= (1+bruit(3,0.07)+bruit(1,0.04))[...,None]
    taches=np.clip((bruit(6,1.0)-0.42)/0.06,0,1)*(1-Pm)*0.5
    t-= taches[...,None]*np.array([0.06,0.08,0.09])
    # plis plus sombres et un peu rouges (lignes de la paume, entre les doigts, articulations)
    t*= (1-0.38*C)[...,None]
    t+= (C*0.04)[...,None]*np.array([1.0,0.2,0.1])
    # ongles : rose-beige, lunule et bord libre plus clairs, bord un peu sale
    ongle_col=np.array([222,190,180])/255
    t=t*(1-O[...,None])+ongle_col*O[...,None]
    bord=np.clip(O*4,0,1)*np.clip((1-O)*4,0,1)
    t*= (1-0.22*bord)[...,None]
    # un peu "froid" : on retire une pointe de saturation (style horreur), sans devenir gris
    g=t.mean(-1,keepdims=True); t=g+(t-g)*0.86
    img=Image.fromarray((np.clip(t,0,1)*255).astype(np.uint8))
    return img

def exporter(m, tex, nom):
    mat=trimesh.visual.material.PBRMaterial(name=f'Peau_{nom}',baseColorTexture=tex,roughnessFactor=0.62,metallicFactor=0.0)
    mm=m.copy(); mm.visual=trimesh.visual.TextureVisuals(uv=m.visual.uv,material=mat)
    mm.apply_scale(0.01)    # cm -> m (pivot au poignet)
    mm.export(f'Mains/Main_{nom}.glb')
