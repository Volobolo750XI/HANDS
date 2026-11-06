# Machine à mains (UEFN)

Jeu de table : chacun son tour, on appuie sur un bouton de la machine. Certains boutons sont piégés :
la mâchoire claque et le joueur est éliminé de la manche. Le dernier en jeu gagne.

## Fichiers
- `Verse/machine_a_mains.verse` : tout le système (un seul appareil `hands_manager`).
- `Modeles/Machine.glb` : la machine stylisée, découpée (Corps, Plaque, Gueule, Bouton_01 à Bouton_24).
- `Modeles/Grange.glb` : le décor (grange, enclos, salle avec la table ronde).

## Déroulé d'un tour
Les joueurs sont **assis** (appareil Chaise) autour de la machine, chacun son tour (sens des aiguilles d'une montre,
ou l'inverse après un REVERSE). Les mains sont **secrètes** : on voit ses cartes en bas de l'écran, et seulement
le **nombre** de cartes des autres.
1. La machine **pivote vers le joueur** (le chemin le plus court ; seul en TestSolo : un tour complet dans le vide).
   Il **pioche 1 carte** (3 max ; chacun commence avec 1 carte).
2. **La carte** : les 6 cartes s'affichent (plus claires au survol). Il en **annonce une en cliquant dessus**,
   **même s'il ne l'a pas** (bluff ; celles qu'il a sont marquées IN HAND), ou clique **NO CARD**.
3. **LIAR!** : pendant 5 s, les autres joueurs **cliquent** pour l'accuser :
   - personne n'accuse → l'effet marche, même si c'était un mensonge ;
   - accusé et il mentait → pas d'effet, **+1 bouton** pour le menteur ;
   - accusé mais c'était vrai → l'effet marche, l'accusateur **perd une carte** et aura **+1 bouton** à son prochain tour.
4. **La machine** : la caméra se place devant la bouche. Il **vise un bouton** (il devient **blanc**, tout le monde le voit)
   et **clique** pour l'enfoncer. 25 s max, sinon un bouton au hasard.
5. Si c'est un **piège**, la mâchoire se **ferme complètement** (60°), le joueur est éliminé et la grille repart à zéro.

Les cartes :
- **DEFUSE** : le piège ne mord pas ce tour-ci ;
- **PEEK** : un bouton sûr s'affiche en vert sur un petit plan du clavier, **sur son écran seulement** ;
- **PASS** : il passe son tour ;
- **REVERSE** : le sens change ;
- **JAM** : le suivant doit appuyer sur 2 boutons ;
- **STEAL** : il **regarde un joueur** et clique : il lui vole une carte au hasard.

## Installation dans UEFN
1. Importe `Machine.glb` avec **Combine Meshes décoché**. Fais de chaque morceau un **accessoire** (Gueule et chaque bouton).
2. Copie le widget **TEST1** de Football Pillars dans un dossier **BOUTON** du projet.
3. Importe les 12 images de `Textures/CartesHands/` dans un dossier **CartesHands** (les 6 cartes + leurs versions `_Survol`).
4. Pose autour de la table **une place par joueur** (petit accessoire invisible devant chaque chaise) et **une Chaise** par place.
5. Pose un **Déclencheur d'entrée** (Input Trigger) réglé sur l'action **Tir** : c'est le clic du jeu.
6. Pose un petit accessoire **blanc** (disque ou cube un peu plus grand qu'un bouton) : le repère du bouton visé.
7. FACULTATIF : une **caméra fixe** par place, devant la bouche de la machine, qui regarde le clavier.
8. Pose l'appareil `hands_manager` et remplis :
   - **Places**, **Chaises** (même ordre), **CamerasClavier** (même ordre, facultatif) ;
   - **Centre** (Corps), **Gueule**, **Plaque**, **Touches** (Bouton_01 → Bouton_24) ;
   - **Surbrillance** (l'accessoire blanc) et **ToucheClic** (le Déclencheur d'entrée) ;
   - les 4 **Audio Players** : clic, claquement, carte, et **SonRotation** (en boucle pendant que la machine tourne).
9. Si la machine ne fait pas face au bon joueur, change **FaceDepart** (90, 180 ou -90).
   Si la mâchoire tourne dans le mauvais sens, change **AxeFermeture** (0, 1 ou 2) ou mets un **AngleFermeture** négatif.
   Si le bouton visé ne suit pas bien le regard, augmente **PorteeVisee** (en cm).
10. Pour tester seul : coche **TestSolo** (à décocher avant de publier).

## Animation (se pencher et appuyer)
Prends sur Mixamo une animation « Button Pushing » ou « Reaching », convertis-la pour le squelette Fortnite
(comme les danses de Football Pillars), puis mets-la dans **AnimAppui**. Vide = pas d'animation.
