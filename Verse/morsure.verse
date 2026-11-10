# ============================================================================
#  MORSURE - jeu de table de bluff, ambiance horreur.
#  Les joueurs sont assis autour de la machine. Chacun son tour, on appuie SOI-MEME sur un bouton de la
#  machine : on vise le bouton avec la camera (il devient blanc) et on clique. Certains boutons sont pieges :
#  la machoire se referme et le joueur est elimine de la manche. Le dernier en jeu gagne.
#
#  CARTES : au debut de la manche, 6 cartes au hasard, on en garde 3. A son tour, on joue une carte (elle agit
#  tout de suite) ou NO CARD. Les jeux de chacun sont secrets : les autres ne voient que le NOMBRE de cartes.
#
#  Un seul appareil Verse a poser : hands_manager
# ============================================================================
using { /Fortnite.com/Devices }
using { /Fortnite.com/Characters }
using { /Fortnite.com/UI }
using { /Verse.org/Simulation }
using { /Verse.org/Random }
using { /Verse.org/Colors }
using { /Verse.org/Assets }
using { /UnrealEngine.com/Temporary/UI }
using { /UnrealEngine.com/Temporary/SpatialMath }
using { BOUTON }          # TEST1 : la zone de clic UMG (copiee de Football Pillars), sans cadre Fortnite

TexteJeu<localizes>(S : string) : message = "{S}"

# --- Les cartes (id) ---------------------------------------------------------
#  0 DEFUSE  : si tu tombes sur un piege ce tour-ci, il ne mord pas
#  1 PEEK    : un bouton SUR devient VERT sur la machine jusqu'a la fin de ton tour
#  2 PASS    : tu passes ton tour sans appuyer
#  3 REVERSE : le sens du tour s'inverse
#  4 JAM     : le joueur suivant devra appuyer sur 2 boutons
#  Images : dossier Reliques (Relique_Bouclier, _Serrure, _Sablier, _Chaine, _Etau) + les versions _Lueur (plus claires)
NomRelique(Id : int) : string =
    if (Id = 0) then "DEFUSE" else if (Id = 1) then "PEEK" else if (Id = 2) then "PASS" else if (Id = 3) then "REVERSE" else "JAM"

# ce que fait la carte, en 2 lignes courtes (ecran du choix des cartes)
DescriptionRelique(Id : int, Ligne : int) : string =
    if (Id = 0) then (if (Ligne = 0) then "SAVES YOU FROM" else "ONE TRAP")
    else if (Id = 1) then (if (Ligne = 0) then "SHOWS YOU ONE" else "SAFE BUTTON")
    else if (Id = 2) then (if (Ligne = 0) then "NO PRESS FOR YOU" else "THIS TURN")
    else if (Id = 3) then (if (Ligne = 0) then "THE MACHINE TURNS" else "THE OTHER WAY")
    else (if (Ligne = 0) then "NEXT PLAYER" else "PRESSES +1")

# RARETE (sur 84) : DEFUSE et PASS sont rares, JAM et REVERSE courantes
PoidsRelique(Id : int)<transacts> : int =
    if (Id = 0) then 8 else if (Id = 1) then 16 else if (Id = 2) then 8 else if (Id = 3) then 22 else 30

TirerReliquePonderee()<transacts> : int =
    var Tirage : int = GetRandomInt(1, 84)
    var Choisie : int = 4
    var Trouve : logic = false
    for (Id := 0..4, not Trouve?):
        set Tirage -= PoidsRelique(Id)
        if (Tirage <= 0):
            set Choisie = Id
            set Trouve = true
    Choisie

# les 6 cartes proposees au debut de la manche : au hasard (raretes), jamais plus de 2 fois la meme
TirerOffre()<transacts> : []int =
    var Offre : []int = array{}
    var Essais : int = 0
    loop:
        if (Offre.Length >= 6 or Essais > 200):
            break
        set Essais += 1
        Id := TirerReliquePonderee()
        var Deja : int = 0
        for (X : Offre, X = Id):
            set Deja += 1
        if (Deja < 2):
            set Offre += array{Id}
    Offre

Dedans(L : []int, X : int)<transacts> : logic =
    var Trouve : logic = false
    for (Y : L, Y = X):
        set Trouve = true
    Trouve

ImageRelique(Id : int) : texture =
    if (Id = 0) then Reliques.Relique_Bouclier else if (Id = 1) then Reliques.Relique_Serrure else if (Id = 2) then Reliques.Relique_Sablier
    else if (Id = 3) then Reliques.Relique_Chaine else Reliques.Relique_Etau

ImageReliqueSurvol(Id : int) : texture =
    if (Id = 0) then Reliques.Relique_Bouclier_Lueur else if (Id = 1) then Reliques.Relique_Serrure_Lueur else if (Id = 2) then Reliques.Relique_Sablier_Lueur
    else if (Id = 3) then Reliques.Relique_Chaine_Lueur else Reliques.Relique_Etau_Lueur

ImgH(T : texture, L : float, H : float) : texture_block =
    texture_block{DefaultImage := T, DefaultDesiredSize := vector2{X := L, Y := H}}

PlaceH(W : widget, AX : float, AY : float, X : float, Y : float, L : float, H : float) : canvas_slot =
    canvas_slot{Widget := W, Anchors := anchors{Minimum := vector2{X := AX, Y := AY}, Maximum := vector2{X := AX, Y := AY}},
        Alignment := vector2{X := 0.5, Y := 0.5}, Offsets := margin{Left := X, Top := Y, Right := L, Bottom := H}, SizeToContent := false}

TexteH(S : string, AX : float, AY : float, X : float, Y : float) : canvas_slot =
    canvas_slot{Widget := text_block{DefaultText := TexteJeu(S), DefaultTextColor := color{R := 1.0, G := 1.0, B := 1.0}},
        Anchors := anchors{Minimum := vector2{X := AX, Y := AY}, Maximum := vector2{X := AX, Y := AY}},
        Alignment := vector2{X := 0.5, Y := 0.5}, Offsets := margin{Left := X, Top := Y, Right := 0.0, Bottom := 0.0}, SizeToContent := true}

# Une carte cliquable de l'ecran : son image (plus claire au survol) + la zone de clic TEST1 par-dessus.
# Clic -> Ev.Signal(Code). S'arrete quand l'ecran est reconstruit (Fin).
# --- ECRITURE pinceau sec : une image par caractere (dossier Ecriture : E_A ... et E_A_Clair pour le survol)
GlypheNormal(C : char)<transacts> : ?texture =
    if (C = 'A') then option{Ecriture.E_A}
    else if (C = 'B') then option{Ecriture.E_B}
    else if (C = 'C') then option{Ecriture.E_C}
    else if (C = 'D') then option{Ecriture.E_D}
    else if (C = 'E') then option{Ecriture.E_E}
    else if (C = 'F') then option{Ecriture.E_F}
    else if (C = 'G') then option{Ecriture.E_G}
    else if (C = 'H') then option{Ecriture.E_H}
    else if (C = 'I') then option{Ecriture.E_I}
    else if (C = 'J') then option{Ecriture.E_J}
    else if (C = 'K') then option{Ecriture.E_K}
    else if (C = 'L') then option{Ecriture.E_L}
    else if (C = 'M') then option{Ecriture.E_M}
    else if (C = 'N') then option{Ecriture.E_N}
    else if (C = 'O') then option{Ecriture.E_O}
    else if (C = 'P') then option{Ecriture.E_P}
    else if (C = 'Q') then option{Ecriture.E_Q}
    else if (C = 'R') then option{Ecriture.E_R}
    else if (C = 'S') then option{Ecriture.E_S}
    else if (C = 'T') then option{Ecriture.E_T}
    else if (C = 'U') then option{Ecriture.E_U}
    else if (C = 'V') then option{Ecriture.E_V}
    else if (C = 'W') then option{Ecriture.E_W}
    else if (C = 'X') then option{Ecriture.E_X}
    else if (C = 'Y') then option{Ecriture.E_Y}
    else if (C = 'Z') then option{Ecriture.E_Z}
    else if (C = '0') then option{Ecriture.E_0}
    else if (C = '1') then option{Ecriture.E_1}
    else if (C = '2') then option{Ecriture.E_2}
    else if (C = '3') then option{Ecriture.E_3}
    else if (C = '4') then option{Ecriture.E_4}
    else if (C = '5') then option{Ecriture.E_5}
    else if (C = '6') then option{Ecriture.E_6}
    else if (C = '7') then option{Ecriture.E_7}
    else if (C = '8') then option{Ecriture.E_8}
    else if (C = '9') then option{Ecriture.E_9}
    else if (C = '!') then option{Ecriture.E_Excl}
    else if (C = '?') then option{Ecriture.E_Inter}
    else if (C = '.') then option{Ecriture.E_Point}
    else if (C = ',') then option{Ecriture.E_Virgule}
    else if (C = ':') then option{Ecriture.E_DeuxPoints}
    else if (C = '-') then option{Ecriture.E_Tiret}
    else if (C = '+') then option{Ecriture.E_Plus}
    else if (C = '%') then option{Ecriture.E_Pourcent}
    else if (C = '/') then option{Ecriture.E_Slash}
    else if (C = '(') then option{Ecriture.E_ParenG}
    else if (C = ')') then option{Ecriture.E_ParenD}
    else if (C = 'x') then option{Ecriture.E_Fois}
    else false

GlypheClair(C : char)<transacts> : ?texture =
    if (C = 'A') then option{Ecriture.E_A_Clair}
    else if (C = 'B') then option{Ecriture.E_B_Clair}
    else if (C = 'C') then option{Ecriture.E_C_Clair}
    else if (C = 'D') then option{Ecriture.E_D_Clair}
    else if (C = 'E') then option{Ecriture.E_E_Clair}
    else if (C = 'F') then option{Ecriture.E_F_Clair}
    else if (C = 'G') then option{Ecriture.E_G_Clair}
    else if (C = 'H') then option{Ecriture.E_H_Clair}
    else if (C = 'I') then option{Ecriture.E_I_Clair}
    else if (C = 'J') then option{Ecriture.E_J_Clair}
    else if (C = 'K') then option{Ecriture.E_K_Clair}
    else if (C = 'L') then option{Ecriture.E_L_Clair}
    else if (C = 'M') then option{Ecriture.E_M_Clair}
    else if (C = 'N') then option{Ecriture.E_N_Clair}
    else if (C = 'O') then option{Ecriture.E_O_Clair}
    else if (C = 'P') then option{Ecriture.E_P_Clair}
    else if (C = 'Q') then option{Ecriture.E_Q_Clair}
    else if (C = 'R') then option{Ecriture.E_R_Clair}
    else if (C = 'S') then option{Ecriture.E_S_Clair}
    else if (C = 'T') then option{Ecriture.E_T_Clair}
    else if (C = 'U') then option{Ecriture.E_U_Clair}
    else if (C = 'V') then option{Ecriture.E_V_Clair}
    else if (C = 'W') then option{Ecriture.E_W_Clair}
    else if (C = 'X') then option{Ecriture.E_X_Clair}
    else if (C = 'Y') then option{Ecriture.E_Y_Clair}
    else if (C = 'Z') then option{Ecriture.E_Z_Clair}
    else if (C = '0') then option{Ecriture.E_0_Clair}
    else if (C = '1') then option{Ecriture.E_1_Clair}
    else if (C = '2') then option{Ecriture.E_2_Clair}
    else if (C = '3') then option{Ecriture.E_3_Clair}
    else if (C = '4') then option{Ecriture.E_4_Clair}
    else if (C = '5') then option{Ecriture.E_5_Clair}
    else if (C = '6') then option{Ecriture.E_6_Clair}
    else if (C = '7') then option{Ecriture.E_7_Clair}
    else if (C = '8') then option{Ecriture.E_8_Clair}
    else if (C = '9') then option{Ecriture.E_9_Clair}
    else if (C = '!') then option{Ecriture.E_Excl_Clair}
    else if (C = '?') then option{Ecriture.E_Inter_Clair}
    else if (C = '.') then option{Ecriture.E_Point_Clair}
    else if (C = ',') then option{Ecriture.E_Virgule_Clair}
    else if (C = ':') then option{Ecriture.E_DeuxPoints_Clair}
    else if (C = '-') then option{Ecriture.E_Tiret_Clair}
    else if (C = '+') then option{Ecriture.E_Plus_Clair}
    else if (C = '%') then option{Ecriture.E_Pourcent_Clair}
    else if (C = '/') then option{Ecriture.E_Slash_Clair}
    else if (C = '(') then option{Ecriture.E_ParenG_Clair}
    else if (C = ')') then option{Ecriture.E_ParenD_Clair}
    else if (C = 'x') then option{Ecriture.E_Fois_Clair}
    else false

# largeur de chaque caractere (fraction de sa taille) pour les poser cote a cote
LargeurGlyphe(C : char)<transacts> : float =
    if (C = 'A') then 0.512
    else if (C = 'B') then 0.527
    else if (C = 'C') then 0.469
    else if (C = 'D') then 0.418
    else if (C = 'E') then 0.570
    else if (C = 'F') then 0.715
    else if (C = 'G') then 0.668
    else if (C = 'H') then 0.523
    else if (C = 'I') then 0.516
    else if (C = 'J') then 0.609
    else if (C = 'K') then 0.570
    else if (C = 'L') then 0.457
    else if (C = 'M') then 0.730
    else if (C = 'N') then 0.523
    else if (C = 'O') then 0.520
    else if (C = 'P') then 0.492
    else if (C = 'Q') then 0.551
    else if (C = 'R') then 0.469
    else if (C = 'S') then 0.539
    else if (C = 'T') then 0.570
    else if (C = 'U') then 0.488
    else if (C = 'V') then 0.535
    else if (C = 'W') then 0.770
    else if (C = 'X') then 0.535
    else if (C = 'Y') then 0.516
    else if (C = 'Z') then 0.664
    else if (C = '0') then 0.500
    else if (C = '1') then 0.188
    else if (C = '2') then 0.484
    else if (C = '3') then 0.414
    else if (C = '4') then 0.402
    else if (C = '5') then 0.535
    else if (C = '6') then 0.391
    else if (C = '7') then 0.496
    else if (C = '8') then 0.418
    else if (C = '9') then 0.348
    else if (C = '!') then 0.203
    else if (C = '?') then 0.520
    else if (C = '.') then 0.230
    else if (C = ',') then 0.184
    else if (C = ':') then 0.254
    else if (C = '-') then 0.461
    else if (C = '+') then 0.398
    else if (C = '%') then 0.484
    else if (C = '/') then 0.457
    else if (C = '(') then 0.477
    else if (C = ')') then 0.340
    else if (C = 'x') then 0.422
    else 0.30

# largeur totale d'un texte ecrit au pinceau (Taille = hauteur d'une lettre a l'ecran)
LargeurTexte(S : string, Taille : float) : float =
    var L : float = 0.0
    for (C : S):
        set L += LargeurGlyphe(C) * Taille + Taille * 0.06
    L

