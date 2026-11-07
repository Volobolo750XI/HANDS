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
using { /Fortnite.com/Animation/PlayAnimation }
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
#  5 STEAL   : tu regardes un joueur et tu cliques : tu lui voles une carte au hasard
#  Images : dossier Reliques (Relique_Bouclier, _Serrure, _Sablier, _Chaine, _Etau, _Corbeau) + les versions _Lueur (plus claires)
NomRelique(Id : int) : string =
    if (Id = 0) then "DEFUSE" else if (Id = 1) then "PEEK" else if (Id = 2) then "PASS" else if (Id = 3) then "REVERSE" else if (Id = 4) then "JAM" else "STEAL"

# ce que fait la carte, en 2 lignes courtes (ecran du choix des cartes)
DescriptionRelique(Id : int, Ligne : int) : string =
    if (Id = 0) then (if (Ligne = 0) then "SAVES YOU FROM" else "ONE TRAP")
    else if (Id = 1) then (if (Ligne = 0) then "SHOWS YOU ONE" else "SAFE BUTTON")
    else if (Id = 2) then (if (Ligne = 0) then "NO PRESS FOR YOU" else "THIS TURN")
    else if (Id = 3) then (if (Ligne = 0) then "THE MACHINE TURNS" else "THE OTHER WAY")
    else if (Id = 4) then (if (Ligne = 0) then "NEXT PLAYER" else "PRESSES +1")
    else (if (Ligne = 0) then "TAKE A CARD" else "FROM A PLAYER")

# RARETE (sur 100) : DEFUSE et PASS sont rares, JAM et REVERSE courantes
PoidsRelique(Id : int)<transacts> : int =
    if (Id = 0) then 8 else if (Id = 1) then 16 else if (Id = 2) then 8 else if (Id = 3) then 22 else if (Id = 4) then 30 else 16

TirerReliquePonderee()<transacts> : int =
    var Tirage : int = GetRandomInt(1, 100)
    var Choisie : int = 5
    var Trouve : logic = false
    for (Id := 0..5, not Trouve?):
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
    else if (Id = 3) then Reliques.Relique_Chaine else if (Id = 4) then Reliques.Relique_Etau else Reliques.Relique_Corbeau

