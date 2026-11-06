# Verifications avant d'envoyer du Verse (erreurs deja rencontrees) :
#  - fonction sans <transacts>/<decides> appelee dans une condition if/for (3512)
#  - condition if/for coupee sur plusieurs lignes (3506)
# usage : python3 Outils/verifier_verse.py
import re, glob
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
print('verification terminee')
