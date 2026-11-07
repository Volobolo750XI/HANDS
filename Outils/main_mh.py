import json, numpy as np, math, sys, re
import trimesh

# ---------- lecture du modele MakeHuman (CC0) ----------
V=[];VT=[];F=[];FT=[];grp=None
for l in open('base.obj'):
    if l.startswith('v '): V.append([float(x) for x in l.split()[1:4]])
    elif l.startswith('vt '): VT.append([float(x) for x in l.split()[1:3]])
    elif l.startswith('g '): grp=l.split()[1]
    elif l.startswith('f ') and grp=='body':
        a=[x.split('/') for x in l.split()[1:]]
        F.append([int(x[0])-1 for x in a]); FT.append([int(x[1])-1 for x in a])
V=np.array(V); VT=np.array(VT)
sk=json.load(open('default.mhskel')); B=sk['bones']; J=sk['joints']
def jpos(n): return V[J[n]].mean(0)
W=json.load(open('default_weights.mhw'))['weights']

# os de la main droite (descendants de lowerarm01.R)
def desc(n):
    out=[n]
    for k,v in B.items():
        if v['parent']==n: out+=desc(k)
    return out
OS=desc('lowerarm01.R')
head={b:jpos(B[b]['head']) for b in OS}; tail={b:jpos(B[b]['tail']) for b in OS}

def rot(axis,ang):
    axis=axis/np.linalg.norm(axis); a=math.radians(ang)
    K=np.array([[0,-axis[2],axis[1]],[axis[2],0,-axis[0]],[-axis[1],axis[0],0]])
    return np.eye(3)+math.sin(a)*K+(1-math.cos(a))*K@K

# normale de la paume (main droite en T-pose) : calculee depuis les metacarpes
pal_c=np.mean([head[f'metacarpal{i}.R'] for i in range(1,5)],0)
across=head['metacarpal1.R']-head['metacarpal4.R']; along=tail['metacarpal2.R']-head['metacarpal2.R']
PALM=np.cross(along,across); PALM/=np.linalg.norm(PALM)
# verifie le sens : la paume (cote ventral) - teste avec un sommet de la paume
def pose_mesh(angles):
    """angles: os -> (flexion vers la paume, ecart, torsion) en degres (repere de repos)"""
    G={}
    def glob(b):
        if b in G: return G[b]
        p=B[b]['parent']
        Rp,tp=glob(p) if p in OS else (np.eye(3),np.zeros(3))
        L=np.eye(3)
        if b in angles:
            a=angles[b]
            d=tail[b]-head[b]; d/=np.linalg.norm(d)
            ax=np.cross(d,-PALM)
            L=rot(ax,a[0])
            if len(a)>1 and a[1]: L=rot(PALM,a[1])@L
            if len(a)>2 and a[2]: L=rot(d,a[2])@L
        R=Rp@L
        h=head[b]; hp=Rp@h+tp
        t=hp-R@h
        G[b]=(R,t); return G[b]
    for b in OS: glob(b)
    global DERNIER_G; DERNIER_G=G
    P=np.zeros_like(V); Ws=np.zeros(len(V))
    for b in OS:
        if b not in W: continue
        R,t=G[b]
        idx=np.array([x[0] for x in W[b]]); w=np.array([x[1] for x in W[b]])
        np.add.at(P,idx,w[:,None]*(V[idx]@R.T+t)); np.add.at(Ws,idx,w)
    return P,Ws

def main_maillage(angles):
    P,Ws=pose_mesh(angles)
    garde=Ws>0.97
    # avant-bras coupe a mi-longueur : on enleve ce qui est trop loin du poignet (vers le coude)
    wr=head['wrist.R']; coude=head['lowerarm01.R']
    axe=wr-coude; L=np.linalg.norm(axe); axe/=L
    garde&=((V-coude)@axe)>L*0.45
    Fk=[f for f in F if all(garde[i] for i in f)]
    FTk=[ft for f,ft in zip(F,FT) if all(garde[i] for i in f)]
    # triangulation (quads -> 2 triangles)
    tris=[];uvs=[]
    for f,ft in zip(Fk,FTk):
        for k in range(1,len(f)-1):
            tris.append([f[0],f[k],f[k+1]]); uvs.append([ft[0],ft[k],ft[k+1]])
    tris=np.array(tris); uvs=np.array(uvs)
    # sommets "deplies" par coin (pour garder les UV)
    pos=P[tris.reshape(-1)]; uv=VT[uvs.reshape(-1)]
    faces=np.arange(len(pos)).reshape(-1,3)
    # repere : poignet a l'origine, doigts vers +Z, paume vers -Y, en cm (MakeHuman : 1 unite = 1 dm)
    z=tail['metacarpal2.R']+tail['metacarpal3.R']-2*wr; z/=np.linalg.norm(z)
    y=-PALM-(-PALM@z)*z; y/=np.linalg.norm(y); y=-y   # paume vers -Y
    x=np.cross(y,z)
    Rm=np.stack([x,y,z])
    pos=(pos-wr)@Rm.T*10.0
    return pos,faces,uv
