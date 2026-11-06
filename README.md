# Machine à mains (UEFN)

Jeu de table : chacun son tour, on appuie sur un bouton de la machine. Certains boutons sont piégés :
la mâchoire claque et le joueur est éliminé de la manche. Le dernier en jeu gagne.

## Fichiers
- `Verse/machine_a_mains.verse` : tout le système (un seul appareil `hands_manager`).
- `Modeles/Machine.glb` : la machine stylisée, découpée (Corps, Plaque, Gueule, Bouton_01 à Bouton_24).
- `Modeles/Grange.glb` : le décor (grange, enclos, salle avec la table ronde).

## Déroulé d'un tour (avec le BLUFF)
Les joueurs sont assis (ils peuvent tourner la tête), chacun son tour dans le sens des aiguilles d'une montre.
Les mains sont **secrètes** : on voit ses cartes en images en bas de l'écran, et seulement le **nombre** de cartes des autres.
1. Le joueur actif **pioche 1 carte** (3 cartes max en main ; chacun commence avec 1 carte).
2. Il peut **annoncer 1 carte**, **même s'il ne l'a pas** (bluff) :
   - DEFUSE : le piège ne mord pas ce tour-ci ;
   - PEEK : un bouton sûr s'allume en vert 3 s (pour lui seul), puis il peut **montrer un bouton à tous** (vrai ou faux) ;
   - PASS : il passe son tour ;
   - REVERSE : le sens change ;
   - JAM : le suivant doit appuyer sur 2 boutons ;
   - STEAL : il vole une carte au hasard au joueur de son choix.
3. Les autres ont **5 s pour crier LIAR!** :
   - personne n'accuse → l'effet marche, même si c'était un mensonge ;
   - accusé et il mentait → pas d'effet, **+1 bouton** pour le menteur ;
   - accusé mais c'était vrai → l'effet marche, l'accusateur **perd une carte** et aura **+1 bouton** à son prochain tour.
4. Il **appuie** sur un bouton (20 s max, sinon un bouton au hasard). L'écran affiche le **% de danger**.
5. Si c'est un **piège**, la mâchoire se ferme, le joueur est éliminé et la grille repart à zéro (nouveaux pièges).

## Installation dans UEFN
1. Importe `Machine.glb` avec **Combine Meshes décoché**. Fais de chaque morceau un **accessoire** (Gueule et chaque bouton).
2. Pose autour de la table **une place par joueur** : un petit accessoire invisible devant chaque chaise.
3. Importe les images de `Textures/CartesHands/` dans un dossier **CartesHands** du Tiroir à contenu
   (Carte_Defuse, Carte_Peek, Carte_Pass, Carte_Reverse, Carte_Jam, Carte_Steal). Pour mettre tes propres images,
   remplace-les en gardant les mêmes noms.
4. Pose l'appareil `hands_manager` et remplis :
   - **Places** ;
   - **Centre** (Corps) et **Gueule** ;
   - **Touches** : les 24 boutons dans l'ordre Bouton_01 → Bouton_24 ;
   - **Plaque** (le support du clavier) ;
   - les 4 **Audio Players** : clic, claquement, carte, et **SonRotation** (son en boucle pendant que la machine tourne).
4. À chaque tour, **toute la machine pivote** vers le joueur qui joue, avec le son de rotation, coupé à l'arrêt.
   Si elle ne fait pas face au bon joueur, change **FaceDepart** (par exemple 90, 180 ou -90).
5. Si la mâchoire tourne dans le mauvais sens, change **AxeFermeture** (0, 1 ou 2) ou mets un **AngleFermeture** négatif.

## Animation (se pencher et appuyer)
Prends sur Mixamo une animation « Button Pushing » ou « Reaching », convertis-la pour le squelette Fortnite
(comme les danses de Football Pillars), puis mets-la dans **AnimAppui**. Vide = pas d'animation.
