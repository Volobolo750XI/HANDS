# Morsure (UEFN)

Jeu de table : chacun son tour, on appuie sur un bouton de la machine. Certains boutons sont piégés :
la mâchoire claque et le joueur est éliminé de la manche. Le dernier en jeu gagne.

## Fichiers
- `Verse/morsure.verse` : tout le système (un seul appareil `hands_manager`).
- `Modeles/Machine.glb` : la machine stylisée, découpée (Corps, Plaque, Gueule, Bouton_01 à Bouton_24).
- `Modeles/Grange.glb` : le décor (grange, enclos, salle avec la table ronde).

## Déroulé d'un tour
Au début de la manche, les **règles** s'affichent 6 s. Les joueurs sont **assis** autour de la machine.
Chacun commence avec **2 cartes** (3 max). On voit **sa main en bas de l'écran** ; des autres, seulement le **nombre**.
Tous les textes (chrono, danger, messages, boutons) sont écrits au **pinceau** (dossier Ecriture).
1. La machine **pivote vers le joueur** (son de rotation, puis **« clac »** à l'arrêt).
2. **SON CHOIX** : **PLAY A CARD** ou **DRAW A CARD** (0 carte : seulement piocher ; 3 cartes : seulement jouer).
3. **PLAY A CARD** : il clique une carte, puis **TRUTH** (il la joue pour ce qu'elle est) ou **LIE**
   (il dit que c'est une autre : « SAY IT IS... »). **BACK** pour revenir en arrière.
4. Sa carte est posée **face cachée** : « P1 PLAYS: JAM ». Les autres ont 5 s pour **cliquer** (LIAR? CLICK TO ACCUSE!) :
   - personne n'accuse → l'effet de la carte **annoncée** s'applique, même si c'était un bluff ;
   - accusé → la carte est **retournée** : **LIE!** (pas d'effet, +1 bouton pour le menteur)
     ou **TRUTH!** (l'effet s'applique, l'accusateur perd une carte et aura +1 bouton).
5. **LA MACHINE** : il clique un bouton de la machine (il devient blanc au survol). Piège → la mâchoire se ferme.

**Les JAM se cumulent, comme les +2 d'un Uno** : un gros **« +1 », « +2 », « +3 »…** surgit à l'écran.
Celui qui reçoit des JAM peut jouer un JAM (vrai ou bluff !) pour **tout passer au suivant, +1**.
Sinon, il appuie sur **tous** ces boutons en plus. PASS fait aussi passer les JAM au suivant.

Les cartes : **DEFUSE** (le piège ne mord pas), **PEEK** (un bouton sûr devient vert), **PASS** (il passe),
**REVERSE** (le sens change), **JAM** (le suivant appuie sur 2 boutons), **STEAL** (il regarde un joueur et clique :
il lui vole une carte).

Les textes et les boutons sont écrits au **pinceau** (dossier **Ecriture**) ; un bouton devient blanc et grossit au survol.

## Installation dans UEFN
1. Importe `Machine.glb` avec **Combine Meshes décoché**. Fais de chaque morceau un **accessoire** (Gueule et chaque bouton).
2. Copie le widget **TEST1** de Football Pillars dans un dossier **BOUTON** du projet.
3. Importe les 100 images de `Textures/Ecriture/` dans un dossier **Ecriture**, et les 12 images de `Textures/Reliques/` dans un dossier **Reliques** (Relique_Bouclier, _Serrure, _Sablier, _Chaine, _Etau, _Corbeau + leurs versions `_Lueur`).
4. Pose autour de la table **une place par joueur** (petit accessoire invisible devant chaque chaise) et **une Chaise** par place.
5. Pose un **Déclencheur d'entrée** (Input Trigger) réglé sur l'action **Tir** : c'est le clic du jeu.
6. Crée un dossier **Teintes** avec 3 matériaux : **T_Base** (copie du matériau actuel des boutons),
   **T_Clair** (le bouton visé, blanc lumineux) et **T_Sur** (le bouton sûr du PEEK, vert lumineux).
7. FACULTATIF : une **caméra fixe** par place, devant la bouche de la machine, qui regarde le clavier.
8. Pose l'appareil `hands_manager` et remplis :
   - **Places**, **Chaises** (même ordre), **CamerasClavier** (même ordre, facultatif) ;
   - **AnimationAssise** (facultatif) : une animation assise Mixamo. Les joueurs restent alors à la première personne
     (pas de vraie chaise : ils sont figés à leur Place et jouent l'animation en boucle) ;
   - **Centre** (Corps), **Gueule**, **Plaque**, **Touches** (Bouton_01 → Bouton_24) ;
   - **ToucheClic** (le Déclencheur d'entrée) ; **IndexMateriau** = l'emplacement de matériau du bouton (0 en général) ;
   - les **Audio Players** : clic, claquement, carte, **SonRotation** (en boucle pendant que la machine tourne)
     et **SonArret** (le « clac » quand elle s'arrête sur un joueur).
9. Si la machine ne fait pas face au bon joueur, change **FaceDepart** (90, 180 ou -90).
   Si la mâchoire tourne dans le mauvais sens, change **AxeFermeture** (0, 1 ou 2) ou mets un **AngleFermeture** négatif.
   Si le bouton visé ne suit pas bien le regard, augmente **PorteeVisee** (en cm).
10. Pour tester seul : coche **TestSolo** (à décocher avant de publier).

## Animation (se pencher et appuyer)
Prends sur Mixamo une animation « Button Pushing » ou « Reaching », convertis-la pour le squelette Fortnite
(comme les danses de Football Pillars), puis mets-la dans **AnimAppui**. Vide = pas d'animation.
