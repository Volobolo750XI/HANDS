Tu es architecte d'intérieur et level designer pour un jeu Fortnite créé avec UEFN (Unreal Editor for Fortnite). Ta mission : concevoir le LOBBY du jeu, pièce par pièce et objet par objet, comme un vrai architecte qui dessine des plans.

LE JEU
- "HANDS" : un jeu d'horreur de bluff autour d'une table. Une machine-mâchoire (genre crocodile dentiste géant) est au milieu de la table, avec 24 boutons ; un des boutons mord.
- Le public : des enfants et des ados. Ambiance horreur, sombre, inquiétante, mais SANS sang, SANS gore, SANS rouge sang (risque de sanction Fortnite).
- Jusqu'à 12 joueurs sur le serveur.

LE LIEU : UNE VIEILLE GRANGE ABANDONNÉE, ULTRA RÉALISTE
- Bois ancien, poutres, paille, poussière, lumière chaude et faible (lampes à huile, rayons de lumière à travers les planches), brouillard léger.
- Le style de référence : le lobby du jeu "Hands Over" (grange sombre en bois, cordes qui pendent d'une poutre, paille au sol, enclos).

CE QUE LE LOBBY DOIT CONTENIR (contraintes de gameplay, obligatoires)
1. Un point d'apparition (spawn) pour 12 joueurs.
2. TROIS ZONES DE DÉPART, une par table de jeu. Chaque zone accueille 4 joueurs maximum. Quand au moins 2 joueurs restent 10 secondes dans une zone, ils partent jouer à SA table. La zone doit être très lisible pour un enfant : on doit comprendre tout de suite "je me mets ici pour jouer" (sol marqué, cercle de lumière, panneau, numéro 1 / 2 / 3...).
3. TROIS TABLES DE JEU, une par zone (chaque table : une table ronde, 4 chaises, la machine-mâchoire au centre). Les tables peuvent être dans d'autres pièces de la grange (box, étable, grenier...) ou séparées, mais un joueur assis ne doit pas voir les autres tables de trop près.
4. Un point de retour au lobby (où les joueurs reviennent après une partie).
5. (Plus tard, à prévoir mais pas à détailler maintenant) un emplacement pour un futur shop.

CE QUE JE VEUX QUE TU ME RENDES
A. Un PLAN DE MASSE vu du dessus (schéma ou image) avec les dimensions en mètres : murs, portes, pièces, spawn, les 3 zones, les 3 tables, le chemin des joueurs.
B. Une explication pièce par pièce, comme un architecte : à quoi sert chaque endroit, ce qu'on y ressent, pourquoi c'est placé là.
C. Une LISTE D'OBJETS précise pour chaque endroit : "ici, contre le mur nord : 2 bottes de foin empilées, une fourche, une lanterne accrochée à 2 m..." avec la position approximative (en mètres depuis un coin de référence) et la rotation.
D. Pour chaque objet : où le trouver. Dans l'ordre de préférence :
   1. dans les galeries et accessoires Fortnite déjà présents dans UEFN (donne le nom à chercher) ;
   2. sur Fab (fab.com) ou Sketchfab, gratuits et sous licence CC0 ou CC-BY (donne le lien et la licence) ;
   3. sinon, un prompt pour le générer en 3D (Meshy, Tripo, Rodin).
E. L'ÉCLAIRAGE : chaque lumière (type, couleur, intensité, position) + le brouillard et l'ambiance (post-process) pour un rendu ultra réaliste, sombre mais où les enfants voient où aller.
F. Les SONS d'ambiance à placer (vent, bois qui grince, animaux au loin...).
G. Les contraintes techniques UEFN : reste dans un budget raisonnable de mémoire et de performances (le jeu doit tourner sur console et mobile), évite les objets inutiles.

H. LE LIVRABLE FINAL, OBLIGATOIRE : LE MODÈLE 3D DU LOBBY.
   À la fin, tu dois m'envoyer le lobby construit en 3D, prêt à importer dans UEFN :
   - au format FBX (ou glTF/GLB), en STATIC MESH (aucun squelette, aucune animation), à l'échelle réelle (1 unité = 1 cm dans UEFN), avec l'axe vertical correct ;
   - la grange complète (murs, sol, toit, poutres, portes, pièces) et tous les objets de décor que tu as placés, déjà à leur place ;
   - découpé en plusieurs fichiers logiques (ex. Grange_Structure, Decor_Zone1, Decor_Table2...) pour que je puisse les déplacer séparément, avec des pivots propres (pivot au sol pour les objets posés, en haut pour les objets suspendus) ;
   - avec les textures PBR (couleur, normal, rugosité) intégrées, réalistes ;
   - des collisions simples sur les murs et le sol ; AUCUNE lumière dans les fichiers (je gère l'éclairage dans UEFN avec ta liste) ;
   - les emplacements du spawn, des 3 zones, des 3 tables et du retour au lobby marqués par des objets repères simples (ex. un cube nommé "REPERE_Zone1") que je supprimerai après ;
   - un aperçu en image (vue de dessus + 2 ou 3 vues à hauteur de joueur) pour que je voie le résultat avant d'importer.
   Utilise tous les outils à ta disposition (Blender en script, bibliothèques 3D, modèles gratuits CC0/CC-BY que tu assembles...). Si une partie ne peut vraiment pas être générée, dis-le clairement et donne la solution la plus proche.

Réfléchis vraiment comme un architecte d'intérieur : circulation des joueurs, points de vue, ce qu'on voit en entrant, mise en scène, lumière qui guide vers les zones. Pose-moi des questions si quelque chose manque, puis donne-moi le dossier complet.
