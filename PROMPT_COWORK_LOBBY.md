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
2. TROIS EMPLACEMENTS DE DÉPART (numérotés 1, 2, 3), assez grands pour 4 joueurs chacun. Les joueurs s'y placent pour lancer une partie ; ils sont alors emmenés ailleurs (les tables de jeu sont dans un autre lieu, loin, invisible depuis le lobby : NE LES MODÉLISE PAS). Chaque emplacement doit être très lisible pour un enfant : on comprend tout de suite "je me mets ici pour jouer" (sol marqué, cercle de lumière, panneau, grand numéro...).
3. Des zones d'attente agréables autour des emplacements (les joueurs attendent qu'un ami arrive).
3 bis. BEAUCOUP DE DÉCORATION, partout : le lobby doit être riche, vivant et plein de détails, jamais vide. Exemples : bottes de foin, outils de ferme (fourches, pelles, seaux, brouettes), vieilles caisses et tonneaux, lanternes, chaînes et cordes, toiles d'araignée, vieux meubles, sacs de grain, cadres poussiéreux, animaux empaillés ou mannequins inquiétants, plumes, planches cassées, objets mystérieux liés à la machine-mâchoire (affiches anciennes, plans, boîtes de boutons...). Chaque coin raconte une petite histoire. Toujours SANS sang ni gore.
4. Un point de retour au lobby (où les joueurs reviennent après une partie).
5. (Plus tard, à prévoir mais pas à détailler maintenant) un emplacement pour un futur shop.

CE QUE JE VEUX QUE TU ME RENDES
A. Un PLAN DE MASSE vu du dessus (schéma ou image) avec les dimensions en mètres : murs, portes, pièces, spawn, les 3 emplacements de départ, le chemin des joueurs.
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
   - découpé en plusieurs fichiers logiques (ex. Grange_Structure, Decor_Depart1, Decor_Spawn...) pour que je puisse les déplacer séparément, avec des pivots propres (pivot au sol pour les objets posés, en haut pour les objets suspendus) ;
   - avec les textures PBR (couleur, normal, rugosité) intégrées, réalistes ;
   - des collisions simples sur les murs et le sol ; AUCUNE lumière dans les fichiers (je gère l'éclairage dans UEFN avec ta liste) ;
   - les emplacements du spawn, des 3 départs et du retour au lobby marqués par des objets repères simples (ex. un cube nommé "REPERE_Depart1") que je supprimerai après ;
   - un aperçu en image (vue de dessus + 2 ou 3 vues à hauteur de joueur) pour que je voie le résultat avant d'importer.
   TU AS CARTE BLANCHE sur les moyens : utilise TOUT ce que tu veux. N'importe quel site (Sketchfab, Fab, Poly Haven, ambientCG, Quixel, TurboSquid gratuit, CGTrader gratuit...), n'importe quel outil (Blender, en script ou à la main, générateurs 3D par IA comme Meshy / Tripo / Rodin, textures scannées...), tu peux télécharger, assembler, modifier, ou créer toi-même de zéro. Seule règle sur les modèles téléchargés : une licence qui autorise l'usage dans un jeu (CC0, CC-BY ou équivalent), et tu me donnes la liste des sources et des crédits.
   SEUL CRITÈRE DE RÉUSSITE : LE RÉSULTAT FINAL DOIT ÊTRE RÉALISTE. Pas de cubes, pas de rendu "jeu mobile cheap", pas de textures plates : du vrai bois vieilli, de la vraie paille, de la poussière, des détails. Vérifie toi-même tes aperçus avant de me livrer ; si ça ne fait pas réaliste, recommence. Si une partie ne peut vraiment pas être faite, dis-le clairement et donne la solution la plus proche.

Réfléchis vraiment comme un architecte d'intérieur : circulation des joueurs, points de vue, ce qu'on voit en entrant, mise en scène, lumière qui guide vers les 3 emplacements de départ. Pose-moi des questions si quelque chose manque, puis donne-moi le dossier complet.
