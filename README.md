# Machine à mains (UEFN)

Jeu de table : chacun son tour, on appuie sur un bouton de la machine. Certains boutons sont piégés :
la mâchoire claque et le joueur est éliminé de la manche. Le dernier en jeu gagne.

## Fichiers
- `Verse/machine_a_mains.verse` : tout le système (un seul appareil `hands_manager`).
- `Modeles/Machine.glb` : la machine stylisée, découpée (Corps, Plaque, Gueule, Bouton_01 à Bouton_24).
- `Modeles/Grange.glb` : le décor (grange, enclos, salle avec la table ronde).

## Déroulé d'un tour
1. Le joueur actif **pioche 1 carte** (3 cartes max en main ; chacun commence avec 1 carte).
2. Il peut **jouer 1 carte** :
   - DEFUSE : le piège ne mord pas ce tour-ci ;
   - PEEK : un bouton sûr s'allume en vert 3 s ;
   - PASS : il passe son tour ;
   - REVERSE : le sens change ;
   - JAM : le suivant doit appuyer sur 2 boutons ;
   - STEAL : il vole une carte.
3. Il **appuie** sur un bouton (20 s max, sinon un bouton au hasard). L'écran affiche le **% de danger**.
4. Si c'est un **piège**, la mâchoire se ferme, le joueur est éliminé et la grille repart à zéro (nouveaux pièges).

## Installation dans UEFN
1. Importe `Machine.glb` avec **Combine Meshes décoché**. Fais de chaque morceau un **accessoire** (Gueule et chaque bouton).
2. Pose autour de la table **une place par joueur** : un petit accessoire invisible devant chaque chaise.
3. Pose l'appareil `hands_manager` et remplis :
   - **Places** ;
   - **Centre** (Corps) et **Gueule** ;
   - **Touches** : les 24 boutons dans l'ordre Bouton_01 → Bouton_24 ;
   - les 3 **Audio Players** (clic, claquement, carte).
4. Si la mâchoire tourne dans le mauvais sens, change **AxeFermeture** (0, 1 ou 2) ou mets un **AngleFermeture** négatif.

## Animation (se pencher et appuyer)
Prends sur Mixamo une animation « Button Pushing » ou « Reaching », convertis-la pour le squelette Fortnite
(comme les danses de Football Pillars), puis mets-la dans **AnimAppui**. Vide = pas d'animation.
