# Verifications avant d'envoyer du Verse (erreurs deja rencontrees) :
#  - fonction sans <transacts>/<decides> appelee dans une condition if/for (3512)
#  - condition if/for coupee sur plusieurs lignes (3506)
# usage : python3 Outils/verifier_verse.py
import re, glob, sys, builtins
ERREURS = 0
_print = builtins.print
def print(*a, **k):
    global ERREURS
    if a and a[0] != 'verification terminee':
        ERREURS += 1
    _print(*a, **k)
for f in glob.glob('Verse/*.verse'):
    L = open(f).read().split('\n')
    trans, toutes = set(), set()
    for l in L:
        m = re.match(r'^(?:    )?([A-Z]\w*)(<[^>]*>)?\((.*?)\)', l)
        if m and ':' in l:
            toutes.add(m.group(1))
            if re.search(r'\)\s*<[^>]*(transacts|decides|computes|converges)', l):
                trans.add(m.group(1))
    for i, l in enumerate(L):
        l = re.sub(r"'[^'\\]'", "'c'", l)          # un caractere entre apostrophes ('(' ...) n'est pas une parenthese
        m = re.match(r'\s*(else if|if|for)\s*\(', l)
        if not m:
            continue
        reste = l[m.end() - 1:]
        prof = 0; fin = None
        for j, ch in enumerate(reste):
            prof += (ch == '(') - (ch == ')')
            if prof == 0:
                fin = j; break
        if fin is None:
            print(f, i + 1, '3506 condition sur plusieurs lignes :', l.strip()[:80]); continue
        cond = reste[1:fin]
        for fn in re.findall(r'(?<![\.\w])([A-Z]\w*)\(', cond):
            if fn in toutes and fn not in trans:
                print(f, i + 1, '3512 ' + fn + ' appelee dans une condition :', l.strip()[:80])
    for i, l in enumerate(L):
        if re.search(r'\bnot\s+\w+\.(TeleportTo|MoveTo|Damage|Respawn|Remove|Grant\w*)\[', l):
            print(f, i + 1, 'not devant une action (Verse annule son effet) :', l.strip()[:80])
    for i, l in enumerate(L):
        if re.match(r'\s*continue\s*$', l):
            print(f, i + 1, "'continue' n'existe pas en Verse :", l.strip()[:80])
        if re.search(r'option\{[^}]*\.Await\(', l):
            print(f, i + 1, '3512 Await dans option{...} :', l.strip()[:80])
    # chaque fonction appelee doit exister (dans le fichier ou dans Verse) : evite d'en supprimer une par erreur
    sans_textes = re.sub(r'"[^"]*"', '""', '\n'.join(L))
    definies = set(re.findall(r'^\s*([A-Z]\w*)(?:<[^>]*>)*\([^\n]*?\)(?:<[^>]*>)*\s*:\s*[^=\n]+=', sans_textes, re.M))
    variables = set(re.findall(r'\b([A-Z]\w*)\s*:=', sans_textes))
    appels = set(re.findall(r'(?<![\.\w])([A-Z]\w*)\(', sans_textes))
    connues = {'Sleep', 'Max', 'Min', 'Abs', 'Floor', 'Ceil', 'Mod', 'ArcTan', 'Tan', 'Sin', 'Cos', 'Sqrt', 'DotProduct',
               'DegreesToRadians', 'MakeRotation', 'MakeRotationFromYawPitchRollDegrees', 'GetRandomInt', 'GetRandomFloat',
               'GetSimulationElapsedTime', 'GetSecondsSinceEpoch', 'GetPlayspace', 'GetPlayerUI', 'ToString', 'ConcatenateMaps',
               'IdentityRotation', 'Distance', 'Lerp', 'TEST1'}
    for fn in sorted(appels - definies - variables - connues):
        print(f, '3506 fonction appelee mais introuvable :', fn)
    # BOUCLE SANS VRAIE PAUSE : une boucle qui n'attend que par MoveTo / PlayAndAwait / Fondu peut tourner a
    # l'infini si l'appel se termine tout de suite (accessoire cache...) -> ComputationLimitExceeded, tout le code s'arrete
    for i, l in enumerate(L):
        if l.strip() != 'loop:':
            continue
        ind = len(l) - len(l.lstrip())
        corps = []
        for m in L[i + 1:]:
            if m.strip() == '':
                continue
            if len(m) - len(m.lstrip()) <= ind:
                break
            corps.append(m)
        txt = '\n'.join(corps)
        if not re.search(r'Sleep\(|Await\(|\bbreak\b|\breturn\b', txt):
            print(f, i + 1, 'BOUCLE SANS Sleep/Await ni break (risque de boucle infinie)')
print('verification terminee')
sys.exit(1 if ERREURS else 0)