ImageReliqueSurvol(Id : int) : texture =
    if (Id = 0) then Reliques.Relique_Bouclier_Lueur else if (Id = 1) then Reliques.Relique_Serrure_Lueur else if (Id = 2) then Reliques.Relique_Sablier_Lueur
    else if (Id = 3) then Reliques.Relique_Chaine_Lueur else if (Id = 4) then Reliques.Relique_Etau_Lueur else Reliques.Relique_Corbeau_Lueur

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

    Suivre()<suspends> : void =
        race:
            Fin.Await()
            loop:
                Zone.Clic.Await()
                Ev.Signal(Code)
            loop:
                Zone.Entre.Await()
                for (I -> Img : Lettres, T := Claires[I]):
                    Img.SetImage(T)
                    Img.SetDesiredSize(vector2{X := Taille * 1.18, Y := Taille * 1.18})
                Zone.Sort.Await()
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

    Suivre()<suspends> : void =
        race:
            Fin.Await()
            loop:
                Zone.Clic.Await()
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
                            Manager.Avertir(J, "WAITING FOR THE OTHERS...")
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
    # Une place par joueur autour de la table (accessoires invisibles poses devant chaque chaise)
    @editable Places : []creative_prop = array{}
    # Une CHAISE (appareil Chaise / Chair) par place, MEME ORDRE que Places. Vide = joueurs figes sur place.
    @editable Chaises : []chair_device = array{}
    # FACULTATIF : une camera fixe par place, MEME ORDRE, posee devant la bouche de la machine et qui regarde
    # le clavier (la machine est tournee vers cette place pendant son tour). Vide = la camera du joueur.
    @editable CamerasClavier : []gameplay_camera_fixed_point_device = array{}
    # Avec une camera fixe : on clique A LA SOURIS. Ou est le clavier A L'ECRAN (vu par la camera), en fractions
    # de l'ecran (0 = gauche / haut, 1 = droite / bas). 7 valeurs = les 7 lignes qui separent les 6 rangees de
    # boutons, de haut en bas : hauteur de la ligne, bord gauche et bord droit du clavier a cette hauteur.
    # (valeurs mesurees sur ta capture d'ecran ; a retoucher seulement si la camera bouge)
    @editable LignesY : []float = array{0.1084, 0.2018, 0.3129, 0.4356, 0.5707, 0.7262, 0.8889}
    @editable BordGauche : []float = array{0.4, 0.396, 0.39, 0.384, 0.376, 0.3675, 0.358}
    @editable BordDroit : []float = array{0.634, 0.638, 0.644, 0.65, 0.657, 0.665, 0.674}
    # quel bouton (Bouton_01...) est ou a l'ecran : si le bouton qui devient blanc n'est pas celui sous la
    # souris, coche / decoche ces cases
    @editable InverserColonnes : logic = false
    @editable InverserLignes : logic = false
    # La machine : le centre (Corps), la machoire du haut (Gueule) et les 24 boutons DANS L'ORDRE Bouton_01..Bouton_24
    @editable Centre : creative_prop = creative_prop{}
    @editable Gueule : creative_prop = creative_prop{}
    @editable Touches : []creative_prop = array{}
    @editable Plaque : creative_prop = creative_prop{}
    # LE CLAVIER CACHE : une 2e machine (copie) posee LOIN, qui ne tourne jamais, avec la camera fixe devant.
    # C'est sur elle qu'on clique : son personnage ne peut pas gener, et la camera ne bouge jamais.
    # Ses 24 boutons DANS L'ORDRE Bouton_01..Bouton_24, et (facultatif) sa machoire pour voir la feinte de pres.
    # Vide = on clique sur la machine de la table, comme avant.
    @editable TouchesClavier : []creative_prop = array{}
    @editable GueuleClavier : []creative_prop = array{}
    # COULEURS DES BOUTONS : 3 materiaux dans un dossier Teintes du Tiroir a contenu :
    #   T_Base (l'aspect normal d'un bouton), T_Clair (le bouton vise, blanc), T_Sur (le bouton sur du PEEK, vert)
    # Numero de l'emplacement de materiau du bouton (0 en general)
    @editable IndexMateriau : int = 0
    # CLIC : un Declencheur d'entree (Input Trigger) regle sur l'action "Tir" (clic gauche / gachette).
    # Sert a appuyer sur le bouton vise, a crier LIAR! et a choisir la victime d'un STEAL.
    @editable ToucheClic : input_trigger_device = input_trigger_device{}
    # LA TABLE VUE DU DESSUS : un 2e Declencheur d'entree (une touche au choix). Appuyer = la table s'affiche 5 s
    # (la machine au milieu, chaque joueur a sa place avec ses cartes en dos de carte, et a qui c'est le tour).
    @editable ToucheVue : input_trigger_device = input_trigger_device{}
    # Distance max (cm) entre le regard et le centre d'un bouton pour qu'il soit vise
    @editable PorteeVisee : float = 12.0
    # Son de rotation (Audio Player en BOUCLE, lecture automatique NON) : il joue tant que la machine tourne
    @editable SonRotation : audio_player_device = audio_player_device{}
    # Son "CLAC" quand la machine s'arrete sur un joueur (Audio Player : lecture automatique NON)
    @editable SonArret : audio_player_device = audio_player_device{}
    # Direction (degres, vue du dessus dans UEFN) vers laquelle la gueule regarde au depart. Ajuste si elle
    # ne fait pas face au bon joueur (ex. 90, 180, -90).
    @editable FaceDepart : float = 0.0
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
    # Animation "se pencher et appuyer" (Mixamo -> squelette Fortnite). Vide = pas d'animation.
    @editable AnimAppui : ?animation_sequence = false
    # l'animation d'appui s'ARRETE (reste figee) sur cette image le temps que le bouton reagisse (feinte ou
    # morsure), puis elle reprend jusqu'a la fin. ImagesParSecondeAppui : 30 pour une animation Mixamo.
    @editable ImageArretAppui : float = 210.0
    @editable ImagesParSecondeAppui : float = 30.0
    # A SA PLACE : le joueur est pose PILE sur sa Place (debout), tourne vers la machine, fige, a la PREMIERE
    # PERSONNE. La vraie chaise ne sert que si Fortnite refuse la teleportation (elle force la 3e personne).
    # Pour le caler : AvanceAssis = cm vers la table (negatif = en arriere), HauteurAssis = cm vers le haut.
    @editable AvanceAssis : float = 0.0
    @editable HauteurAssis : float = 0.0
    # decoche pour essayer de garder le CORPS immobile (si la tete ne bouge plus du tout, recoche-la)
    @editable CorpsTourne : logic = true
    # LA TETE : de combien de degres on peut tourner la tete a droite / a gauche depuis la machine
    @editable TeteMaxDroite : float = 60.0
    @editable TeteMaxGauche : float = 60.0
    # Reglages
    @editable JoueursMinimum : int = 2
    # TEST : true = on peut jouer TOUT SEUL (la manche dure jusqu'a ce que tu tombes sur un piege ;
    # entre deux tours, la machine fait un tour complet et revient sur toi). Decoche avant de publier.
    @editable TestSolo : logic = false
    @editable PiegesParGrille : int = 2
    @editable DureeTour : float = 25.0           # temps pour appuyer (le choix de la carte et l'annonce en plus)
    @editable DureeChoixDepart : float = 30.0    # debut de manche : temps pour choisir ses 3 cartes
    @editable DureeChoixCarte : float = 25.0     # temps pour choisir la carte a jouer et ce qu'on annonce
    @editable AngleFermeture : float = 60.0      # degres pour fermer COMPLETEMENT la machoire
    @editable AxeFermeture : int = 1             # 0 = X, 1 = Y, 2 = Z (change si elle tourne dans le mauvais sens)
    @editable Enfoncement : float = 2.0          # cm : un bouton appuye descend de ca
    Colonnes : int = 4
    PaquetMax : int = 3

    # codes des clics sur les cartes de l'ecran : 100 + Id = annoncer la carte Id, 199 = pas de carte
    Choix : event(int) = event(int){}
    # un clic (action Tir) d'un joueur
    ClicJoueur : event(agent) = event(agent){}
    FinEcran : event() = event(){}
    var EnMachine : [player]logic = map{}          # il clique sur la machine (camera fixe) : ses textes sont a gauche
    var Orientations : [player]float = map{}       # direction (degres) de la machine vue de sa place : la tete est limitee autour
    var SurVraieChaise : [player]logic = map{}     # teleportation refusee : assis sur la vraie chaise
    var BaseTouches : []transform = array{}
    var BaseTouchesClavier : []transform = array{}
    var BasesGueuleClavier : []transform = array{}
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
        set BaseTouchesClavier = for (T : TouchesClavier) do T.GetTransform()
        set BasesGueuleClavier = for (G : GueuleClavier) do G.GetTransform()
        set BaseGueule = Gueule.GetTransform()
        set BaseCentre = Centre.GetTransform()
        set BasePlaque = Plaque.GetTransform()
        set Enfoncee = for (T : Touches) do false
        set Piegee = for (T : Touches) do false
        ToucheClic.PressedEvent.Subscribe(QuandClic)
        ToucheVue.PressedEvent.Subscribe(QuandVue)
        spawn{ LimiterTetes() }
        EnleverCameras()
        loop:
            Presents := GetPlayspace().GetPlayers()
            Requis := if (TestSolo?) then 1 else Max(2, JoueursMinimum)
            if (Presents.Length >= Requis):
                Manche()
                Sleep(6.0)
            else:
                Bandeau("WAITING FOR PLAYERS {Presents.Length}/{Requis}")
                Sleep(1.0)

    # LA camera fixe d'un joueur : celle qui est posee le plus pres de SA place (l'ordre de la liste ne compte pas)
    CameraDe(J : player)<transacts> : ?gameplay_camera_fixed_point_device =
        var Meilleure : ?gameplay_camera_fixed_point_device = false
        if (Pl := Places[NumeroDe(J) - 1]):
            Ici := Pl.GetTransform().Translation
            var PlusPres : float = 100000000.0
            for (Cam : CamerasClavier):
                V := Cam.GetTransform().Translation - Ici
                D := DotProduct(V, V)
                if (D < PlusPres):
                    set PlusPres = D
                    set Meilleure = option{Cam}
        Meilleure

    # aucune camera fixe sur personne (au demarrage et a chaque manche) : on ne la voit que pendant son tour
    EnleverCameras() : void =
        for (Cam : CamerasClavier, J : GetPlayspace().GetPlayers()):
            Cam.RemoveFrom(J)

    # LA TETE : si un joueur a sa place tourne trop a droite / a gauche, il est remis a la limite
    LimiterTetes()<suspends> : void =
        loop:
            Sleep(0.1)
            for (J -> Cible : Orientations, Perso := J.GetFortCharacter[], Perso.IsActive[]):
                F := Perso.GetViewRotation().GetLocalForward()
                Yaw := ArcTan(F.Y, F.X) * 180.0 / PiFloat
                Ecart := AngleCourt(Yaw - Cible)
                Borne := if (Ecart > TeteMaxDroite) then TeteMaxDroite else if (Ecart < -TeteMaxGauche) then -TeteMaxGauche else Ecart
                if (Borne <> Ecart):
                    if (Perso.TeleportTo[Perso.GetTransform().Translation, MakeRotationFromYawPitchRollDegrees(Cible + Borne, 0.0, 0.0)]) {}

    AngleCourt(A0 : float)<transacts> : float =
        var A : float = A0
        for (K := 1..4):
            if (A > 180.0):
                set A -= 360.0
            else if (A < -180.0):
                set A += 360.0
        A

    QuandClic(Agent : agent) : void =
        ClicJoueur.Signal(Agent)

    # LA TABLE VUE DU DESSUS (touche ToucheVue) : affichee 5 s ; appuyer encore la cache
    var Vues : [player]canvas = map{}
    QuandVue(Agent : agent) : void =
        if (J := player[Agent], UI := GetPlayerUI[J]):
            if (Ancienne := Vues[J]):
                UI.RemoveWidget(Ancienne)
                OterVue(J)
            else if (Contient(Assis, J)?):
                V := DessinerVue(J)
                UI.AddWidget(V)
                if (set Vues[J] = V) {}
                spawn{ CacherVue(J, V) }

    OterVue(J : player) : void =
        var Reste : [player]canvas = map{}
        for (X -> W : Vues, X <> J):
            if (set Reste[X] = W) {}
        set Vues = Reste

    CacherVue(J : player, V : canvas)<suspends> : void =
        Sleep(5.0)
        if (Actuelle := Vues[J], Actuelle = V, UI := GetPlayerUI[J]):
            UI.RemoveWidget(V)
            OterVue(J)

    # la table vue du dessus, TOI en bas : la machine au milieu, chaque joueur a sa vraie place autour
    DessinerVue(J : player) : canvas =
        var S : []canvas_slot = array{PlaceH(color_block{DefaultColor := color{R := 0.0, G := 0.0, B := 0.0}, DefaultOpacity := 0.82}, 0.5, 0.5, 0.0, 0.0, 820.0, 820.0)}
        C := BaseCentre.Translation
        if (PlMoi := Places[NumeroDe(J) - 1]):
            Moi := PlMoi.GetTransform().Translation
            L0 := Max(1.0, Sqrt((C.X - Moi.X) * (C.X - Moi.X) + (C.Y - Moi.Y) * (C.Y - Moi.Y)))
            # vers l'avant (de moi vers la machine) = le HAUT de l'ecran ; ma droite = la droite de l'ecran
            FX := (C.X - Moi.X) / L0
            FY := (C.Y - Moi.Y) / L0
            set S += TexteEcrit("THE MACHINE", 0.5, 0.5, 0.0, 0.0, 38.0)
            for (I -> X : Assis, Pl := Places[I]):
                P := Pl.GetTransform().Translation
                RX := P.X - C.X
                RY := P.Y - C.Y
                L := Max(1.0, Sqrt(RX * RX + RY * RY))
                SX := (RX * (-FY) + RY * FX) / L * 280.0
                SY := -(RX * FX + RY * FY) / L * 280.0
                Nom := if (X = J) then "YOU" else "P{I + 1}"
                set S += TexteEcrit(Nom, 0.5, 0.5, SX, SY - 55.0, 44.0)
                if (I = DernierTourne):
                    set S += TexteEcrit("HIS TURN", 0.5, 0.5, SX, SY - 100.0, 30.0)
                if (not Contient(Vivants, X)?):
                    set S += TexteEcrit("OUT", 0.5, 0.5, SX, SY + 10.0, 40.0)
                else:
                    N := NombreDe(X)
                    if (N = 0):
                        set S += TexteEcrit("NO CARD", 0.5, 0.5, SX, SY + 10.0, 28.0)
                    for (K := 0..N - 1):
                        set S += DosCarte(0.5, 0.5, SX + (K * 1.0 - (N - 1) * 0.5) * 44.0, SY + 15.0, 50.0)
        canvas{Slots := S}

    # =========================================================================
    #  UNE MANCHE
    # =========================================================================
    Manche()<suspends> : void =
        var Liste : []player = array{}
        for (J : GetPlayspace().GetPlayers()):
            if (Liste.Length < Places.Length):
                set Liste += array{J}
        set Assis = Liste
        set Vivants = Liste
        EnleverCameras()
        set Paquets = map{}
        set Penalites = map{}
        set DefiEnCours = false
        set Sens = 1
        set Bloque = 0
        for (I -> J : Liste):
            Asseoir(J, I)
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
                    if (Sens < 0):
                        set Index -= 1
                else:
                    set Index += Sens
        # fin de manche
        FermerEcrans()
        if (G := Vivants[0], not TestSolo?):
            Bandeau("P{NumeroDe(G)} WINS THE ROUND!")
        else:
            Bandeau(if (TestSolo?) then "GAME OVER - THE TRAP GOT YOU" else "NO WINNER")
        Sleep(4.0)
        Bandeau("")
        set Orientations = map{}
        set SurVraieChaise = map{}
        for (J : Assis, Perso := J.GetFortCharacter[]):
            Perso.ReleaseFromStasis()

    # le joueur va a sa place (debout, ou assis avec l'animation), tourne vers la machine, fige, a la premiere personne
    Asseoir(J : player, I : int) : void =
        if (Pl := Places[I], Perso := J.GetFortCharacter[]):
            Ici := Pl.GetTransform().Translation
            C := Centre.GetTransform().Translation
            LacetRad := ArcTan(C.Y - Ici.Y, C.X - Ici.X)
            Lacet := LacetRad * 180.0 / PiFloat
            Avant := vector3{X := Cos(LacetRad), Y := Sin(LacetRad), Z := 0.0}
            Pose := Ici + Avant * AvanceAssis + vector3{X := 0.0, Y := 0.0, Z := HauteurAssis}
            Rot := MakeRotationFromYawPitchRollDegrees(Lacet, 0.0, 0.0)
            # Fortnite REFUSE la teleportation si le joueur ne rentre pas a cet endroit : on essaie plus haut, puis devant
            Resultat := PoserPres(Perso, Pose, Avant, Rot)
            Exact := if (Resultat = 0) then true else false
            if (TestSolo?):
                Avertir(J, if (Resultat = 0) then "SEAT: ON YOUR PLACE" else if (Resultat = 1) then "SEAT: SOMETHING IN THE WAY - DROPPED FROM ABOVE" else if (Resultat = 2) then "SEAT: SOMETHING IN THE WAY - IN FRONT" else "SEAT: TELEPORT REFUSED - MOVE YOUR PLACE")
            if (Resultat >= 0):
                if (set Orientations[J] = Lacet) {}
                Perso.PutInStasis(stasis_args{AllowTurning := CorpsTourne, AllowFalling := if (Exact?) then false else true, AllowEmotes := false})
            else if (Ch := Chaises[I]):
                # teleportation refusee partout : pas fige au point d'apparition, il est assis sur la vraie chaise
                if (set SurVraieChaise[J] = true) {}
                Ch.Enable()
                Ch.Seat(J)

    # teleporte le joueur a Pose ; si Fortnite refuse (il ne rentre pas : chaise, mur...), plus haut, puis devant.
    # 0 = pile a Pose, 1 = au-dessus (il tombe), 2 = devant, -1 = refuse partout (il reste ou il est)
    PoserPres(Perso : fort_character, Pose : vector3, Avant : vector3, Rot : rotation) : int =
        var Resultat : int = -1
        if (Perso.TeleportTo[Pose, Rot]):
            set Resultat = 0
        for (H : array{40.0, 80.0, 130.0, 200.0}, Resultat < 0):
            if (Perso.TeleportTo[Pose + vector3{X := 0.0, Y := 0.0, Z := H}, Rot]):
                set Resultat = 1
        for (D : array{60.0, 120.0}, Resultat < 0):
            if (Perso.TeleportTo[Pose + Avant * D + vector3{X := 0.0, Y := 0.0, Z := 40.0}, Rot]):
                set Resultat = 2
        Resultat

    # un joueur qui s'est leve de sa chaise y est remis (la chaise ne fait rien s'il est deja assis)
    Rasseoir() : void =
        for (I -> J : Assis, SurVraieChaise[J]?, Contient(Vivants, J)?, Ch := Chaises[I]):
            Ch.Seat(J)

    TirerRelique()<transacts> : int = GetRandomInt(0, 5)

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
        for (K -> T : TouchesClavier, B := BaseTouchesClavier[K]):
            spawn{ Bouger(T, B, 0.25) }

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
        I := NumeroDe(J) - 1
        if (Pl := Places[I]):
            Ici := Pl.GetTransform().Translation
            C := BaseCentre.Translation
            Cible := ArcTan(Ici.Y - C.Y, Ici.X - C.X) * 180.0 / PiFloat - FaceDepart
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
                # pas de 15 degres (8 pour la roulette) : moins d'ordres de deplacement qu'avant (8 degres)
                # = les boutons restent mieux colles a la machine, sans qu'elle se deforme entre deux pas
                Pas := if (N := Ceil[Abs(Ecart) / (if (Tours > 0) then 8.0 else 15.0)]) then Max(1, N) else 1
                Dt := Duree / (Pas * 1.0)
                Depart := LacetMachine
                SonRotation.Play()
                for (K := 1..Pas):
                    Frac := (K * 1.0) / (Pas * 1.0)
                    # vitesse constante, et elle s'arrete d'un coup (roulette comprise)
                    L := Depart + Ecart * Frac
                    spawn{ Bouger(Centre, Tournee(BaseCentre, L), Dt) }
                    spawn{ Bouger(Plaque, Tournee(BasePlaque, L), Dt) }
                    spawn{ Bouger(Gueule, Tournee(BaseGueule, L), Dt) }
                    for (N2 -> T : Touches, B := BaseTouches[N2]):
                        Pose := Tournee(B, L)
                        Bas := if (Enfoncee[N2]?) then Enfoncement else 0.0
                        spawn{ Bouger(T, transform{Translation := Pose.Translation - vector3{X := 0.0, Y := 0.0, Z := Bas}, Rotation := Pose.Rotation, Scale := Pose.Scale}, Dt) }
                    Sleep(Dt)
                set LacetMachine = Depart + Ecart
                SonRotation.Stop()
                SonArret.Play()

    # +1 / -1 : le sens dans lequel la machine tourne pour aller au joueur SUIVANT (selon la position des Places
    # autour de la table), inverse par REVERSE
    SensRotation()<transacts> : float =
        var Naturel : float = 1.0
        if (P0 := Places[0], P1 := Places[1]):
            C := BaseCentre.Translation
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

    # =========================================================================
    #  LA VISEE : le bouton (libre) le plus proche du regard du joueur, ou -1
    # =========================================================================
    BoutonVise(J : player) : int =
        var Meilleur : int = -1
        if (Perso := J.GetFortCharacter[]):
            Oeil := Perso.GetViewLocation()
            Regard := Perso.GetViewRotation().GetLocalForward()
            var PlusPres : float = PorteeVisee
            for (K -> T : Touches, not Enfoncee[K]?):
                P := T.GetTransform().Translation
                V := P - Oeil
                Avance := DotProduct(V, Regard)
                if (Avance > 0.0):
                    # distance entre le centre du bouton et la ligne du regard
                    Ecart := (V - Regard * Avance).Length()
                    if (Ecart < PlusPres):
                        set PlusPres = Ecart
                        set Meilleur = K
        Meilleur

    # le joueur (encore en jeu, autre que J) que J regarde le plus, ou rien
    JoueurVise(J : player) : ?player =
        var Meilleur : ?player = false
        if (Perso := J.GetFortCharacter[]):
            Oeil := Perso.GetViewLocation()
            Regard := Perso.GetViewRotation().GetLocalForward()
            var MeilleurCos : float = 0.85
            for (X : Vivants, X <> J, NombreDe(X) > 0, PX := X.GetFortCharacter[]):
                V := PX.GetTransform().Translation + vector3{X := 0.0, Y := 0.0, Z := 120.0} - Oeil
                Lg := V.Length()
                if (Lg > 1.0):
                    Cosinus := DotProduct(V, Regard) / Lg
                    if (Cosinus > MeilleurCos):
                        set MeilleurCos = Cosinus
                        set Meilleur = option{X}
        Meilleur

    # le bouton K prend son materiau : blanc s'il est vise, vert si c'est le bouton sur du PEEK, normal sinon
    Peindre(K : int) : void =
        if (T := Touches[K]):
            PeindreProp(T, K)
        if (T := TouchesClavier[K]):
            PeindreProp(T, K)

    PeindreProp(T : creative_prop, K : int) : void =
        if (K = BoutonBlanc):
            T.SetMaterial(Teintes.T_Clair{}, ?Index := IndexMateriau)
        else if (K = BoutonVert):
            T.SetMaterial(Teintes.T_Sur{}, ?Index := IndexMateriau)
        else:
            T.SetMaterial(Teintes.T_Base{}, ?Index := IndexMateriau)

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
        Rasseoir()
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
                else if (Id = 5):
                    Voler(J)

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
                    # le geste reprend la ou il etait fige, jusqu'a la fin (il retire sa main)
                    ReprendreAppui(J)
            if (Camera := CameraDe(J)?):
                Camera.RemoveFrom(J)
            if (set EnMachine[J] = false) {}
        Surligner(-1)
        Verdir(-1)
        FermerEcrans()
        Elimine

    # il vise avec la camera : le bouton vise devient blanc ; un clic l'enfonce. Temps ecoule : bouton au hasard.
    ViserEtCliquer(J : player, Requis : int, Vu : int, Fin : float)<suspends> : int =
        if (Camera := CameraDe(J)?):
            return CliquerALaSouris(J, Requis, Vu, Fin)
        EcranVisee(J, Requis, Vu, false)
        var Choisi : int = -2
        var Vise : int = -1
        loop:
            Reste := Fin - GetSimulationElapsedTime()
            MajChronos(Reste)
            if (Reste <= 0.0):
                set Choisi = BoutonLibre()
                break
            K := BoutonVise(J)
            if (K <> Vise):
                set Vise = K
                Surligner(K)
            var Clic : logic = false
            race:
                Sleep(0.05)
                loop:
                    A := ClicJoueur.Await()
                    if (player[A] = J):
                        set Clic = true
                        break
            if (Clic?, Vise >= 0):
                set Choisi = Vise
                break
        Surligner(-1)
        Choisi

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

    # STEAL : il regarde un joueur (son nom s'affiche) et clique. Temps ecoule : un joueur au hasard.
    Voler(J : player)<suspends> : void =
        Victimes := for (X : Vivants, X <> J, NombreDe(X) > 0) do X
        if (Victimes.Length = 0):
            Avertir(J, "NOBODY HAS A CARD TO STEAL")
            return
        # un ecran : il CLIQUE sur le joueur a voler (10 s, sinon un joueur au hasard)
        FermerEcrans()
        for (X : Assis, EstLa(X)?):
            Chrono := NouveauChrono()
            var S : []canvas_slot = Entete(X, Chrono)
            if (X = J):
                set S += TexteEcrit("STEAL A CARD FROM...", 0.5, 0.0, 0.0, 300.0, 90.0)
                for (N -> V : Victimes):
                    Y := (N * 1.0 - (Victimes.Length - 1) * 0.5) * 120.0
                    set S += BoutonTexte("P{NumeroDe(V)} ({NombreDe(V)} CARDS)", 0.5, 0.5, 0.0, Y, 70.0, 700 + N)
                set S += PaquetEnBas(X)
                Montrer(X, S, Chrono, true)
            else:
                set S += TexteEcrit("P{NumeroDe(J)} IS STEALING A CARD...", 0.5, 0.0, 0.0, 300.0, 54.0)
                set S += PaquetEnBas(X)
                Montrer(X, S, Chrono, false)
        var Cible : ?player = false
        Fin := GetSimulationElapsedTime() + 10.0
        loop:
            Reste := Fin - GetSimulationElapsedTime()
            MajChronos(Reste)
            if (Reste <= 0.0):
                break
            var Recu : int = -1
            race:
                Sleep(Min(0.5, Reste))
                block:
                    set Recu = Choix.Await()
            if (V := Victimes[Recu - 700]):
                set Cible = option{V}
                break
        if (not Cible?, X := Victimes[GetRandomInt(0, Victimes.Length - 1)]):
            set Cible = option{X}
        FermerEcrans()
        if (C := Cible?, MC := Paquets[C], MC.Length > 0):
            I := GetRandomInt(0, MC.Length - 1)
            if (Volee := MC[I]):
                RetirerRelique(C, I)
                if (MJ := Paquets[J], MJ.Length < PaquetMax, set Paquets[J] = MJ + array{Volee}) {}
                SonCarte.Play()
                Avertir(J, "YOU STOLE {NomRelique(Volee)} FROM P{NumeroDe(C)}!")
                Avertir(C, "P{NumeroDe(J)} STOLE YOUR {NomRelique(Volee)}!")
                for (X : Assis, X <> J, X <> C):
                    Avertir(X, "P{NumeroDe(J)} STOLE A CARD FROM P{NumeroDe(C)}")

    # les 6 cartes a l'ecran (survol plus clair) + NO CARD. Renvoie la carte annoncee, ou -1.
    # PIOCHER : une carte arrive dans sa main
    Piocher(J : player)<suspends> : void =
        if (M := Paquets[J], M.Length < PaquetMax, set Paquets[J] = M + array{TirerRelique()}):
            SonCarte.Play()
            Avertir(J, "+1 CARD")
        for (X : Assis, X <> J):
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
            for (X : Assis, EstLa(X)?, UI := GetPlayerUI[X]):
                if (Ancien := Calques[X]):
                    UI.RemoveWidget(Ancien)
                var S : []canvas_slot = TexteEcrit(Gros, 0.5, 0.5, 0.0, -60.0, Taille)
                set S += TexteEcrit(Ligne1, 0.5, 0.5, 0.0, 120.0, 52.0)
                if (X = Qui):
                    set S += TexteEcrit(Ligne2, 0.5, 0.5, 0.0, 190.0, 44.0)
                C := canvas{Slots := S}
                UI.AddWidget(C)
                if (set Calques[X] = C) {}
            Sleep(0.06)
        SonBoom.Play()
        Sleep(1.6)
        for (X -> C : Calques, UI := GetPlayerUI[X]):
            UI.RemoveWidget(C)

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

    # la carte jouee, en grand, pour tout le monde (1,6 s)
    CartePosee(J : player, Id : int)<suspends> : void =
        FermerEcrans()
        SonCarte.Play()
        for (X : Assis, EstLa(X)?):
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

    # le personnage se penche (animation), puis le bouton s'enfonce
    Appuyer(J : player, K : int)<suspends> : void =
        # le geste jusqu'a l'image d'arret, puis il reste fige dessus (le doigt sur le bouton)
        if (Anim := AnimAppui?, Perso := J.GetFortCharacter[], Controle := Perso.GetPlayAnimationController[]):
            Arret := ImageArretAppui / Max(1.0, ImagesParSecondeAppui)
            Controle.Play(Anim)
            Sleep(Arret)
            Controle.Play(Anim, ?PlayRate := 0.0, ?StartPositionSeconds := Arret, ?BlendInTime := 0.0)
        if (set Enfoncee[K] = true) {}
        if (T := Touches[K], B0 := BaseTouches[K]):
            B := Tournee(B0, LacetMachine)
            spawn{ Bouger(T, transform{Translation := B.Translation - vector3{X := 0.0, Y := 0.0, Z := Enfoncement}, Rotation := B.Rotation, Scale := B.Scale}, 0.1) }
        if (T := TouchesClavier[K], B := BaseTouchesClavier[K]):
            spawn{ Bouger(T, transform{Translation := B.Translation - vector3{X := 0.0, Y := 0.0, Z := Enfoncement}, Rotation := B.Rotation, Scale := B.Scale}, 0.1) }
        Sleep(0.1)
        SonClic.Play()
        Sleep(0.4)

    ReprendreAppui(J : player) : void =
        if (Anim := AnimAppui?, Perso := J.GetFortCharacter[], Controle := Perso.GetPlayAnimationController[]):
            Controle.Play(Anim, ?StartPositionSeconds := ImageArretAppui / Max(1.0, ImagesParSecondeAppui), ?BlendInTime := 0.0)

    # piege : la machoire claque (fermee completement), jumpscare pour la victime, puis elle se rouvre
    # et la grille repart a zero
    Croc(J : player)<suspends> : void =
        PoseG := Tournee(BaseGueule, LacetMachine)
        SonBoom.Play()
        # la victime : le JUMPSCARE en plein ecran ; les autres : la machoire qui claque et le message
        sync:
            JouerCauchemar(J)
            block:
                spawn{ MachoireClavier(AngleFermeture, 0.12, 0.8, 1.6) }
                Gueule.MoveTo(PoseG.Translation, RotationGueule(AngleFermeture), 0.12)
                for (X : GetPlayspace().GetPlayers(), X <> J):
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
        spawn{ MachoireClavier(AngleFeinte, 0.07, 0.25, 0.0) }
        Gueule.MoveTo(PoseG.Translation, RotationGueule(AngleFeinte), 0.07)
        Gueule.MoveTo(PoseG.Translation, PoseG.Rotation, 0.25)

    # la machoire du clavier cache (il ne tourne jamais) : se ferme de Angle, reste Pause s, se rouvre
    MachoireClavier(Angle : float, Fermer : float, Ouvrir : float, Pause : float)<suspends> : void =
        if (G := GueuleClavier[0], B := BasesGueuleClavier[0]):
            Axe := if (AxeFermeture = 0) then vector3{X := 1.0, Y := 0.0, Z := 0.0} else if (AxeFermeture = 2) then vector3{X := 0.0, Y := 0.0, Z := 1.0} else vector3{X := 0.0, Y := 1.0, Z := 0.0}
            G.MoveTo(B.Translation, B.Rotation.RotateBy(MakeRotation(Axe, DegreesToRadians(Angle))), Fermer)
            Sleep(Pause)
            G.MoveTo(B.Translation, B.Rotation, Ouvrir)

    # LE JUMPSCARE, pour la victime seulement : ecran noir le temps de charger les premieres images (0,35 s),
    # puis les images calees sur l'horloge, avec le son (pour elle seule)
    JouerCauchemar(J : player)<suspends> : void =
        if (UI := GetPlayerUI[J], Premiere := ImagesCauchemar[0]):
            Plein := anchors{Minimum := vector2{X := 0.0, Y := 0.0}, Maximum := vector2{X := 1.0, Y := 1.0}}
            Couches := for (Im : ImagesCauchemar) do texture_block{DefaultImage := Im, DefaultDesiredSize := vector2{X := 1920.0, Y := 1080.0}}
            Ecran := texture_block{DefaultImage := Premiere, DefaultDesiredSize := vector2{X := 1920.0, Y := 1080.0}}
            Noir := color_block{DefaultColor := color{R := 0.0, G := 0.0, B := 0.0}, DefaultOpacity := 1.0}
            Scene := canvas{Slots := array{canvas_slot{Widget := Noir, Anchors := Plein, Offsets := margin{}, ZOrder := 3}}}
            UI.AddWidget(Scene)
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
            UI.RemoveWidget(Scene)
            SonCauchemar.Stop(J)
            SonCauchemar.Unregister(J)

    # =========================================================================
    #  INTERFACE (seulement des images et du texte : on joue sur la vraie machine)
    # =========================================================================
    FermerEcrans() : void =
        FinEcran.Signal()
        for (J -> C : Ecrans, UI := GetPlayerUI[J]):
            UI.RemoveWidget(C)
        set Ecrans = map{}
        set Chronos = map{}

    MajChronos(Reste : float) : void =
        if (S := Ceil[Reste]):
            V := Max(0, Min(99, S))
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
                CM := carte_main{Ev := Choix, Fin := FinEcran, Code := 100 + I, Image := Img, Normale := ImageRelique(Id), Lueur := ImageReliqueSurvol(Id), Taille := 230.0, Zone := Zone}
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
        Largeur := LargeurTexte(S, Taille)
        var Cx : float = X - Largeur * 0.5
        for (C : S):
            L := LargeurGlyphe(C) * Taille
            if (T := GlypheNormal(C)?, T2 := GlypheClair(C)?):
                Img := ImgH(T, Taille, Taille)
                set Lettres += array{Img}
                set Normales += array{T}
                set Claires += array{T2}
                set Slots += array{PlaceLibre(Img, AX, AY, Cx + L * 0.5, Y)}
            set Cx += L + Taille * 0.06
        Zone := TEST1{}
        BT := bouton_texte{Ev := Ev, Fin := FinEcran, Code := Code, Lettres := Lettres, Normales := Normales, Claires := Claires, Taille := Taille, Zone := Zone}
        spawn{ BT.Suivre() }
        Slots + array{PlaceH(Zone, AX, AY, X, Y, Largeur + 20.0, Taille * 0.9)}

    Montrer(J : player, S : []canvas_slot, Chrono : []texture_block, Souris : logic) : void =
        if (UI := GetPlayerUI[J]):
            C := canvas{Slots := S}
            if (Souris?):
                UI.AddWidget(C, player_ui_slot{InputMode := ui_input_mode.All})
            else:
                UI.AddWidget(C)
            if (set Ecrans[J] = C, set Chronos[J] = Chrono) {}

    NouveauChrono() : []texture_block =
        array{ImgH(Ecriture.E_0, 64.0, 64.0), ImgH(Ecriture.E_0, 64.0, 64.0)}

    # LE CHOIX DES CARTES : les 6 cartes, leur effet ; on en prend 3 (clic = prise / rendue), puis CONFIRM
    ChoixDepart()<suspends> : void =
        FermerEcrans()
        var Liste : []choix_depart = array{}
        for (J : Assis, EstLa(J)?):
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
                CM := carte_main{Ev := EvJ, Fin := FinEcran, Code := 500 + Place, Image := Img, Normale := ImageRelique(Id), Lueur := ImageReliqueSurvol(Id), Taille := 240.0, Zone := Zone}
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
            if (Reste <= 0.0 or Tous?):
                break
            Sleep(0.25)
        for (CD : Liste):
            CD.Completer()
            if (set Paquets[CD.J] = CD.Main()) {}
        FermerEcrans()

    # LES REGLES, au debut de la manche, pour tout le monde
    EcranRegles() : void =
        FermerEcrans()
        for (J : Assis, EstLa(J)?):
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
        for (J : Assis, EstLa(J)?):
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
        for (J : Assis, EstLa(J)?):
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
                    set S += BoutonTexte("TRUTH", 0.5, 1.0, XChoisie - 110.0, -360.0, 64.0, 400)
                    set S += BoutonTexte("LIE", 0.5, 1.0, XChoisie + 110.0, -360.0, 64.0, 401)
                else:
                    set S += TexteEcrit("SAY IT IS...", 0.5, 0.0, 0.0, 300.0, 100.0)
                    var N : int = 0
                    for (Id := 0..5, Id <> Reelle):
                        X := (N * 1.0 - 2.0) * 200.0
                        Img := ImgH(ImageRelique(Id), 210.0, 210.0)
                        Zone := TEST1{}
                        CM := carte_main{Ev := Choix, Fin := FinEcran, Code := 300 + Id, Image := Img, Normale := ImageRelique(Id), Lueur := ImageReliqueSurvol(Id), Taille := 210.0, Zone := Zone}
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
        for (J : Assis, EstLa(J)?):
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
        for (J : GetPlayspace().GetPlayers()):
            MessagePour(J, S)

    Avertir(J : player, S : string) : void =
        spawn{ MessageBref(J, S) }

    MessageBref(J : player, S : string)<suspends> : void =
        MessagePour(J, S)
        Sleep(2.5)
        MessagePour(J, "")

    # le message du haut, ecrit au pinceau (remplace le precedent ; "" = efface)
    MessagePour(J : player, S : string) : void =
        if (UI := GetPlayerUI[J]):
            if (Ancien := Bandeaux[J]):
                UI.RemoveWidget(Ancien)
            C := canvas{Slots := if (EnMachine[J]?) then TexteEcrit(S, 0.0, 0.5, 330.0, 220.0, 30.0) else TexteEcrit(S, 0.5, 0.0, 0.0, 90.0, 46.0)}
            UI.AddWidget(C)
            if (set Bandeaux[J] = C) {}