# une image posee a sa taille propre (elle peut grossir au survol), centree en (X, Y)
PlaceLibre(W : widget, AX : float, AY : float, X : float, Y : float) : canvas_slot =
    canvas_slot{Widget := W, Anchors := anchors{Minimum := vector2{X := AX, Y := AY}, Maximum := vector2{X := AX, Y := AY}},
        Alignment := vector2{X := 0.5, Y := 0.5}, Offsets := margin{Left := X, Top := Y, Right := 0.0, Bottom := 0.0}, SizeToContent := true}

# comme PlaceLibre, avec un ordre d'affichage (plus grand = devant)
PlaceZ(W : widget, AX : float, AY : float, X : float, Y : float, Z : type{_X:int where 0 <= _X, _X <= 2147483647}) : canvas_slot =
    canvas_slot{Widget := W, Anchors := anchors{Minimum := vector2{X := AX, Y := AY}, Maximum := vector2{X := AX, Y := AY}},
        Alignment := vector2{X := 0.5, Y := 0.5}, Offsets := margin{Left := X, Top := Y, Right := 0.0, Bottom := 0.0}, SizeToContent := true, ZOrder := Z}

# le pseudo Fortnite d'un joueur (affiche dans un text_block)
NomJoueur<localizes>(Agent : agent) : message = "{Agent}"

# un TEXTE au pinceau (non cliquable), centre en (X, Y)
TexteEcrit(S : string, AX : float, AY : float, X : float, Y : float, Taille : float) : []canvas_slot =
    var Slots : []canvas_slot = array{}
    var Cx : float = X - LargeurTexte(S, Taille) * 0.5
    for (C : S):
        L := LargeurGlyphe(C) * Taille
        if (T := GlypheNormal(C)?):
            set Slots += array{PlaceLibre(ImgH(T, Taille, Taille), AX, AY, Cx + L * 0.5, Y)}
        set Cx += L + Taille * 0.06
    Slots

# un texte au pinceau aligne a GAUCHE (commence en X)
TexteGauche(S : string, AX : float, AY : float, X : float, Y : float, Taille : float) : []canvas_slot =
    TexteEcrit(S, AX, AY, X + LargeurTexte(S, Taille) * 0.5, Y, Taille)

# l'image d'un chiffre (0 a 9) au pinceau
GlypheChiffre(N : int)<transacts> : ?texture =
    if (N = 0) then option{Ecriture.E_0} else if (N = 1) then option{Ecriture.E_1} else if (N = 2) then option{Ecriture.E_2}
    else if (N = 3) then option{Ecriture.E_3} else if (N = 4) then option{Ecriture.E_4} else if (N = 5) then option{Ecriture.E_5}
    else if (N = 6) then option{Ecriture.E_6} else if (N = 7) then option{Ecriture.E_7} else if (N = 8) then option{Ecriture.E_8}
    else if (N = 9) then option{Ecriture.E_9} else false

# une carte face cachee (le dos) : cadre gris use + fond sombre + un "?" au pinceau
DosCarte(AX : float, AY : float, X : float, Y : float, Taille : float) : []canvas_slot =
    L := Taille * 0.72
    H := Taille * 0.96
    array{PlaceH(color_block{DefaultColor := color{R := 0.33, G := 0.33, B := 0.32}}, AX, AY, X, Y, L, H),
        PlaceH(color_block{DefaultColor := color{R := 0.07, G := 0.07, B := 0.075}}, AX, AY, X, Y, L - Taille * 0.06, H - Taille * 0.06)} + TexteEcrit("?", AX, AY, X, Y, Taille * 0.45)

# LE JUMPSCARE (quand on se fait mordre) : 81 images du dossier Cauchemar, jouees en plein ecran
ImagesCauchemar : []texture = array{
    Cauchemar.Cauchemar_001,
    Cauchemar.Cauchemar_002,
    Cauchemar.Cauchemar_003,
    Cauchemar.Cauchemar_004,
    Cauchemar.Cauchemar_005,
    Cauchemar.Cauchemar_006,
    Cauchemar.Cauchemar_007,
    Cauchemar.Cauchemar_008,
    Cauchemar.Cauchemar_009,
    Cauchemar.Cauchemar_010,
    Cauchemar.Cauchemar_011,
    Cauchemar.Cauchemar_012,
    Cauchemar.Cauchemar_013,
    Cauchemar.Cauchemar_014,
    Cauchemar.Cauchemar_015,
    Cauchemar.Cauchemar_016,
    Cauchemar.Cauchemar_017,
    Cauchemar.Cauchemar_018,
    Cauchemar.Cauchemar_019,
    Cauchemar.Cauchemar_020,
    Cauchemar.Cauchemar_021,
    Cauchemar.Cauchemar_022,
    Cauchemar.Cauchemar_023,
    Cauchemar.Cauchemar_024,
    Cauchemar.Cauchemar_025,
    Cauchemar.Cauchemar_026,
    Cauchemar.Cauchemar_027,
    Cauchemar.Cauchemar_028,
    Cauchemar.Cauchemar_029,
    Cauchemar.Cauchemar_030,
    Cauchemar.Cauchemar_031,
    Cauchemar.Cauchemar_032,
    Cauchemar.Cauchemar_033,
    Cauchemar.Cauchemar_034,
    Cauchemar.Cauchemar_035,
    Cauchemar.Cauchemar_036,
    Cauchemar.Cauchemar_037,
    Cauchemar.Cauchemar_038,
    Cauchemar.Cauchemar_039,
    Cauchemar.Cauchemar_040,
    Cauchemar.Cauchemar_041,
    Cauchemar.Cauchemar_042,
    Cauchemar.Cauchemar_043,
    Cauchemar.Cauchemar_044,
    Cauchemar.Cauchemar_045,
    Cauchemar.Cauchemar_046,
    Cauchemar.Cauchemar_047,
    Cauchemar.Cauchemar_048,
    Cauchemar.Cauchemar_049,
    Cauchemar.Cauchemar_050,
    Cauchemar.Cauchemar_051,
    Cauchemar.Cauchemar_052,
    Cauchemar.Cauchemar_053,
    Cauchemar.Cauchemar_054,
    Cauchemar.Cauchemar_055,
    Cauchemar.Cauchemar_056,
    Cauchemar.Cauchemar_057,
    Cauchemar.Cauchemar_058,
    Cauchemar.Cauchemar_059,
    Cauchemar.Cauchemar_060,
    Cauchemar.Cauchemar_061,
    Cauchemar.Cauchemar_062,
    Cauchemar.Cauchemar_063,
    Cauchemar.Cauchemar_064,
    Cauchemar.Cauchemar_065,
    Cauchemar.Cauchemar_066,
    Cauchemar.Cauchemar_067,
    Cauchemar.Cauchemar_068,
    Cauchemar.Cauchemar_069,
    Cauchemar.Cauchemar_070,
    Cauchemar.Cauchemar_071,
    Cauchemar.Cauchemar_072,
    Cauchemar.Cauchemar_073,
    Cauchemar.Cauchemar_074,
    Cauchemar.Cauchemar_075,
    Cauchemar.Cauchemar_076,
    Cauchemar.Cauchemar_077,
    Cauchemar.Cauchemar_078,
    Cauchemar.Cauchemar_079,
    Cauchemar.Cauchemar_080,
    Cauchemar.Cauchemar_081}

# Pour qu'il n'y ait JAMAIS d'image blanche (image pas encore chargee) : les images A VENIR sont posees en plein
# ecran SOUS l'image affichee (invisibles, mais le jeu les charge en vraie taille avant qu'on en ait besoin).
# Fenetre glissante : seules les prochaines images sont posees, les images passees sont retirees.
fenetre_images := class:
    Scene : canvas
    Couches : []texture_block
    Plein : anchors
    var Bas : int = 0
    var Haut : int = -1

    Avancer(Debut : int, Avance : int) : void =
        Fin := Min(Couches.Length - 1, Debut + Avance)
        for (K := Haut + 1..Fin, W := Couches[K]):
            Scene.AddWidget(canvas_slot{Widget := W, Anchors := Plein, Offsets := margin{}, ZOrder := 0})
        set Haut = Max(Haut, Fin)
        for (K := Bas..Debut - 1, W := Couches[K]):
            Scene.RemoveWidget(W)
        set Bas = Max(Bas, Debut)

# un TEXTE-BOUTON : au survol, il devient blanc pur et grossit un peu ; clic -> Ev.Signal(Code)
bouton_texte := class:
    Ev : event(int)
    Fin : event()
    Code : int
    Lettres : []texture_block
    Normales : []texture
    Claires : []texture
    Taille : float
    Zone : TEST1
    Fond : texture_block
    FondNormal : texture
    FondSurvol : texture
    LargFond : float
    HautFond : float

    Son : audio_player_device

    Suivre()<suspends> : void =
        race:
            Fin.Await()
            loop:
                Zone.Clic.Await()
                Son.Play()
                Ev.Signal(Code)
            loop:
                Zone.Entre.Await()
                # survol : le bouton s'eclaircit et grossit un peu, le texte devient plus blanc et plus gros
                Fond.SetImage(FondSurvol)
                Fond.SetDesiredSize(vector2{X := LargFond * 1.06, Y := HautFond * 1.06})
                for (I -> Img : Lettres, T := Claires[I]):
                    Img.SetImage(T)
                    Img.SetDesiredSize(vector2{X := Taille * 1.12, Y := Taille * 1.12})
                Zone.Sort.Await()
                Fond.SetImage(FondNormal)
                Fond.SetDesiredSize(vector2{X := LargFond, Y := HautFond})
                for (I -> Img : Lettres, T := Normales[I]):
                    Img.SetImage(T)
                    Img.SetDesiredSize(vector2{X := Taille, Y := Taille})

# une CARTE de sa main, cliquable : au survol elle s'eclaircit et grossit (on la "prend")
carte_main := class:
    Ev : event(int)
    Fin : event()
    Code : int
    Image : texture_block
    Normale : texture
    Lueur : texture
    Taille : float
    Zone : TEST1
    var Gardee : logic = false                 # carte prise (choix du debut) : elle reste grande et claire

    Son : audio_player_device

    Suivre()<suspends> : void =
        race:
            Fin.Await()
            loop:
                Zone.Clic.Await()
                Son.Play()
                Ev.Signal(Code)
            loop:
                Zone.Entre.Await()
                Grande(true)
                Zone.Sort.Await()
                if (not Gardee?):
                    Grande(false)

    Grande(Oui : logic) : void =
        if (Oui?):
            Image.SetImage(Lueur)
            Image.SetDesiredSize(vector2{X := Taille * 1.15, Y := Taille * 1.15})
        else:
            Image.SetImage(Normale)
            Image.SetDesiredSize(vector2{X := Taille, Y := Taille})

    Garder(Oui : logic) : void =
        set Gardee = Oui
        Grande(Oui)

# Avec la CAMERA FIXE : une zone de clic invisible posee a l'ecran PILE sur un bouton de la machine.
# Souris dessus -> le vrai bouton devient blanc ; clic -> il est enfonce.
zone_bouton := class:
    Manager : hands_manager
    K : int
    Zone : TEST1

    Suivre()<suspends> : void =
        race:
            Manager.FinEcran.Await()
            loop:
                Zone.Clic.Await()
                Manager.Choix.Signal(K)
            loop:
                Zone.Entre.Await()
                Manager.Surligner(K)
                Zone.Sort.Await()
                Manager.Surligner(-1)

# LE CHOIX DES CARTES au debut de la manche (chaque joueur a le sien, en meme temps que les autres)
choix_depart := class:
    Manager : hands_manager
    J : player
    Cartes : []carte_main
    Compteur : texture_block
    Ev : event(int)
    Offre : []int                              # la carte de chaque place (6 places)
    var Pris : []int = array{}                 # les PLACES prises
    var Confirme : logic = false

    Suivre(Fin : event())<suspends> : void =
        race:
            Fin.Await()
            loop:
                Code := Ev.Await()
                if (not Confirme?):
                    if (Code = 599):
                        if (Pris.Length = 3):
                            set Confirme = true
                        else:
                            Manager.Avertir(J, "CHOOSE 3 CARDS")
                    else:
                        Basculer(Code - 500)

    # clic sur une carte : prise (cadre clair) ou rendue
    Basculer(Id : int) : void =
        if (Dedans(Pris, Id)?):
            set Pris = for (P : Pris, P <> Id) do P
            if (Carte := Cartes[Id]):
                Carte.Garder(false)
        else if (Pris.Length < 3):
            set Pris += array{Id}
            if (Carte := Cartes[Id]):
                Carte.Garder(true)
        if (G := GlypheChiffre(Pris.Length)?):
            Compteur.SetImage(G)

    # ses 3 cartes (les cartes des places prises)
    Main()<transacts> : []int =
        for (P : Pris, Id := Offre[P]) do Id

    # temps ecoule : on complete au hasard
    Completer() : void =
        var Essais : int = 0
        loop:
            if (Pris.Length >= 3 or Essais > 100):
                break
            Place := GetRandomInt(0, Offre.Length - 1)
            if (not Dedans(Pris, Place)?):
                set Pris += array{Place}
            set Essais += 1

hands_manager := class(creative_device):
    # --- A REMPLIR DANS UEFN ---------------------------------------------------
    # Une place par joueur autour de la table (accessoires invisibles, sans collision, pivot au sol)
    @editable Places : []creative_prop = array{}
    # Une camera fixe par place, posee devant la bouche de la machine et qui regarde le clavier (l'ordre ne compte
    # pas : chaque joueur a la camera la plus proche de sa place). On clique sur les boutons A LA SOURIS.
    @editable CamerasClavier : []gameplay_camera_fixed_point_device = array{}
    # Ou est le clavier A L'ECRAN (vu par la camera), en fractions de l'ecran (0 = gauche / haut, 1 = droite / bas).
    # 7 valeurs = les 7 lignes qui separent les 6 rangees de boutons, de haut en bas : hauteur de la ligne, bord
    # gauche et bord droit du clavier a cette hauteur (mesurees sur ta capture d'ecran de la camera)
    @editable LignesY : []float = array{0.274, 0.329, 0.399, 0.486, 0.600, 0.751, 0.946}
    @editable BordGauche : []float = array{0.409, 0.398, 0.383, 0.364, 0.340, 0.310, 0.298}
    @editable BordDroit : []float = array{0.593, 0.600, 0.603, 0.613, 0.625, 0.645, 0.668}
    # si le bouton qui devient blanc n'est pas celui sous la souris, coche / decoche ces cases
    @editable InverserColonnes : logic = false
    @editable InverserLignes : logic = false
    # La machine : le socle (Centre), la machoire du haut (Gueule), la machoire du bas (Plaque) et les 24 boutons DANS L'ORDRE Bouton_01..Bouton_24
    @editable Centre : creative_prop = creative_prop{}
    @editable Gueule : creative_prop = creative_prop{}
    @editable Touches : []creative_prop = array{}
    @editable Plaque : creative_prop = creative_prop{}
    # COULEURS DES BOUTONS : 2 materiaux dans un dossier Teintes du Tiroir a contenu :
    #   T_Clair (le bouton vise, blanc), T_Sur (le bouton sur du PEEK, vert) ; sinon le bouton reprend M_Touches
    # Numero de l'emplacement de materiau du bouton (0 en general)
    @editable IndexMateriau : int = 0
    # LE LOBBY : un Compteur de joueurs (Player Counter, "Utiliser la zone" coche) = l'enclos de CETTE table. Les joueurs entrent dans la zone ; des
    # qu'ils sont au moins 2 (4 maximum), un compte a rebours de 10 s demarre ; sortir de la zone retire le joueur.
    # A 0, les joueurs de la zone vont a la table. 3 tables = 3 appareils hands_manager, chacun avec SA zone.
    @editable ZoneLobby : player_counter_device = player_counter_device{}
    # Ou les joueurs sont renvoyes a la fin de la partie (un accessoire invisible SANS collision, pres des zones).
    # VIDE = chacun revient la ou il est apparu.
    @editable RetourLobby : []creative_prop = array{}
    # Secondes a passer dans la zone avant le depart
    @editable AttenteLobby : float = 10.0
    # Distance max (cm) entre le regard et le centre d'un bouton pour qu'il soit vise
    # Son de rotation (Audio Player en BOUCLE, lecture automatique NON) : il joue tant que la machine tourne
    @editable SonRotation : audio_player_device = audio_player_device{}
    # Son "CLAC" quand la machine s'arrete sur un joueur (Audio Player : lecture automatique NON)
    @editable SonArret : audio_player_device = audio_player_device{}
    # Direction (degres, vue du dessus dans UEFN) vers laquelle la gueule regarde au depart. Ajuste si elle
    # ne fait pas face au bon joueur (ex. 90, 180, -90).
    @editable FaceDepart : float = -90.0
    @editable DureeRotation : float = 1.75       # secondes pour pivoter vers le joueur suivant
    # LA ROULETTE du debut de manche : nombre de tours complets, et sa duree totale (secondes). Plus long = plus lent.
    @editable ToursRoulette : int = 3
    @editable DureeRoulette : float = 12.0
    # Sons (Audio Player : lecture automatique NON)
    @editable SonClic : audio_player_device = audio_player_device{}
    @editable SonBoom : audio_player_device = audio_player_device{}
    # LE JUMPSCARE : le son, entendu SEULEMENT par celui qui se fait mordre (Audio Player : lecture automatique NON)
    @editable SonCauchemar : audio_player_device = audio_player_device{}
    @editable ImagesParSecondeCauchemar : float = 24.0
    # LA FEINTE : a chaque bouton sur, la machoire claque un peu (degres) puis se rouvre
    @editable AngleFeinte : float = 14.0
    @editable SonCarte : audio_player_device = audio_player_device{}
    # Son des BOUTONS et des CARTES qu'on clique (confirmer, jouer une carte, choisir ses cartes...).
    # Lecteur audio : lecture automatique NON, en boucle NON, spatialisation NON.
    @editable SonBouton : audio_player_device = audio_player_device{}
    # A SA PLACE : le joueur est pose PILE sur sa Place (debout), tourne vers la machine, fige, a la PREMIERE
    # PERSONNE (si Fortnite refuse la teleportation, il est pose un peu plus haut ou un peu devant).
    # Pour le caler : AvanceAssis = cm vers la table (negatif = en arriere), HauteurAssis = cm vers le haut.
    @editable AvanceAssis : float = 0.0
    @editable HauteurAssis : float = 0.0
    # correction (degres) de la direction de la vue a sa place : +90 = un quart de tour a droite, -90 a gauche
    @editable CorrectionVue : float = 0.0
    # Reglages
    @editable JoueursMinimum : int = 2
    # TEST : true = on peut jouer TOUT SEUL (la manche dure jusqu'a ce que tu tombes sur un piege ;
    # entre deux tours, la machine fait un tour complet et revient sur toi). Decoche avant de publier.
    @editable TestSolo : logic = false
    # Coche si, dans l'editeur, tu as ATTACHE la machoire, la plaque et les 24 boutons au socle (Centre) :
    # seul le socle est alors tourne par le code, tout le reste suit d'un seul bloc (plus aucun decalage)
    @editable PiecesAttachees : logic = false
    # BACK TO LOBBY : un appareil Bouton (Button) dans la piece (Temps d'interaction : 2 s). Un joueur mordu
    # (plus dans le jeu) qui l'utilise rentre au lobby tout de suite. Les joueurs encore en jeu ne peuvent pas.
    @editable BoutonRetourLobby : button_device = button_device{}
    # VICTOIRE : une camera fixe (UNE par table, posee n'importe ou ; "Ajouter aux joueurs au debut" : NON).
    # Quand quelqu'un gagne, le code la place devant le gagnant, tournee vers lui, puis la recule doucement
    # (leger dezoom). Toute la table la voit.
    @editable CameraVictoire : gameplay_camera_fixed_point_device = gameplay_camera_fixed_point_device{}
    @editable DistanceDebutVictoire : float = 55.0     # cm devant le gagnant au debut (gros plan sur la tete)
    @editable DistanceFinVictoire : float = 170.0      # cm devant le gagnant a la fin (dezoom)
    @editable HauteurVictoire : float = 70.0           # hauteur de la camera par rapport au CENTRE du personnage (sa tete = environ 70)
    @editable InclinaisonVictoire : float = -4.0       # degres : negatif = la camera regarde un peu vers le bas
    @editable DureeVictoire : float = 4.0              # secondes du dezoom
    # TEST : coche pour gagner tout de suite (5 s apres l'arrivee : pose a ta place, puis la scene de victoire)
    @editable TestVictoire : logic = false
    # TEST : coche pour etre envoye dans la porcherie comme un joueur MORDU (5 s apres l'arrivee) : tu peux
    # marcher et essayer le bouton BACK TO LOBBY
    @editable TestRetourLobby : logic = false
    # Les panneaux (BACK TO LOBBY...) qui FLOTTENT doucement de haut en bas, comme dans Football Pillars
    @editable PanneauxFlottants : []creative_prop = array{}
    @editable Flottement : float = 15.0           # cm de haut en bas
    @editable VitesseFlottement : float = 0.4     # allers-retours par seconde
    # Ou va un joueur mordu : des accessoires INVISIBLES et SANS collision, au sol, dans un coin de la piece
    # (3 pour une table de 4). Vide = il reste a sa place. Ensuite il peut se deplacer librement.
    @editable PointsElimines : []creative_prop = array{}
    @editable PiegesParGrille : int = 2
    @editable DureeTour : float = 25.0           # temps pour appuyer (le choix de la carte et l'annonce en plus)
    @editable DureeChoixDepart : float = 30.0    # debut de manche : temps pour choisir ses 3 cartes
    @editable DureeChoixCarte : float = 25.0     # temps pour choisir la carte a jouer et ce qu'on annonce
    @editable AngleFermeture : float = 60.0      # degres pour fermer COMPLETEMENT la machoire
    @editable AxeFermeture : int = 0             # 0 = X, 1 = Y, 2 = Z (change si elle tourne dans le mauvais sens)
    @editable Enfoncement : float = 3.0          # cm : un bouton appuye descend de ca
    Colonnes : int = 4
    PaquetMax : int = 3

    # codes des clics sur les cartes de l'ecran : 100 + Id = annoncer la carte Id, 199 = pas de carte
    Choix : event(int) = event(int){}
    # un clic (action Tir) d'un joueur
    FinEcran : event() = event(){}
    var EnMachine : [player]logic = map{}          # il clique sur la machine (camera fixe) : ses textes sont a gauche
    var Orientations : [player]float = map{}       # direction (degres) de la machine vue de sa place : la tete est limitee autour
    var BaseTouches : []transform = array{}
    var BaseGueule : transform = transform{}
    var BaseCentre : transform = transform{}
    var BasePlaque : transform = transform{}
    var BoutonBlanc : int = -1                   # bouton vise en ce moment (blanc)
    var BoutonVert : int = -1                    # bouton sur montre par PEEK (vert)
    var LacetMachine : float = 0.0               # rotation actuelle de toute la machine (degres)
    var Enfoncee : []logic = array{}
    var Piegee : []logic = array{}
    var Assis : []player = array{}
    var Vivants : []player = array{}
    var Paquets : [player][]int = map{}
    var Sens : int = 1
    var Bloque : int = 0
    var Ecrans : [player]canvas = map{}
    var Chronos : [player][]texture_block = map{}   # les 2 chiffres du chrono (ecriture pinceau)
    var Bandeaux : [player]canvas = map{}           # le message du haut (ecriture pinceau)
    var DernierTourne : int = -1                 # place vers laquelle la machine est tournee
    var ApresRoulette : logic = false            # la roulette vient de choisir le joueur : son 1er tour ne refait pas un tour
    # BLUFF : l'annonce en cours (les autres peuvent crier LIAR!)
    var DefiEnCours : logic = false
    var DefiRelique : int = 0
    var DefiAuteur : int = 0                     # numero (P1, P2...) de celui qui annonce
    var Penalites : [player]int = map{}          # boutons en plus au prochain tour (mauvaise accusation)

    OnBegin<override>()<suspends> : void =
        set BaseTouches = for (T : Touches) do T.GetTransform()
        set BaseGueule = Gueule.GetTransform()
        set BaseCentre = Centre.GetTransform()
        set BasePlaque = Plaque.GetTransform()
        set Enfoncee = for (T : Touches) do false
        set Piegee = for (T : Touches) do false
        EnleverCameras()
        # SECURITE (reglages des appareils) : rien ne doit gener, meme si une case est mal reglee dans l'editeur
        #  - aucun son du jeu ne joue tout seul au lancement (si "lecture automatique" est cochee par erreur)
        for (Son : array{SonRotation, SonArret, SonClic, SonBoom, SonCauchemar, SonCarte, SonBouton}):
            Son.Stop()
        #  - les reperes (places, points des mordus, points de retour) sont invisibles et sans collision
        for (Pl : Places):
            Pl.Hide()
        for (Pl : PointsElimines):
            Pl.Hide()
        for (Pl : RetourLobby):
            Pl.Hide()
        spawn{ MemoriserSpawns() }
        if (TestVictoire?):
            spawn{ TesterVictoire() }
        if (TestRetourLobby?):
            spawn{ TesterRetourLobby() }
        for (Pan : PanneauxFlottants):
            spawn{ FaireFlotter(Pan) }
        BoutonRetourLobby.InteractedWithEvent.Subscribe(QuandRetourLobby)
        ZoneLobby.CountedEvent.Subscribe(EntreZone)
        ZoneLobby.RemovedEvent.Subscribe(SortZone)
        loop:
            Table0 := Lobby()
            # la partie commence : les joueurs partis jouer restent COMPTES dans le compteur de l'enclos (il affiche
            # 4/4, 3/4... tant que la partie dure) ; on ne peut pas y lancer une autre partie
            for (X : Table0):
                ZoneLobby.Register(X)
            race:
                Manche(Table0)
                ZonePendantPartie()
                GarderEnPlace()
            ZoneLobby.UnregisterAll()
            Sleep(1.0)

    # =========================================================================
    #  LE LOBBY : 3 zones (une par table), 2 a 4 joueurs, depart apres 10 s ; on bouge librement
    # =========================================================================
    # les joueurs dans la zone du lobby (dans l'ordre d'arrivee) et ceux de la partie en cours a CETTE table
    var DansZone : []player = array{}
    var Table : []player = array{}

    EntreZone(Agent : agent) : void =
        # (les joueurs de la partie en cours, inscrits dans le compteur, ne comptent pas pour une nouvelle partie)
        if (J := player[Agent], not Contient(DansZone, J)?, not Contient(Table, J)?):
            set DansZone += array{J}

    SortZone(Agent : agent) : void =
        if (J := player[Agent]):
            set DansZone = for (X : DansZone, X <> J) do X
            AfficherLobby(J, "")

    # attend que 2 a 4 joueurs restent AttenteLobby secondes dans la zone ; rend la liste des joueurs qui partent
    Lobby()<suspends> : []player =
        set Table = array{}
        Max4 := Min(4, Max(1, Places.Length))
        Requis := if (TestSolo?) then 1 else Min(Max4, Max(2, JoueursMinimum))
        var Reste : float = AttenteLobby
        var Partants : []player = array{}
        loop:
            set DansZone = for (J : DansZone, EstLa(J)?, J.GetFortCharacter[]) do J
            for (J -> T : Affiches, not Contient(DansZone, J)?):
                if (set Affiches[J] = "") {}
            Groupe := for (K -> J : DansZone, K < Max4) do J
            if (Groupe.Length >= Requis):
                if (Reste <= 0.0):
                    set Partants = Groupe
                    break
                Secondes := if (C := Ceil[Reste]) then C else 0
                for (J : Groupe):
                    AfficherLobby(J, "{Groupe.Length}/{Max4} PLAYERS  -  START IN {Secondes}")
                for (K -> J : DansZone, K >= Max4):
                    AfficherLobby(J, "FULL ({Max4}/{Max4})  -  TRY ANOTHER ZONE")
                set Reste -= 0.25
            else:
                set Reste = AttenteLobby
                for (J : DansZone):
                    AfficherLobby(J, "{DansZone.Length}/{Max4} PLAYERS  -  WAITING FOR A FRIEND")
            Sleep(0.25)
        for (J : DansZone):
            AfficherLobby(J, "")
        set DansZone = for (J : DansZone, not Contient(Partants, J)?) do J
        set Table = Partants
        Partants

    # pendant la partie de CETTE table, ceux qui entrent dans sa zone sont prevenus
    ZonePendantPartie()<suspends> : void =
        loop:
            set DansZone = for (J : DansZone, EstLa(J)?, J.GetFortCharacter[]) do J
            for (J : DansZone):
                AfficherLobby(J, "GAME IN PROGRESS  -  TRY ANOTHER ZONE")
            Sleep(0.5)

    # le texte du lobby n'est redessine que s'il change (pas de clignotement)
    var Affiches : [player]string = map{}
    AfficherLobby(J : player, S : string) : void =
        Avant := if (A := Affiches[J]) then A else ""
        if (Avant <> S):
            if (set Affiches[J] = S) {}
            MessagePour(J, S)

    # l'endroit ou chaque joueur est apparu (retenu la premiere fois qu'on le voit)
    var PointSpawn : [player]vector3 = map{}
    MemoriserSpawns()<suspends> : void =
        loop:
            for (J : GetPlayspace().GetPlayers(), not PointSpawn[J], Perso := J.GetFortCharacter[]):
                if (set PointSpawn[J] = Perso.GetTransform().Translation) {}
                # securite : a son arrivee, AUCUNE camera fixe du jeu (clavier, victoire) ne doit etre sur lui,
                # meme si "Ajouter aux joueurs au debut" est reste coche sur une camera
                CameraVictoire.RemoveFrom(J)
                for (Cam : CamerasClavier):
                    Cam.RemoveFrom(J)
            Sleep(0.5)

    # un panneau monte et descend doucement, en boucle (8 petits pas par aller-retour)
    FaireFlotter(Pan : creative_prop)<suspends> : void =
        Depart := Pan.GetTransform()
        Pas := 8
        Duree := 1.0 / Max(0.05, VitesseFlottement) / (Pas * 1.0)
        loop:
            for (K := 1..Pas):
                Onde := Sin((K * 1.0) / (Pas * 1.0) * 2.0 * PiFloat)
                Hauteur := (Onde + 1.0) * 0.5 * Flottement
                # le Sleep garantit l'attente (un panneau cache rend MoveTo instantane : sans lui, boucle infinie)
                spawn{ BougerPanneau(Pan, Depart.Translation + vector3{X := 0.0, Y := 0.0, Z := Hauteur}, Depart.Rotation, Duree) }
                Sleep(Duree)

    BougerPanneau(Pan : creative_prop, Ou : vector3, Rot : rotation, Duree : float)<suspends> : void =
        Pan.MoveTo(Ou, Rot, Duree)

    # LA VICTOIRE : la camera se place devant le gagnant (tournee vers lui) et recule doucement ; toute la table
    # la voit, puis elle est retiree. Sans personnage (deconnecte) : simple attente.
    CinematiqueVictoire(G : player)<suspends> : void =
        if (Perso := G.GetFortCharacter[]):
            EnleverCameras()
            P := Perso.GetTransform().Translation
            # il est tourne FACE A LA CAMERA (vers la machine, la ou la camera va se placer) et fige pendant la scene :
            # il ne peut plus tourner la tete, il regarde la camera
            C := CentreTable()
            LacetG := ArcTan(C.Y - P.Y, C.X - P.X)
            F := vector3{X := Cos(LacetG), Y := Sin(LacetG), Z := 0.0}
            Perso.ReleaseFromStasis()
            # toujours VISIBLE pendant sa scene (securite)
            Perso.Show()
            if (Perso.TeleportTo[P, MakeRotationFromYawPitchRollDegrees(LacetG * 180.0 / PiFloat, 0.0, 0.0)]) {}
            Perso.PutInStasis(stasis_args{AllowTurning := false, AllowFalling := false, AllowEmotes := false})
            Haut := vector3{X := 0.0, Y := 0.0, Z := HauteurVictoire}
            # la camera regarde le gagnant : direction opposee a la sienne
            Lacet := ArcTan(-F.Y, -F.X) * 180.0 / PiFloat
            Rot := MakeRotationFromYawPitchRollDegrees(Lacet, InclinaisonVictoire, 0.0)
            if (CameraVictoire.TeleportTo[P + F * DistanceDebutVictoire + Haut, Rot]) {}
            # SEULEMENT les joueurs de CETTE table encore dans la porcherie (pas les autres tables, pas ceux deja rentres)
            for (X : Table, EstLa(X)?, not Contient(DejaRentres, X)?):
                CameraVictoire.AddTo(X)
            # L'ECRAN DU GAGNANT : la couronne, WINNER, et son pseudo (pour toute la table)
            var EcransV : [player]canvas = map{}
            for (X : Table, EstLa(X)?, not Contient(DejaRentres, X)?, IU := GetPlayerUI[X]):
                CV := EcranGagnant(G)
                IU.AddWidget(CV)
                if (set EcransV[X] = CV) {}
            Sleep(0.2)
            Debut := GetSimulationElapsedTime()
            CameraVictoire.MoveTo(P + F * DistanceFinVictoire + Haut, Rot, Max(0.5, DureeVictoire))
            # securite : la scene dure toujours au moins DureeVictoire, meme si le deplacement finit trop tot
            Sleep(Max(0.0, DureeVictoire - (GetSimulationElapsedTime() - Debut)) + 0.6)
            for (X -> CV : EcransV, IU := GetPlayerUI[X]):
                IU.RemoveWidget(CV)
            for (X : Table, EstLa(X)?):
                CameraVictoire.RemoveFrom(X)
        else:
            Sleep(4.0)

    # en haut de l'ecran : la couronne, WINNER au pinceau, et le pseudo du gagnant sur un bandeau sombre
    EcranGagnant(G : player) : canvas =
        var S : []canvas_slot = array{
            PlaceZ(ImgH(Panneaux.Couronne, 170.0, 170.0), 0.5, 0.0, 0.0, 115.0, 0),
            canvas_slot{Widget := color_block{DefaultColor := color{R := 0.02, G := 0.02, B := 0.02}, DefaultOpacity := 0.65},
                Anchors := anchors{Minimum := vector2{X := 0.5, Y := 0.0}, Maximum := vector2{X := 0.5, Y := 0.0}},
                Alignment := vector2{X := 0.5, Y := 0.5}, Offsets := margin{Left := 0.0, Top := 345.0, Right := 620.0, Bottom := 70.0}, ZOrder := 0},
            canvas_slot{Widget := text_block{DefaultText := NomJoueur(G), DefaultTextColor := color{R := 1.0, G := 0.86, B := 0.35}, DefaultJustification := text_justification.Center},
                Anchors := anchors{Minimum := vector2{X := 0.5, Y := 0.0}, Maximum := vector2{X := 0.5, Y := 0.0}},
                Alignment := vector2{X := 0.5, Y := 0.5}, Offsets := margin{Left := 0.0, Top := 345.0, Right := 600.0, Bottom := 60.0}, ZOrder := 1}}
        set S += TexteEcrit("WINNER", 0.5, 0.0, 0.0, 265.0, 110.0)
        canvas{Slots := S}

    # TEST : 5 s apres le debut, le premier joueur est mis a la table comme s'il venait d'etre mordu
    TesterRetourLobby()<suspends> : void =
        Sleep(5.0)
        if (J := GetPlayspace().GetPlayers()[0], J.GetFortCharacter[]):
            set Table = array{J}
            set Assis = array{J}
            set Vivants = array{}
            set DejaRentres = array{}
            set PlaceDe = map{J => 0}
            Asseoir(J, 0, ?Annonce := false)
            Sleep(1.0)
            DevenirSpectateur(J, 0)

    # TEST : 5 s apres le debut, le premier joueur est pose a la place 1 et gagne (scene de victoire), puis lobby
    TesterVictoire()<suspends> : void =
        Sleep(5.0)
        if (J := GetPlayspace().GetPlayers()[0], J.GetFortCharacter[]):
            set Table = array{J}
            set Assis = array{J}
            set Vivants = array{J}
            set PlaceDe = map{J => 0}
            Asseoir(J, 0, ?Annonce := false)
            Sleep(1.0)
            CinematiqueVictoire(J)
            Bandeau("")
            RenvoyerAuLobby(array{J})
            set Table = array{}
            set Assis = array{}
            set Vivants = array{}

    # les joueurs mordus deja rentres au lobby par le bouton (on ne les y renvoie pas une 2e fois)
    var DejaRentres : []player = array{}
    QuandRetourLobby(Agent : agent) : void =
        if (J := player[Agent], Contient(Assis, J)?, not Contient(Vivants, J)?, not Contient(DejaRentres, J)?):
            RenvoyerAuLobby(array{J})
            set DejaRentres += array{J}
            # il ne fait plus partie de CETTE table : plus aucun message, ecran ni camera d'ici (il peut rejouer ailleurs)
            set Table = for (X : Table, X <> J) do X
            MessagePour(J, "")

    # fin de partie : les joueurs de la table sont renvoyes au lobby (sur RetourLobby, ou a leur point
    # d'apparition si RetourLobby est vide)
    RenvoyerAuLobby(Liste : []player) : void =
        for (K -> J : Liste, not Contient(DejaRentres, J)?, Perso := J.GetFortCharacter[]):
            Perso.ReleaseFromStasis()
            Perso.Show()
            if (RetourLobby.Length = 0, P := PointSpawn[J]):
                var PoseS : logic = false
                for (H : array{0.0, 40.0, 80.0, 130.0}, not PoseS?):
                    if (Perso.TeleportTo[P + vector3{X := 0.0, Y := 0.0, Z := H}, Perso.GetTransform().Rotation]):
                        set PoseS = true
            else if (Ix := Mod[K, Max(1, RetourLobby.Length)], Pl := RetourLobby[Ix]):
                T := Pl.GetTransform()
                var Pose : logic = false
                for (H : array{0.0, 40.0, 80.0, 130.0}, not Pose?):
                    if (Perso.TeleportTo[T.Translation + vector3{X := 0.0, Y := 0.0, Z := H}, T.Rotation]):
                        set Pose = true

    # LA camera fixe d'un joueur : celle qui est posee le plus pres de SA place (l'ordre de la liste ne compte pas)
    CameraDe(J : player)<transacts> : ?gameplay_camera_fixed_point_device =
        var Meilleure : ?gameplay_camera_fixed_point_device = false
        if (Pl := Places[PlaceIndex(J)]):
            Ici := Pl.GetTransform().Translation
            var PlusPres : float = 2000.0 * 2000.0   # une camera a plus de 20 m de la place est ignoree (camera d'une autre table)
            for (Cam : CamerasClavier):
                V := Cam.GetTransform().Translation - Ici
                D := DotProduct(V, V)
                if (D < PlusPres):
                    set PlusPres = D
                    set Meilleure = option{Cam}
        Meilleure

    # aucune camera fixe sur personne (au demarrage et a chaque manche) : on ne la voit que pendant son tour
    EnleverCameras() : void =
        for (Cam : CamerasClavier, J : Table):
            Cam.RemoveFrom(J)

    # a l'arrivee a sa place : sa vue est tournee FACE A LA MACHINE (refait 2 fois, Fortnite l'applique parfois en retard)
    RetourPlace(J : player)<suspends> : void =
        # (plus d'ecran noir : le retour a sa place se fait directement)
        if (Perso := J.GetFortCharacter[], Perso.IsActive[]):
            Perso.ReleaseFromStasis()
            Asseoir(J, PlaceIndex(J), ?Annonce := false)
        # securite : AUCUNE camera fixe ne reste sur lui, et il est refige avec la TETE LIBRE (meme si la
        # teleportation de retour a ete refusee)
        for (Cam : CamerasClavier):
            Cam.RemoveFrom(J)
        if (Perso := J.GetFortCharacter[], Perso.IsActive[]):
            Perso.ReleaseFromStasis()
            Perso.PutInStasis(stasis_args{AllowTurning := true, AllowFalling := true, AllowEmotes := false})
        if (Vue := Orientations[J]):
            spawn{ FaceMachineApres(J, Vue, array{0.05, 0.1, 0.15, 0.25}) }
        Sleep(0.3)

    # FILET DE SECURITE pendant TOUTE la partie : apres une teleportation lointaine, Fortnite charge la zone (ecran
    # "deplacement") et peut annuler le gel. Toutes les 0,5 s : un joueur en jeu qui n'est plus devant la table (plus
    # de 1,50 m de sa place) y est REPOSE et REFIGE. S'il est bien a sa place, rien ne se passe.
    # la position ou il a REELLEMENT ete pose a sa place (reference du filet de securite)
    var PoseDe : [player]vector3 = map{}
    GarderEnPlace()<suspends> : void =
        loop:
            Sleep(0.5)
            for (J : Vivants, not EnMachine[J]?, Perso := J.GetFortCharacter[], Perso.IsActive[], P := PoseDe[J]):
                E := Perso.GetTransform().Translation - P
                if (E.X * E.X + E.Y * E.Y > 22500.0):
                    # remis EXACTEMENT a l'endroit retenu (sa vue garde sa direction), puis refige un peu plus tard
                    # (un gel pose en meme temps que la teleportation peut etre annule par Fortnite)
                    Perso.ReleaseFromStasis()
                    if (Perso.TeleportTo[P + vector3{X := 0.0, Y := 0.0, Z := 15.0}, Perso.GetTransform().Rotation]) {}
                    spawn{ RefigerPlusTard(J) }

    RefigerPlusTard(J : player)<suspends> : void =
        Sleep(0.3)
        Verrouiller(J)

    # le joueur est FIGE SUR SA PLACE : s'il en est a plus de 30 cm, il y est d'abord remis, puis fige (tete libre)
    Verrouiller(J : player) : void =
        if (Perso := J.GetFortCharacter[], Perso.IsActive[], not EnMachine[J]?, Contient(Vivants, J)?):
            if (P := PoseDe[J]):
                E := Perso.GetTransform().Translation - P
                if (E.X * E.X + E.Y * E.Y > 900.0):
                    Perso.ReleaseFromStasis()
                    if (Perso.TeleportTo[P + vector3{X := 0.0, Y := 0.0, Z := 15.0}, Perso.GetTransform().Rotation]) {}
            Perso.PutInStasis(stasis_args{AllowTurning := true, AllowFalling := true, AllowEmotes := false})

    # ARRIVEE A LA TABLE : pendant 3 s, il est reverrouille 5 fois par seconde (Fortnite annule parfois le gel
    # pendant le chargement de la zone) : il n'a jamais le temps de bouger
    VerrouArrivee(J : player)<suspends> : void =
        for (K := 1..15):
            Sleep(0.2)
            Verrouiller(J)

    # (un joueur FIGE ignore la rotation : on le libere un instant, on le tourne, on le refige)
    FaceMachine(J : player, Lacet : float)<suspends> : void =
        FaceMachineApres(J, Lacet, array{0.25, 0.35})

    # Delais : les attentes successives avant chaque correction (apres la camera du clavier, la transition
    # de Fortnite remet la vue ailleurs : on corrige plus tard et plusieurs fois)
    FaceMachineApres(J : player, Lacet : float, Delais : []float)<suspends> : void =
        for (Attente : Delais):
            Sleep(Attente)
            if (Perso := J.GetFortCharacter[]):
                Ici := Perso.GetTransform().Translation
                Perso.ReleaseFromStasis()
                if (Perso.TeleportTo[Ici, MakeRotationFromYawPitchRollDegrees(Lacet, 0.0, 0.0)]) {}
                Perso.PutInStasis(stasis_args{AllowTurning := true, AllowFalling := true, AllowEmotes := false})

    AngleCourt(A0 : float)<transacts> : float =
        var A : float = A0
        for (K := 1..4):
            if (A > 180.0):
                set A -= 360.0
            else if (A < -180.0):
                set A += 360.0
        A

    CentreTable()<transacts> : vector3 =
        var Somme : vector3 = vector3{}
        var N : float = 0.0
        for (Pl : Places):
            set Somme = Somme + Pl.GetTransform().Translation
            set N += 1.0
        if (N > 0.0) then Somme / N else BaseCentre.Translation

    # =========================================================================
    #  UNE MANCHE
    # =========================================================================
    Manche(Joueurs : []player)<suspends> : void =
        var Liste0 : []player = array{}
        for (J : Joueurs):
            if (Liste0.Length < Places.Length):
                set Liste0 += array{J}
        # PLACES AU HASARD : on tire au hasard QUELLES places sont prises et QUI va ou ; l'ordre du jeu suit le tour
        # de la table (places triees), pour que la machine tourne toujours dans le bon sens
        ToutesPlaces := for (K := 0..Places.Length - 1) do K
        # decalage tire de l'HEURE (en millisecondes) : change a chaque manche et a chaque session
        Decal := if (T := Floor[GetSimulationElapsedTime() * 1000.0], M := Mod[T, Max(1, Places.Length)]) then M else 0
        Melangees := Shuffle(ToutesPlaces)
        Tournees := for (K := 0..Melangees.Length - 1, I2 := Mod[K + Decal, Melangees.Length], V := Melangees[I2]) do V
        Choisies := if (Sl := Tournees.Slice[0, Liste0.Length]) then TrierEntiers(Sl) else ToutesPlaces
        Liste := Shuffle(Liste0)
        set PlaceDe = map{}
        for (K -> J : Liste, P := Choisies[K]):
            if (set PlaceDe[J] = P) {}
        set Assis = Liste
        set Vivants = Liste
        EnleverCameras()
        set Paquets = map{}
        set Penalites = map{}
        set DefiEnCours = false
        set Sens = 1
        set Bloque = 0
        for (I -> J : Liste):
            Asseoir(J, PlaceIndex(J))
            spawn{ VerrouArrivee(J) }
            if (set Paquets[J] = array{}) {}
        NouvelleGrille()
        EcranRegles()
        Sleep(6.0)
        FermerEcrans()
        ChoixDepart()
        for (N := 0..2):
            Bandeau("ROUND STARTS IN {3 - N}")
            Sleep(1.0)
        Bandeau("")
        # LA ROULETTE : la machine fait plusieurs tours et s'arrete sur le premier joueur (1 chance sur N)
        var Index : int = GetRandomInt(0, Max(0, Vivants.Length - 1))
        if (Premier := Vivants[Index]):
            TournerVersAvec(Premier, Max(0, ToursRoulette))
        loop:
            set Vivants = for (J : Vivants, EstLa(J)?) do J
            # a plusieurs : le dernier en jeu gagne. En TEST SOLO : on joue jusqu'a tomber sur un piege.
            if (Vivants.Length = 0 or (Vivants.Length = 1 and not TestSolo?)):
                break
            if (M := Mod[Index + Vivants.Length * 100, Vivants.Length]):
                set Index = M
            if (J := Vivants[Index]):
                Elimine := TourDe(J)
                if (Elimine?):
                    set Vivants = for (X : Vivants, X <> J) do X
                    # il MEURT, reapparait, et est pose un peu au loin : de la, il regarde la partie
                    spawn{ DevenirSpectateur(J, Assis.Length - Vivants.Length - 1) }
                    if (Sens < 0):
                        set Index -= 1
                else:
                    set Index += Sens
        # fin de manche
        FermerEcrans()
        if (G := Vivants[0], not TestSolo?):
            CinematiqueVictoire(G)
        else:
            Bandeau(if (TestSolo?) then "GAME OVER - THE TRAP GOT YOU" else "NO WINNER")
            # TEST SOLO : la cinematique est jouee quand meme sur toi, pour la regler
            if (TestSolo?, Seul := Assis[0]):
                CinematiqueVictoire(Seul)
            else:
                Sleep(4.0)
        Bandeau("")
        set Orientations = map{}
        set PoseDe = map{}
        for (J : Assis, not Contient(DejaRentres, J)?, Perso := J.GetFortCharacter[]):
            Perso.ReleaseFromStasis()
        EnleverCameras()
        RenvoyerAuLobby(Assis)
        set Table = array{}
        set DejaRentres = array{}

    # le joueur va a sa place (debout, ou assis avec l'animation), tourne vers la machine, fige, a la premiere personne
    Asseoir(J : player, I : int, ?Annonce : logic = true) : void =
        if (Pl := Places[I], Perso := J.GetFortCharacter[]):
            Ici := Pl.GetTransform().Translation
            # le VRAI centre de la table (moyenne des Places) : le pivot de la machine importee n'est pas au milieu
            C := CentreTable()
            LacetRad := ArcTan(C.Y - Ici.Y, C.X - Ici.X)
            Lacet := LacetRad * 180.0 / PiFloat
            Avant := vector3{X := Cos(LacetRad), Y := Sin(LacetRad), Z := 0.0}
            Pose := Ici + Avant * AvanceAssis + vector3{X := 0.0, Y := 0.0, Z := HauteurAssis}
            Rot := MakeRotationFromYawPitchRollDegrees(Lacet + CorrectionVue, 0.0, 0.0)
            # Fortnite REFUSE la teleportation si le joueur ne rentre pas a cet endroit : on essaie plus haut, puis devant
            Resultat := PoserPres(Perso, Pose, Avant, Rot)
            Exact := if (Resultat = 0) then true else false
            if (TestSolo?, Annonce?):
                Avertir(J, if (Resultat = 0) then "SEAT: ON YOUR PLACE" else if (Resultat = 1) then "SEAT: SOMETHING IN THE WAY - DROPPED FROM ABOVE" else if (Resultat = 2) then "SEAT: SOMETHING IN THE WAY - IN FRONT" else "SEAT: TELEPORT REFUSED - MOVE YOUR PLACE")
            if (Resultat >= 0):
                Vue := Lacet + CorrectionVue
                if (set Orientations[J] = Vue) {}
                spawn{ FaceMachine(J, Vue) }
                Perso.PutInStasis(stasis_args{AllowTurning := true, AllowFalling := if (Exact?) then false else true, AllowEmotes := false})
                # on retient l'endroit DEMANDE (sa place), pas la position lue juste apres la teleportation (elle peut
                # encore etre l'ancienne : il serait alors teleporte en boucle sans bouger)
                if (set PoseDe[J] = Pose) {}
                spawn{ RefigerPlusTard(J) }
            else:
                # teleportation refusee partout : il est quand meme FIGE (jamais libre de marcher a la table)
                Perso.PutInStasis(stasis_args{AllowTurning := true, AllowFalling := true, AllowEmotes := false})

    # teleporte le joueur a Pose ; si Fortnite refuse (il ne rentre pas : table, mur...), plus haut, puis devant.
    # 0 = pile a Pose, 1 = au-dessus (il tombe), 2 = devant, -1 = refuse partout (il reste ou il est)
    PoserPres(Perso : fort_character, Pose : vector3, Avant : vector3, Rot : rotation) : int =
        var Resultat : int = -1
        if (Perso.TeleportTo[Pose, Rot]):
            set Resultat = 0
        # (jamais trop haut : a 1,30 m ou 2 m, il pouvait se retrouver dans le toit -> ecran noir)
        for (H : array{15.0, 40.0, 80.0}, Resultat < 0):
            if (Perso.TeleportTo[Pose + vector3{X := 0.0, Y := 0.0, Z := H}, Rot]):
                set Resultat = 1
        for (D : array{60.0, 120.0}, Resultat < 0):
            if (Perso.TeleportTo[Pose + Avant * D + vector3{X := 0.0, Y := 0.0, Z := 40.0}, Rot]):
                set Resultat = 2
        Resultat

    TirerRelique()<transacts> : int = GetRandomInt(0, 4)

    # encore la et encore a CETTE table (pas rentre au lobby par le bouton)
    ALaTable(J : player)<transacts> : logic =
        if (EstLa(J)?, not Contient(DejaRentres, J)?) then true else false

    EstLa(J : player)<transacts> : logic =
        var Trouve : logic = false
        for (X : GetPlayspace().GetPlayers(), X = J):
            set Trouve = true
        Trouve

    Contient(Liste : []player, J : player)<transacts> : logic =
        var Trouve : logic = false
        for (X : Liste, X = J):
            set Trouve = true
        Trouve

    # la place (index dans Places) tiree au hasard pour ce joueur
    var PlaceDe : [player]int = map{}
    PlaceIndex(J : player)<transacts> : int =
        if (P := PlaceDe[J]) then P else NumeroDe(J) - 1

    TrierEntiers(L : []int)<transacts> : []int =
        var R : []int = L
        for (A := 0..R.Length - 1):
            for (B := 0..R.Length - 2):
                if (X := R[B], Y := R[B + 1], X > Y):
                    if (set R[B] = Y, set R[B + 1] = X) {}
        R

    NumeroDe(J : player)<transacts> : int =
        var N : int = 0
        for (I -> X : Assis, X = J):
            set N = I + 1
        N

    # =========================================================================
    #  LA MACHINE
    # =========================================================================
    # pieges par grille : 1 par joueur (2 a 2 joueurs, 3 a 3, 4 a 4, jamais plus de 4), au moins PiegesParGrille
    NombrePieges()<transacts> : int =
        Max(PiegesParGrille, Min(4, Assis.Length))

    NouvelleGrille() : void =
        set Enfoncee = for (T : Touches) do false
        set Piegee = for (T : Touches) do false
        var Poses : int = 0
        var Essais : int = 0
        loop:
            if (Poses >= Min(NombrePieges(), Touches.Length - 1) or Essais > 500):
                break
            set Essais += 1
            K := GetRandomInt(0, Touches.Length - 1)
            if (not Piegee[K]?, set Piegee[K] = true):
                set Poses += 1
        set BoutonBlanc = -1
        set BoutonVert = -1
        for (K -> T : Touches, B := BaseTouches[K]):
            spawn{ Bouger(T, Tournee(B, LacetMachine), 0.25) }
            Peindre(K)

    # une piece de la machine, tournee de Lacet degres autour du centre de la machine
    Tournee(B : transform, Lacet : float) : transform =
        R := MakeRotation(vector3{X := 0.0, Y := 0.0, Z := 1.0}, DegreesToRadians(Lacet))
        C := BaseCentre.Translation
        transform{Translation := C + R.RotateVector(B.Translation - C), Rotation := B.Rotation.RotateBy(R), Scale := B.Scale}

    # TOUTE la machine pivote vers le joueur J (le chemin le plus court), avec le son de rotation.
    # TEST SOLO : deja tournee vers lui -> un tour complet dans le vide, et elle revient sur lui.
    TournerVers(J : player)<suspends> : void =
        TournerVersAvec(J, 0)

    # Tours > 0 : la ROULETTE du debut de manche (plusieurs tours complets, puis elle s'arrete d'un coup sur J)
    TournerVersAvec(J : player, Tours : int)<suspends> : void =
        I := PlaceIndex(J)
        if (Pl := Places[I]):
            Ici := Pl.GetTransform().Translation
            C := BaseCentre.Translation
            Brut := ArcTan(Ici.Y - C.Y, Ici.X - C.X) * 180.0 / PiFloat - FaceDepart
            # la machine ne tourne QUE par quarts de tour (0, 90, 180, 270) depuis sa position de depart :
            # elle prend le quart de tour le plus proche de la place, meme si la place est decalee de quelques degres
            Cible := if (Q := Round[Brut / 90.0]) then Q * 90.0 else Brut
            var Ecart : float = Cible - LacetMachine
            loop:
                if (Ecart <= 180.0):
                    break
                set Ecart -= 360.0
            loop:
                if (Ecart > -180.0):
                    break
                set Ecart += 360.0
            # la machine tourne TOUJOURS dans le sens du jeu : apres un REVERSE, elle repart dans l'autre sens
            Dir := SensRotation()
            if (Dir > 0.0, Ecart < -2.0):
                set Ecart += 360.0
            if (Dir < 0.0, Ecart > 2.0):
                set Ecart -= 360.0
            if (Abs(Ecart) <= 2.0, TestSolo?, DernierTourne = I, Tours = 0, not ApresRoulette?):
                set Ecart = 360.0 * Dir
            set ApresRoulette = if (Tours > 0) then true else false
            if (Tours > 0):
                set Ecart += 360.0 * (Tours * 1.0) * Dir
            set DernierTourne = I
            if (Abs(Ecart) > 2.0):
                Duree := if (Tours > 0) then DureeRoulette else Max(0.2, DureeRotation * (if (Abs(Ecart) > 300.0) then 1.6 else 1.0))
                # un ordre de deplacement tous les 45 degres seulement (avant : tous les 8-15 degres) : chaque ordre
                # arrive un peu decale chez les joueurs -> moins d'ordres = plus d'a-coups ni de boutons qui se decollent
                Pas := if (N := Ceil[Abs(Ecart) / 45.0]) then Max(1, N) else 1
                Dt := Duree / (Pas * 1.0)
                Depart := LacetMachine
                SonRotation.Play()
                for (K := 1..Pas):
                    Frac := (K * 1.0) / (Pas * 1.0)
                    # vitesse constante, et elle s'arrete d'un coup (roulette comprise)
                    L := Depart + Ecart * Frac
                    if (not PiecesAttachees?):
                        spawn{ Bouger(Plaque, Tournee(BasePlaque, L), Dt) }
                    for (N2 -> T : Touches, B := BaseTouches[N2], not PiecesAttachees?):
                        Pose := Tournee(B, L)
                        Bas := if (Enfoncee[N2]?) then Enfoncement else 0.0
                        spawn{ Bouger(T, transform{Translation := Pose.Translation - vector3{X := 0.0, Y := 0.0, Z := Bas}, Rotation := Pose.Rotation, Scale := Pose.Scale}, Dt) }
                    # le pas suivant part quand le CORPS ET LA GUEULE ont fini : la gueule n'est plus coupee en
                    # plein mouvement par l'ordre suivant (c'est ce qui la faisait sauter)
                    race:
                        sync:
                            Bouger(Centre, Tournee(BaseCentre, L), Dt)
                            if (not PiecesAttachees?):
                                Bouger(Gueule, Tournee(BaseGueule, L), Dt)
                        Sleep(Dt + 0.15)
                set LacetMachine = Depart + Ecart
                SonRotation.Stop()
                SonArret.Play()

    # +1 / -1 : le sens dans lequel la machine tourne pour aller au joueur SUIVANT (selon la position des Places
    # autour de la table), inverse par REVERSE
    SensRotation()<transacts> : float =
        var Naturel : float = 1.0
        if (P0 := Places[0], P1 := Places[1]):
            C := CentreTable()
            A0 := ArcTan(P0.GetTransform().Translation.Y - C.Y, P0.GetTransform().Translation.X - C.X) * 180.0 / PiFloat
            A1 := ArcTan(P1.GetTransform().Translation.Y - C.Y, P1.GetTransform().Translation.X - C.X) * 180.0 / PiFloat
            if (AngleCourt(A1 - A0) < 0.0):
                set Naturel = -1.0
        Naturel * (Sens * 1.0)

    Bouger(T : creative_prop, Ou : transform, Duree : float)<suspends> : void =
        T.MoveTo(Ou.Translation, Ou.Rotation, Duree)

    PiegesRestants()<transacts> : int =
        var N : int = 0
        for (K -> P : Piegee, P?, not Enfoncee[K]?):
            set N += 1
        N

    LibresRestants()<transacts> : int =
        var N : int = 0
        for (E : Enfoncee, not E?):
            set N += 1
        N

    # un bouton libre et SUR au hasard (-1 s'il n'y en a pas)
    BoutonSur()<transacts> : int =
        var Sures : []int = array{}
        for (K -> E : Enfoncee, not E?, not Piegee[K]?):
            set Sures += array{K}
        if (K := Sures[GetRandomInt(0, Sures.Length - 1)]) then K else -1

    BoutonLibre()<transacts> : int =
        var Libres : []int = array{}
        for (K -> E : Enfoncee, not E?):
            set Libres += array{K}
        if (K := Libres[GetRandomInt(0, Libres.Length - 1)]) then K else -1

    # le bouton K prend son materiau : blanc s'il est vise, vert si c'est le bouton sur du PEEK, normal sinon
    Peindre(K : int) : void =
        if (T := Touches[K]):
            PeindreProp(T, K)

    PeindreProp(T : creative_prop, K : int) : void =
        if (K = BoutonBlanc):
            T.SetMaterial(Teintes.T_Clair{}, ?Index := IndexMateriau)
        else if (K = BoutonVert):
            T.SetMaterial(Teintes.T_Sur{}, ?Index := IndexMateriau)
        else:
            # le materiau D'ORIGINE des boutons de la nouvelle machine (Salle_Porcherie/Materials/M_Touches)
            T.SetMaterial(Salle_Porcherie.Materials.M_Touches{}, ?Index := IndexMateriau)

    # le bouton vise devient blanc (-1 = aucun) ; l'ancien reprend sa couleur
    Surligner(K : int) : void =
        Ancien := BoutonBlanc
        set BoutonBlanc = K
        if (Ancien <> K):
            Peindre(Ancien)
            Peindre(K)

    # PEEK : le bouton sur devient vert (-1 = plus de vert)
    Verdir(K : int) : void =
        Ancien := BoutonVert
        set BoutonVert = K
        Peindre(Ancien)
        Peindre(K)

    # =========================================================================
    #  UN TOUR : (jouer une carte et l'annoncer une carte, vraie ou bluff) -> appuyer soi-meme sur la machine
    #  renvoie true si le joueur est elimine
    # =========================================================================
    TourDe(J : player)<suspends> : logic =
        TournerVers(J)
        Penalite := if (P := Penalites[J]) then P else 0
        if (set Penalites[J] = 0) {}
        # JAM CUMULES : les boutons en plus qui lui arrivent dessus. S'il joue un JAM a son tour, il les PASSE au
        # suivant (+1). Sinon, il les prend tous.
        var Attente : int = Bloque
        set Bloque = 0
        var Requis : int = 1 + Penalite
        var Bouclier : logic = false
        var Vu : int = -1
        var Passe : logic = false
        var Elimine : logic = false

        if (Attente > 0):
            AnimerPlus("+{Attente}", "P{NumeroDe(J)} MUST PRESS {Attente} MORE!", "PLAY A JAM TO PASS IT ON!", J)

        # --- 1. SON CHOIX : JOUER une carte OU NO CARD (pas de pioche : les 3 cartes sont choisies au debut)
        var Index : int = -1
        var Id : int = -1
        loop:
            Action := ChoisirAction(J, Attente)
            if (Action = 0):
                Jeu := JouerCarte(J)
                # BACK (-2) : il revient au choix PLAY A CARD / NO CARD ; sinon c'est joue
                if (Jeu(0) <> -2):
                    set Index = Jeu(0)
                    set Id = Jeu(1)
                    break
            else:
                break
        if (Index >= 0, Paquet := Paquets[J], Reelle := Paquet[Index]):
            # la carte quitte sa main, tout le monde la voit, et elle agit tout de suite
            RetirerRelique(J, Index)
            CartePosee(J, Reelle)
            Effet := true
            if (Effet?):
                if (Id = 0):
                    set Bouclier = true
                else if (Id = 1):
                    set Vu = BoutonSur()
                    Verdir(Vu)
                else if (Id = 2):
                    set Passe = true
                    # PASS : les boutons en attente passent au suivant
                    set Bloque = Attente
                    set Attente = 0
                else if (Id = 3):
                    set Sens = -Sens
                else if (Id = 4):
                    # JAM : il passe tout au suivant, +1
                    set Bloque = Attente + 1
                    set Attente = 0
                    AnimerPlus("+{Bloque}", "NEXT PLAYER MUST PRESS {Bloque} MORE!", "", J)

        # les JAM qu'il n'a pas passes : il les prend
        set Requis += Attente

        # --- 2. LA MACHINE : il vise un bouton (il devient blanc) et clique, Requis fois
        if (not Passe?):
            if (Camera := CameraDe(J)?):
                Camera.AddTo(J)
                if (set EnMachine[J] = true) {}

            Fin := GetSimulationElapsedTime() + DureeTour
            loop:
                if (Requis <= 0 or Elimine? or LibresRestants() = 0):
                    break
                K := ViserEtCliquer(J, Requis, Vu, Fin)
                if (K >= 0):
                    if (K = Vu):
                        set Vu = -1
                        Verdir(-1)
                    Appuyer(J, K)
                    if (Piegee[K]?):
                        if (Bouclier?):
                            set Bouclier = false
                            Avertir(J, "DEFUSED! THE TRAP DIDN'T BITE")
                            if (PiegesRestants() = 0):
                                NouvelleGrille()
                            set Requis = 0
                        else:
                            Croc(J)
                            set Elimine = true
                    else:
                        Feinte()
                        set Requis -= 1
            if (not Elimine?):
                # retour a sa place SANS temps mort : ecran noir tres court, on le re-pose (comme au debut de la
                # manche) PENDANT qu'il voit encore la camera du clavier, on enleve la camera, on corrige tout de suite
                RetourPlace(J)
            else if (Camera := CameraDe(J)?):
                Camera.RemoveFrom(J)
            if (set EnMachine[J] = false) {}
        Surligner(-1)
        Verdir(-1)
        FermerEcrans()
        Elimine

    # mordu : le personnage meurt ; quand il reapparait, il est assis sur le siege numero K (au loin)
    # mordu : il n'est plus dans le jeu ; il est LIBRE de se deplacer dans la piece (il regarde les autres jouer)
    # ou il rentre au lobby avec le bouton BACK TO LOBBY
    DevenirSpectateur(J : player, K : int)<suspends> : void =
        Sleep(0.5)
        if (Perso := J.GetFortCharacter[]):
            Perso.ReleaseFromStasis()
            # INVISIBLE pour les autres : en se promenant, il ne peut pas cacher la machine aux joueurs encore en jeu
            # (il redevient visible en rentrant au lobby)
            Perso.Hide()
            # il est envoye a un point de la piece (le K-ieme mordu va au K-ieme point), tourne vers la table
            if (Ix := Mod[K, Max(1, PointsElimines.Length)], Pl := PointsElimines[Ix]):
                Ici := Pl.GetTransform().Translation
                C := CentreTable()
                Lacet := ArcTan(C.Y - Ici.Y, C.X - Ici.X) * 180.0 / PiFloat
                Resultat := PoserPres(Perso, Ici, vector3{X := 0.0, Y := 0.0, Z := 0.0}, MakeRotationFromYawPitchRollDegrees(Lacet, 0.0, 0.0))

    # il vise avec la camera : le bouton vise devient blanc ; un clic l'enfonce. Temps ecoule : bouton au hasard.
    ViserEtCliquer(J : player, Requis : int, Vu : int, Fin : float)<suspends> : int =
        if (Camera := CameraDe(J)?):
            return CliquerALaSouris(J, Requis, Vu, Fin)
        # pas de camera fixe pour cette place (oubli dans l'editeur) : bouton au hasard a la fin du temps
        if (TestSolo?):
            Avertir(J, "NO KEYPAD CAMERA NEAR YOUR PLACE - CHECK CamerasClavier")
        EcranVisee(J, Requis, Vu, false)
        Sleep(Max(0.0, Fin - GetSimulationElapsedTime()))
        BoutonLibre()

    # CAMERA FIXE : le curseur de la souris passe sur les boutons de la machine (ils deviennent blancs), un clic
    # enfonce le bouton. Temps ecoule : bouton au hasard.
    CliquerALaSouris(J : player, Requis : int, Vu : int, Fin : float)<suspends> : int =
        EcranVisee(J, Requis, Vu, true)
        PoserZones(J)
        var Choisi : int = -1
        loop:
            Reste := Fin - GetSimulationElapsedTime()
            MajChronos(Reste)
            if (Reste <= 0.0):
                set Choisi = BoutonLibre()
                break
            var Recu : int = -2
            race:
                Sleep(Min(0.5, Reste))
                block:
                    set Recu = Choix.Await()
            if (Recu >= 0, Recu < Touches.Length, not Enfoncee[Recu]?):
                set Choisi = Recu
                break
        Surligner(-1)
        Choisi

    # le bouton numero K (Bouton_01 = 0) est dans quelle rangee / colonne de l'ecran (0 = en haut / a gauche)
    RangeeDe(K : int)<transacts> : int =
        R := if (Q := Floor[(K * 1.0) / (Colonnes * 1.0)]) then Q else 0
        if (InverserLignes?) then 5 - R else R

    ColonneDe(K : int)<transacts> : int =
        C := if (M := Mod[K, Colonnes]) then M else 0
        if (InverserColonnes?) then Colonnes - 1 - C else C

    # une zone de clic invisible (TEST1) sur chaque bouton libre, a sa place exacte A L'ECRAN
    PoserZones(J : player) : void =
        if (C := Ecrans[J]):
            for (K -> T : Touches, not Enfoncee[K]?, R := RangeeDe(K), H0 := LignesY[R], H1 := LignesY[R + 1], G0 := BordGauche[R], G1 := BordGauche[R + 1], D0 := BordDroit[R], D1 := BordDroit[R + 1]):
                Gauche := (G0 + G1) * 0.5
                Droite := (D0 + D1) * 0.5
                Largeur := (Droite - Gauche) / (Colonnes * 1.0)
                X := Gauche + (ColonneDe(K) * 1.0 + 0.5) * Largeur
                Y := (H0 + H1) * 0.5
                # taille de la zone (unites de l'interface : 1920 x 1080), un peu plus petite que le bouton
                L := Largeur * 1920.0 * 0.88
                H := (H1 - H0) * 1080.0 * 0.88
                Zone := TEST1{}
                ZB := zone_bouton{Manager := Self, K := K, Zone := Zone}
                spawn{ ZB.Suivre() }
                C.AddWidget(canvas_slot{Widget := Zone, Anchors := anchors{Minimum := vector2{X := X, Y := Y}, Maximum := vector2{X := X, Y := Y}},
                    Alignment := vector2{X := 0.5, Y := 0.5}, Offsets := margin{Left := 0.0, Top := 0.0, Right := L, Bottom := H}, SizeToContent := false})

    # les 6 cartes a l'ecran (survol plus clair) + NO CARD. Renvoie la carte annoncee, ou -1.
    # PIOCHER : une carte arrive dans sa main
    Piocher(J : player)<suspends> : void =
        if (M := Paquets[J], M.Length < PaquetMax, set Paquets[J] = M + array{TirerRelique()}):
            SonCarte.Play()
            Avertir(J, "+1 CARD")
        for (X : Assis, X <> J, ALaTable(X)?):
            Avertir(X, "P{NumeroDe(J)} DRAWS A CARD")

    # SON CHOIX : PLAY A CARD (0) ou NO CARD (1). 0 carte : pas d'ecran, il va direct a la machine (-1).
    # Temps ecoule : NO CARD.
    ChoisirAction(J : player, Attente : int)<suspends> : int =
        N := NombreDe(J)
        if (N = 0):
            return -1
        PeutJouer := true
        PeutPiocher := true
        EcranAction(J, Attente, PeutJouer, PeutPiocher)
        var Action : int = 1
        Fin := GetSimulationElapsedTime() + DureeChoixCarte
        loop:
            Reste := Fin - GetSimulationElapsedTime()
            MajChronos(Reste)
            if (Reste <= 0.0):
                break
            var Recu : int = -2
            race:
                Sleep(Min(0.5, Reste))
                block:
                    set Recu = Choix.Await()
            if (Recu = 410, PeutJouer?):
                set Action = 0
                break
            if (Recu = 411, PeutPiocher?):
                set Action = 1
                break
        FermerEcrans()
        Action

    # "+2", "+3"... en GROS au milieu de l'ecran de tout le monde, qui surgit (comme un +2 d'Uno)
    AnimerPlus(Gros : string, Ligne1 : string, Ligne2 : string, Qui : player)<suspends> : void =
        var Calques : [player]canvas = map{}
        for (Taille : array{90.0, 190.0, 300.0, 250.0, 270.0}):
            for (X : Assis, ALaTable(X)?, IU := GetPlayerUI[X]):
                if (Ancien := Calques[X]):
                    IU.RemoveWidget(Ancien)
                var S : []canvas_slot = TexteEcrit(Gros, 0.5, 0.5, 0.0, -60.0, Taille)
                set S += TexteEcrit(Ligne1, 0.5, 0.5, 0.0, 120.0, 52.0)
                if (X = Qui):
                    set S += TexteEcrit(Ligne2, 0.5, 0.5, 0.0, 190.0, 44.0)
                C := canvas{Slots := S}
                IU.AddWidget(C)
                if (set Calques[X] = C) {}
            Sleep(0.06)
        SonBoom.Play()
        Sleep(1.6)
        for (X -> C : Calques, IU := GetPlayerUI[X]):
            IU.RemoveWidget(C)

    # JOUER : il clique une carte de sa main -> TRUTH (il la joue pour ce qu'elle est) ou LIE (il dit que c'est
    # une autre : il choisit laquelle). SKIP = pas de carte.
    # Renvoie (place de la carte dans sa main, carte annoncee), ou (-1, -1).
    JouerCarte(J : player)<suspends> : tuple(int, int) =
        if (NombreDe(J) = 0):
            Avertir(J, "NO CARD IN YOUR HAND")
            return (-1, -1)
        var Choisie : int = -1
        var Mensonge : logic = false
        var Resultat : tuple(int, int) = (-1, -1)
        EcranJouer(J, Choisie, Mensonge)
        Fin := GetSimulationElapsedTime() + DureeChoixCarte
        loop:
            Reste := Fin - GetSimulationElapsedTime()
            MajChronos(Reste)
            if (Reste <= 0.0):
                break
            var Recu : int = -2
            race:
                Sleep(Min(0.5, Reste))
                block:
                    set Recu = Choix.Await()
            # un clic sur une carte de sa main : elle est jouee tout de suite (plus de mensonge)
            if (Recu >= 100, Recu < 100 + PaquetMax, Paquet := Paquets[J], Reelle := Paquet[Recu - 100]):
                set Resultat = (Recu - 100, Reelle)
                break
            else if (Recu = 197):
                set Resultat = (-2, -2)
                break
        FermerEcrans()
        Resultat

    # LA NOTIFICATION en haut a gauche pour tout le monde : "P2 PLAYED REVERSE" + la petite carte, qui glisse et
    # dont le fond sombre transparent apparait / disparait en fondu
    NotifierCarte(J : player, Id : int) : void =
        for (X : Table):
            spawn{ Notification(X, "P{NumeroDe(J)} PLAYED", NomRelique(Id), ImageRelique(Id)) }

    Notification(X : player, Ligne1 : string, Ligne2 : string, Image : texture)<suspends> : void =
        if (IU := GetPlayerUI[X]):
            Fond := color_block{DefaultColor := color{R := 0.05, G := 0.05, B := 0.06}, DefaultOpacity := 0.0}
            Opa : []type{_X:float where 0.0 <= _X, _X <= 1.0} = array{0.0, 0.12, 0.24, 0.36, 0.48, 0.55}
            var Actuel : ?canvas = false
            Positions : []float = array{-420.0, -300.0, -190.0, -100.0, -40.0, 0.0}
            # entree : glisse depuis la gauche, le fond apparait
            for (K -> Dx : Positions):
                if (O := Opa[K]):
                    Fond.SetOpacity(O)
                C := DessinerNotif(Fond, Ligne1, Ligne2, Image, Dx)
                if (A := Actuel?):
                    IU.RemoveWidget(A)
                IU.AddWidget(C)
                set Actuel = option{C}
                Sleep(0.04)
            Sleep(3.0)
            # sortie : le fond s'efface et ca repart a gauche
            for (K := 0..5):
                if (O := Opa[5 - K], Dx := Positions[5 - K]):
                    Fond.SetOpacity(O)
                    C := DessinerNotif(Fond, Ligne1, Ligne2, Image, Dx)
                    if (A := Actuel?):
                        IU.RemoveWidget(A)
                    IU.AddWidget(C)
                    set Actuel = option{C}
                Sleep(0.04)
            if (A := Actuel?):
                IU.RemoveWidget(A)

    DessinerNotif(Fond : color_block, Ligne1 : string, Ligne2 : string, Image : texture, Dx : float) : canvas =
        X0 := 30.0 + Dx
        var S : []canvas_slot = array{canvas_slot{Widget := Fond, Anchors := anchors{Minimum := vector2{X := 0.0, Y := 0.0}, Maximum := vector2{X := 0.0, Y := 0.0}},
            Offsets := margin{Left := X0, Top := 330.0, Right := 380.0, Bottom := 110.0}, SizeToContent := false}}
        set S += array{PlaceH(ImgH(Image, 96.0, 96.0), 0.0, 0.0, X0 + 58.0, 385.0, 96.0, 96.0)}
        set S += TexteGauche(Ligne1, 0.0, 0.0, X0 + 118.0, 360.0, 30.0)
        set S += TexteGauche(Ligne2, 0.0, 0.0, X0 + 118.0, 405.0, 44.0)
        canvas{Slots := S}

    # la carte jouee, en grand, pour tout le monde (1,6 s)
    CartePosee(J : player, Id : int)<suspends> : void =
        NotifierCarte(J, Id)
        FermerEcrans()
        SonCarte.Play()
        for (X : Assis, ALaTable(X)?):
            Chrono := NouveauChrono()
            var S : []canvas_slot = Entete(X, Chrono)
            set S += array{PlaceH(ImgH(ImageRelique(Id), 400.0, 400.0), 0.5, 0.5, 0.0, -20.0, 400.0, 400.0)}
            set S += TexteEcrit("P{NumeroDe(J)} PLAYS {NomRelique(Id)}!", 0.5, 0.5, 0.0, -270.0, 80.0)
            Montrer(X, S, Chrono, false)
        Sleep(1.6)
        FermerEcrans()

    EffacerBandeau(Apres : float)<suspends> : void =
        Sleep(Apres)
        if (not DefiEnCours?):
            Bandeau("")

    # place de la carte Id dans la main du joueur (-1 s'il ne l'a pas)
    IndexRelique(J : player, Id : int)<transacts> : int =
        var Trouve : int = -1
        if (M := Paquets[J]):
            for (I -> X : M, X = Id, Trouve < 0):
                set Trouve = I
        Trouve

    NombreDe(J : player)<transacts> : int =
        if (M := Paquets[J]) then M.Length else 0

    CombienDe(J : player, Id : int)<transacts> : int =
        var N : int = 0
        if (M := Paquets[J]):
            for (X : M, X = Id):
                set N += 1
        N

    RetirerRelique(J : player, Index : int) : void =
        if (M := Paquets[J], set Paquets[J] = for (I -> X : M, I <> Index) do X) {}

    RetirerReliqueAuHasard(J : player) : void =
        if (M := Paquets[J], M.Length > 0):
            RetirerRelique(J, GetRandomInt(0, M.Length - 1))

    # le bouton s'enfonce
    Appuyer(J : player, K : int)<suspends> : void =
        if (set Enfoncee[K] = true) {}
        if (T := Touches[K], B0 := BaseTouches[K]):
            B := Tournee(B0, LacetMachine)
            spawn{ Bouger(T, transform{Translation := B.Translation - vector3{X := 0.0, Y := 0.0, Z := Enfoncement}, Rotation := B.Rotation, Scale := B.Scale}, 0.1) }
        Sleep(0.1)
        SonClic.Play()
        Sleep(0.4)

    # piege : la machoire claque (fermee completement), jumpscare pour la victime, puis elle se rouvre
    # et la grille repart a zero
    Croc(J : player)<suspends> : void =
        PoseG := Tournee(BaseGueule, LacetMachine)
        SonBoom.Play()
        # la victime : le JUMPSCARE en plein ecran ; les autres : la machoire qui claque et le message
        sync:
            JouerCauchemar(J)
            block:
                Gueule.MoveTo(PoseG.Translation, RotationGueule(AngleFermeture), 0.12)
                for (X : Table, X <> J):
                    MessagePour(X, "P{NumeroDe(J)} GOT BITTEN!")
                Sleep(1.6)
                Gueule.MoveTo(PoseG.Translation, PoseG.Rotation, 0.8)
        Bandeau("")
        NouvelleGrille()

    # la machoire fermee de Angle degres (machine tournee vers le joueur actuel)
    RotationGueule(Angle : float) : rotation =
        Axe := if (AxeFermeture = 0) then vector3{X := 1.0, Y := 0.0, Z := 0.0} else if (AxeFermeture = 2) then vector3{X := 0.0, Y := 0.0, Z := 1.0} else vector3{X := 0.0, Y := 1.0, Z := 0.0}
        Lacet := MakeRotation(vector3{X := 0.0, Y := 0.0, Z := 1.0}, DegreesToRadians(LacetMachine))
        PoseG := Tournee(BaseGueule, LacetMachine)
        PoseG.Rotation.RotateBy(MakeRotation(Lacet.RotateVector(Axe), DegreesToRadians(Angle)))

    # LA FEINTE : bouton sur -> la machoire claque un peu, d'un coup, puis se rouvre (on a eu peur pour rien)
    Feinte()<suspends> : void =
        PoseG := Tournee(BaseGueule, LacetMachine)
        Gueule.MoveTo(PoseG.Translation, RotationGueule(AngleFeinte), 0.07)
        Gueule.MoveTo(PoseG.Translation, PoseG.Rotation, 0.25)

    # LE JUMPSCARE, pour la victime seulement : ecran noir le temps de charger les premieres images (0,35 s),
    # puis les images calees sur l'horloge, avec le son (pour elle seule)
    JouerCauchemar(J : player)<suspends> : void =
        # plus AUCUN texte a l'ecran pendant le screamer (ecrans, chrono, message du haut, vue de la table)
        FermerEcrans()
        MessagePour(J, "")
        if (IU := GetPlayerUI[J], Premiere := ImagesCauchemar[0]):
            Plein := anchors{Minimum := vector2{X := 0.0, Y := 0.0}, Maximum := vector2{X := 1.0, Y := 1.0}}
            Couches := for (Im : ImagesCauchemar) do texture_block{DefaultImage := Im, DefaultDesiredSize := vector2{X := 1920.0, Y := 1080.0}}
            Ecran := texture_block{DefaultImage := Premiere, DefaultDesiredSize := vector2{X := 1920.0, Y := 1080.0}}
            Noir := color_block{DefaultColor := color{R := 0.0, G := 0.0, B := 0.0}, DefaultOpacity := 1.0}
            Scene := canvas{Slots := array{canvas_slot{Widget := Noir, Anchors := Plein, Offsets := margin{}, ZOrder := 3}}}
            IU.AddWidget(Scene)
            Fenetre := fenetre_images{Scene := Scene, Couches := Couches, Plein := Plein}
            Fenetre.Avancer(0, 30)
            Sleep(0.35)
            Scene.AddWidget(canvas_slot{Widget := Ecran, Anchors := Plein, Offsets := margin{}, ZOrder := 2})
            Scene.RemoveWidget(Noir)
            SonCauchemar.Register(J)
            SonCauchemar.Play(J)
            N := ImagesCauchemar.Length
            Debut := GetSimulationElapsedTime()
            var Affichee : int = 0
            loop:
                Sleep(0.0)
                I := if (V := Floor[(GetSimulationElapsedTime() - Debut) * Max(1.0, ImagesParSecondeCauchemar)]) then V else 0
                if (I >= N):
                    break
                if (I <> Affichee, Im := ImagesCauchemar[I]):
                    Ecran.SetImage(Im)
                    set Affichee = I
                    Fenetre.Avancer(I, 30)
            IU.RemoveWidget(Scene)
            SonCauchemar.Stop(J)
            SonCauchemar.Unregister(J)

    # =========================================================================
    #  INTERFACE (seulement des images et du texte : on joue sur la vraie machine)
    # =========================================================================
    FermerEcrans() : void =
        FinEcran.Signal()
        set DernierChrono = -1
        for (J -> C : Ecrans, IU := GetPlayerUI[J]):
            IU.RemoveWidget(C)
        set Ecrans = map{}
        set Chronos = map{}

    var DernierChrono : int = -1
    MajChronos(Reste : float) : void =
        if (S := Ceil[Reste]):
            V := Max(0, Min(99, S))
            # les chiffres ne sont redessines que quand la seconde change (sinon on ne fait rien)
            if (V = DernierChrono):
                return
            set DernierChrono = V
            Dizaine := if (Q := Floor[(V * 1.0) / 10.0]) then Q else 0
            Unite := if (R := Mod[V, 10]) then R else 0
            for (J -> T : Chronos, Diz := T[0], Uni := T[1]):
                if (G := GlypheChiffre(Dizaine)?):
                    Diz.SetImage(G)
                Diz.SetVisibility(if (Dizaine > 0) then widget_visibility.Visible else widget_visibility.Hidden)
                if (G := GlypheChiffre(Unite)?):
                    Uni.SetImage(G)

    # ce que tout le monde voit en haut (ecriture pinceau) : chrono, danger, sa place, le nombre de cartes des autres
    Entete(J : player, Chrono : []texture_block) : []canvas_slot =
        var S : []canvas_slot = array{}
        Libres := LibresRestants()
        Risque := if (Libres > 0, P := Floor[PiegesRestants() * 100.0 / (Libres * 1.0) + 0.5]) then P else 0
        for (I -> Chiffre : Chrono):
            set S += array{PlaceLibre(Chiffre, 0.5, 0.0, -20.0 + I * 40.0, 165.0)}
        set S += TexteEcrit("DANGER {Risque}%", 0.5, 0.0, 0.0, 215.0, 42.0)
        set S += TexteGauche("YOU ARE P{NumeroDe(J)}", 0.0, 0.0, 110.0, 50.0, 48.0)
        # les autres joueurs : leur numero et leurs cartes en DOS DE CARTE (on voit tout de suite qui en a combien)
        var Ligne : float = 125.0
        for (I -> X : Assis, X <> J, Contient(Vivants, X)?):
            set S += TexteGauche("P{I + 1}", 0.0, 0.0, 110.0, Ligne, 40.0)
            N := NombreDe(X)
            if (N = 0):
                set S += TexteGauche("NO CARD", 0.0, 0.0, 175.0, Ligne, 28.0)
            for (K := 0..N - 1):
                set S += DosCarte(0.0, 0.0, 195.0 + K * 42.0, Ligne, 46.0)
            set Ligne += 56.0
        S

    # comme Entete, mais le chrono et le DANGER sont sur le cote gauche (pendant qu'il clique sur la machine)
    EnteteGauche(J : player, Chrono : []texture_block) : []canvas_slot =
        var S : []canvas_slot = array{}
        Libres := LibresRestants()
        Risque := if (Libres > 0, P := Floor[PiegesRestants() * 100.0 / (Libres * 1.0) + 0.5]) then P else 0
        for (I -> Chiffre : Chrono):
            set S += array{PlaceLibre(Chiffre, 0.0, 0.5, 310.0 + I * 40.0, -130.0)}
        set S += TexteEcrit("DANGER {Risque}%", 0.0, 0.5, 330.0, -70.0, 42.0)
        set S += TexteGauche("YOU ARE P{NumeroDe(J)}", 0.0, 0.0, 110.0, 50.0, 48.0)
        S

    # sa main, en petit, en bas de l'ecran (non cliquable)
    # SA MAIN en bas de l'ecran, en eventail (non cliquable)
    PaquetEnBas(J : player) : []canvas_slot =
        Paquet : []int = if (M := Paquets[J]) then M else array{}
        for (I -> Id : Paquet):
            PlaceH(ImgH(ImageRelique(Id), 230.0, 230.0), 0.5, 1.0, (I * 1.0 - (Paquet.Length - 1) * 0.5) * 175.0, -125.0, 230.0, 230.0)

    # SA MAIN cliquable (codes 100 + place) ; la carte choisie reste grande et claire
    MainCliquable(J : player, Choisie : int) : []canvas_slot =
        var S : []canvas_slot = array{}
        Paquet : []int = if (M := Paquets[J]) then M else array{}
        for (I -> Id : Paquet):
            X := (I * 1.0 - (Paquet.Length - 1) * 0.5) * 175.0
            if (I = Choisie):
                set S += array{PlaceLibre(ImgH(ImageReliqueSurvol(Id), 280.0, 280.0), 0.5, 1.0, X, -160.0)}
            else:
                Img := ImgH(ImageRelique(Id), 230.0, 230.0)
                Zone := TEST1{}
                CM := carte_main{Ev := Choix, Fin := FinEcran, Code := 100 + I, Image := Img, Normale := ImageRelique(Id), Lueur := ImageReliqueSurvol(Id), Taille := 230.0, Zone := Zone, Son := SonBouton}
                spawn{ CM.Suivre() }
                set S += array{PlaceLibre(Img, 0.5, 1.0, X, -125.0), PlaceH(Zone, 0.5, 1.0, X, -125.0, 165.0, 220.0)}
        S

    # un TEXTE-BOUTON au pinceau (blanc + plus gros au survol)
    BoutonTexte(S : string, AX : float, AY : float, X : float, Y : float, Taille : float, Code : int) : []canvas_slot =
        BoutonTexteSur(Choix, S, AX, AY, X, Y, Taille, Code)

    BoutonTexteSur(Ev : event(int), S : string, AX : float, AY : float, X : float, Y : float, Taille : float, Code : int) : []canvas_slot =
        var Slots : []canvas_slot = array{}
        var Lettres : []texture_block = array{}
        var Normales : []texture = array{}
        var Claires : []texture = array{}
        # LE FOND CARTOON : rouge pour dire non (NO CARD, LIE, BACK), vert sinon ; toujours aux proportions 4:1
        Rouge := if (Code = 411 or Code = 401 or Code = 197 or Code = 198) then true else false
        FondN := if (Rouge?) then Boutons.Bouton_Rouge else Boutons.Bouton_Vert
        FondS := if (Rouge?) then Boutons.Bouton_Rouge_Survol else Boutons.Bouton_Vert_Survol
        HautB := Taille * 1.45
        LargB := HautB * 4.0
        # le texte tient dans le bouton (il est reduit s'il est trop long)
        Brut := LargeurTexte(S, Taille)
        T := if (Brut > LargB * 0.8) then Taille * LargB * 0.8 / Brut else Taille
        Fond := ImgH(FondN, LargB, HautB)
        # ORDRE D'AFFICHAGE FIXE : le fond derriere (0), les lettres devant (1), la zone de clic par-dessus (2)
        set Slots += array{PlaceZ(Fond, AX, AY, X, Y, 0)}
        Largeur := LargeurTexte(S, T)
        var Cx : float = X - Largeur * 0.5
        for (C : S):
            L := LargeurGlyphe(C) * T
            if (Gn := GlypheNormal(C)?, Gc := GlypheClair(C)?):
                Img := ImgH(Gn, T, T)
                set Lettres += array{Img}
                set Normales += array{Gn}
                set Claires += array{Gc}
                set Slots += array{PlaceZ(Img, AX, AY, Cx + L * 0.5, Y - T * 0.04, 1)}
            set Cx += L + T * 0.06
        Zone := TEST1{}
        BT := bouton_texte{Ev := Ev, Fin := FinEcran, Code := Code, Lettres := Lettres, Normales := Normales, Claires := Claires, Taille := T, Zone := Zone,
            Son := SonBouton, Fond := Fond, FondNormal := FondN, FondSurvol := FondS, LargFond := LargB, HautFond := HautB}
        spawn{ BT.Suivre() }
        Slots + array{canvas_slot{Widget := Zone, Anchors := anchors{Minimum := vector2{X := AX, Y := AY}, Maximum := vector2{X := AX, Y := AY}},
            Alignment := vector2{X := 0.5, Y := 0.5}, Offsets := margin{Left := X, Top := Y, Right := LargB, Bottom := HautB}, SizeToContent := false, ZOrder := 2}}

    Montrer(J : player, S : []canvas_slot, Chrono : []texture_block, Souris : logic) : void =
        # ecran a la souris (on ne peut plus tourner la tete) : il est d'abord tourne FACE A LA TABLE
        if (Souris?, not EnMachine[J]?, Vue := Orientations[J]):
            spawn{ FaceMachineApres(J, Vue, array{0.0, 0.15}) }
        if (IU := GetPlayerUI[J]):
            C := canvas{Slots := S}
            if (Souris?):
                IU.AddWidget(C, player_ui_slot{InputMode := ui_input_mode.All})
            else:
                IU.AddWidget(C)
            if (set Ecrans[J] = C, set Chronos[J] = Chrono) {}

    NouveauChrono() : []texture_block =
        set DernierChrono = -1
        array{ImgH(Ecriture.E_0, 64.0, 64.0), ImgH(Ecriture.E_0, 64.0, 64.0)}

    # LE CHOIX DES CARTES : les 6 cartes, leur effet ; on en prend 3 (clic = prise / rendue), puis CONFIRM
    ChoixDepart()<suspends> : void =
        FermerEcrans()
        var Liste : []choix_depart = array{}
        for (J : Assis, ALaTable(J)?):
            Chrono := NouveauChrono()
            Compteur := ImgH(Ecriture.E_0, 56.0, 56.0)
            EvJ := event(int){}
            var S : []canvas_slot = Entete(J, Chrono)
            set S += TexteEcrit("CHOOSE YOUR CARDS", 0.5, 0.0, 0.0, 300.0, 80.0)
            set S += array{PlaceLibre(Compteur, 0.5, 0.0, -30.0, 375.0)}
            set S += TexteEcrit("/3", 0.5, 0.0, 25.0, 375.0, 56.0)
            var Cartes : []carte_main = array{}
            Offre := TirerOffre()
            for (Place -> Id : Offre):
                X := (Place * 1.0 - 2.5) * 290.0
                Img := ImgH(ImageRelique(Id), 240.0, 240.0)
                Zone := TEST1{}
                CM := carte_main{Ev := EvJ, Fin := FinEcran, Code := 500 + Place, Image := Img, Normale := ImageRelique(Id), Lueur := ImageReliqueSurvol(Id), Taille := 240.0, Zone := Zone, Son := SonBouton}
                spawn{ CM.Suivre() }
                set Cartes += array{CM}
                set S += array{PlaceLibre(Img, 0.5, 0.5, X, 0.0), PlaceH(Zone, 0.5, 0.5, X, 0.0, 200.0, 240.0)}
                set S += TexteEcrit(NomRelique(Id), 0.5, 0.5, X, 160.0, 40.0)
                set S += TexteEcrit(DescriptionRelique(Id, 0), 0.5, 0.5, X, 205.0, 24.0)
                set S += TexteEcrit(DescriptionRelique(Id, 1), 0.5, 0.5, X, 235.0, 24.0)
            CD := choix_depart{Manager := Self, J := J, Cartes := Cartes, Compteur := Compteur, Ev := EvJ, Offre := Offre}
            set S += BoutonTexteSur(EvJ, "CONFIRM", 0.5, 1.0, 0.0, -110.0, 80.0, 599)
            Montrer(J, S, Chrono, true)
            spawn{ CD.Suivre(FinEcran) }
            set Liste += array{CD}
        Fin := GetSimulationElapsedTime() + DureeChoixDepart
        loop:
            Reste := Fin - GetSimulationElapsedTime()
            MajChronos(Reste)
            var Tous : logic = true
            for (CD : Liste, not CD.Confirme?):
                set Tous = false
            # ceux qui ont confirme voient combien de joueurs sont prets : WAITING FOR PLAYERS 1/3
            NbPrets := (for (CD : Liste, CD.Confirme?) do CD).Length
            for (CD : Liste, CD.Confirme?):
                AfficherLobby(CD.J, "WAITING FOR PLAYERS {NbPrets}/{Liste.Length}")
            if (Reste <= 0.0 or Tous?):
                break
            Sleep(0.25)
        for (CD : Liste):
            CD.Completer()
            if (set Paquets[CD.J] = CD.Main()) {}
            AfficherLobby(CD.J, "")
        FermerEcrans()

    # LES REGLES, au debut de la manche, pour tout le monde
    EcranRegles() : void =
        FermerEcrans()
        for (J : Assis, ALaTable(J)?):
            Chrono := NouveauChrono()
            var S : []canvas_slot = array{PlaceH(color_block{DefaultColor := color{R := 0.0, G := 0.0, B := 0.0}, DefaultOpacity := 0.75}, 0.5, 0.5, 0.0, 0.0, 3000.0, 2000.0)}
            set S += TexteEcrit("HOW TO PLAY", 0.5, 0.5, 0.0, -260.0, 100.0)
            set S += TexteEcrit("EACH TURN: PLAY A CARD TO HELP YOU", 0.5, 0.5, 0.0, -110.0, 56.0)
            set S += TexteEcrit("OR TO TRAP THE OTHERS", 0.5, 0.5, 0.0, -20.0, 56.0)
            set S += TexteEcrit("THEN PRESS A BUTTON ON THE MACHINE...", 0.5, 0.5, 0.0, 70.0, 56.0)
            set S += TexteEcrit("AND PRAY.", 0.5, 0.5, 0.0, 170.0, 80.0)
            Montrer(J, S, Chrono, false)

    # SON CHOIX : deux gros mots, PLAY A CARD / NO CARD (et les boutons qui l'attendent, s'il y en a)
    EcranAction(Actif : player, Attente : int, PeutJouer : logic, PeutPiocher : logic) : void =
        FermerEcrans()
        for (J : Assis, ALaTable(J)?):
            Chrono := NouveauChrono()
            var S : []canvas_slot = Entete(J, Chrono)
            if (J = Actif):
                set S += TexteEcrit("YOUR TURN", 0.5, 0.0, 0.0, 300.0, 100.0)
                if (Attente > 0):
                    set S += TexteEcrit("+{Attente} BUTTONS FOR YOU - PLAY A JAM TO PASS IT ON!", 0.5, 0.0, 0.0, 380.0, 40.0)
                if (PeutJouer?):
                    set S += BoutonTexte("PLAY A CARD", 0.5, 0.5, if (PeutPiocher?) then -300.0 else 0.0, 20.0, 80.0, 410)
                if (PeutPiocher?):
                    set S += BoutonTexte("NO CARD", 0.5, 0.5, if (PeutJouer?) then 300.0 else 0.0, 20.0, 80.0, 411)
                set S += PaquetEnBas(J)
                Montrer(J, S, Chrono, true)
            else:
                set S += TexteEcrit("P{NumeroDe(Actif)} IS THINKING...", 0.5, 0.0, 0.0, 300.0, 54.0)
                set S += PaquetEnBas(J)
                Montrer(J, S, Chrono, false)

    # JOUER : ses cartes en grand en bas. Une carte choisie -> TRUTH / LIE au-dessus. LIE -> les autres cartes.
    EcranJouer(Actif : player, Choisie : int, Mensonge : logic) : void =
        FermerEcrans()
        for (J : Assis, ALaTable(J)?):
            Chrono := NouveauChrono()
            var S : []canvas_slot = Entete(J, Chrono)
            if (J = Actif):
                Paquet : []int = if (M := Paquets[J]) then M else array{}
                Reelle := if (R := Paquet[Choisie]) then R else -1
                XChoisie := (Choisie * 1.0 - (Paquet.Length - 1) * 0.5) * 175.0
                if (Choisie < 0):
                    set S += TexteEcrit("CHOOSE A CARD", 0.5, 0.0, 0.0, 300.0, 100.0)
                else if (not Mensonge?):
                    set S += TexteEcrit("TRUTH OR LIE?", 0.5, 0.0, 0.0, 300.0, 100.0)
                    set S += BoutonTexte("TRUTH", 0.5, 1.0, XChoisie - 170.0, -360.0, 52.0, 400)
                    set S += BoutonTexte("LIE", 0.5, 1.0, XChoisie + 170.0, -360.0, 52.0, 401)
                else:
                    set S += TexteEcrit("SAY IT IS...", 0.5, 0.0, 0.0, 300.0, 100.0)
                    var N : int = 0
                    for (Id := 0..5, Id <> Reelle):
                        X := (N * 1.0 - 2.0) * 200.0
                        Img := ImgH(ImageRelique(Id), 210.0, 210.0)
                        Zone := TEST1{}
                        CM := carte_main{Ev := Choix, Fin := FinEcran, Code := 300 + Id, Image := Img, Normale := ImageRelique(Id), Lueur := ImageReliqueSurvol(Id), Taille := 210.0, Zone := Zone, Son := SonBouton}
                        spawn{ CM.Suivre() }
                        set S += array{PlaceLibre(Img, 0.5, 0.5, X, -20.0), PlaceH(Zone, 0.5, 0.5, X, -20.0, 150.0, 200.0)}
                        set N += 1
                    set S += BoutonTexte("BACK", 0.5, 1.0, 600.0, -230.0, 56.0, 198)
                if (Choisie < 0):
                    set S += BoutonTexte("BACK", 0.5, 1.0, 600.0, -130.0, 56.0, 197)
                set S += MainCliquable(J, Choisie)
                Montrer(J, S, Chrono, true)
            else:
                set S += TexteEcrit("P{NumeroDe(Actif)} IS CHOOSING A CARD...", 0.5, 0.0, 0.0, 260.0, 54.0)
                set S += PaquetEnBas(J)
                Montrer(J, S, Chrono, false)

    # L'ANNONCE : sa carte FACE CACHEE au centre, et ce qu'il dit qu'elle est. Les autres CLIQUENT pour LIAR!
    # A LA MACHINE : pas de curseur, il vise avec la camera. PEEK : le bouton sur, sur SON ecran seulement.
    EcranVisee(Actif : player, Requis : int, Vu : int, Souris : logic) : void =
        FermerEcrans()
        for (J : Assis, ALaTable(J)?):
            Chrono := NouveauChrono()
            var S : []canvas_slot = Entete(J, Chrono)
            if (J = Actif, Souris?):
                # le clavier de la machine occupe le milieu de l'ecran : tout est sur le cote gauche
                var G : []canvas_slot = EnteteGauche(J, Chrono)
                set G += TexteEcrit("CLICK A BUTTON", 0.0, 0.5, 330.0, 20.0, 46.0)
                set G += TexteEcrit("{Requis} TO PRESS", 0.0, 0.5, 330.0, 75.0, 46.0)
                if (Vu >= 0):
                    set G += TexteEcrit("GREEN = SAFE", 0.0, 0.5, 330.0, 135.0, 40.0)
                Montrer(J, G, Chrono, true)
            else if (J = Actif):
                set S += TexteEcrit("AIM AT A BUTTON AND CLICK - {Requis} TO PRESS", 0.5, 0.0, 0.0, 280.0, 46.0)
                if (Vu >= 0):
                    set S += TexteEcrit("THE GREEN BUTTON IS SAFE", 0.5, 0.0, 0.0, 335.0, 42.0)
                set S += PaquetEnBas(J)
                Montrer(J, S, Chrono, false)
            else:
                set S += TexteEcrit("P{NumeroDe(Actif)} IS CHOOSING A BUTTON...", 0.5, 0.0, 0.0, 280.0, 46.0)
                set S += PaquetEnBas(J)
                Montrer(J, S, Chrono, false)

    # message en haut de l'ecran pour tout le monde ("" = efface)
    Bandeau(S : string) : void =
        for (J : Table):
            MessagePour(J, S)

    Avertir(J : player, S : string) : void =
        spawn{ MessageBref(J, S) }

    MessageBref(J : player, S : string)<suspends> : void =
        MessagePour(J, S)
        Sleep(2.5)
        MessagePour(J, "")

    # le message du haut, ecrit au pinceau (remplace le precedent ; "" = efface)
    MessagePour(J : player, S : string) : void =
        if (IU := GetPlayerUI[J]):
            if (Ancien := Bandeaux[J]):
                IU.RemoveWidget(Ancien)
            C := canvas{Slots := if (EnMachine[J]?) then TexteEcrit(S, 0.0, 0.5, 330.0, 220.0, 30.0) else TexteEcrit(S, 0.5, 0.0, 0.0, 90.0, 46.0)}
            IU.AddWidget(C)
            if (set Bandeaux[J] = C) {}
