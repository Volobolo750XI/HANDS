# ============================================================================
#  MACHINE A MAINS - jeu de table : chacun son tour, on appuie sur un bouton de la machine.
#  Certains boutons sont pieges : la machoire se referme et le joueur est elimine de la manche.
#  Avant d'appuyer, on peut ANNONCER une carte (on en pioche une a chaque tour). BLUFF : on peut annoncer une
#  carte qu'on n'a pas. Les autres ont DureeDefi s pour crier LIAR! :
#    - personne n'accuse        -> l'effet s'applique (meme si c'etait un mensonge)
#    - accuse et il mentait     -> pas d'effet, le menteur appuie sur 1 bouton de plus
#    - accuse mais c'etait vrai -> l'effet s'applique, l'accusateur perd une carte et appuiera sur 1 bouton de plus
#  Les mains sont secretes : les autres ne voient que le NOMBRE de cartes.
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

TexteHands<localizes>(S : string) : message = "{S}"

# --- Les cartes (id) ---------------------------------------------------------
#  0 DEFUSE  : si tu tombes sur un piege ce tour-ci, il n'explose pas (ton tour s'arrete)
#  1 PEEK    : un bouton SUR s'allume en vert pendant 3 s (toi seul le vois)
#  2 PASS    : tu passes ton tour sans appuyer
#  3 REVERSE : le sens du tour s'inverse
#  4 JAM     : le joueur suivant devra appuyer sur 2 boutons
#  5 STEAL   : tu voles une carte (au hasard) au joueur de ton choix
#  Images des cartes : dossier CartesHands du Tiroir a contenu (Carte_Defuse, Carte_Peek, Carte_Pass,
#  Carte_Reverse, Carte_Jam, Carte_Steal) : remplace-les par tes images en gardant les memes noms.
NomCarte(Id : int) : string =
    if (Id = 0) then "DEFUSE" else if (Id = 1) then "PEEK" else if (Id = 2) then "PASS" else if (Id = 3) then "REVERSE" else if (Id = 4) then "JAM" else "STEAL"

AideCarte(Id : int) : string =
    if (Id = 0) then "TRAP WON'T BITE" else if (Id = 1) then "SEE 1 SAFE BUTTON" else if (Id = 2) then "SKIP YOUR TURN" else if (Id = 3) then "REVERSE ORDER" else if (Id = 4) then "NEXT PRESSES 2" else "TAKE A CARD"

ImageCarte(Id : int) : texture =
    if (Id = 0) then CartesHands.Carte_Defuse else if (Id = 1) then CartesHands.Carte_Peek else if (Id = 2) then CartesHands.Carte_Pass
    else if (Id = 3) then CartesHands.Carte_Reverse else if (Id = 4) then CartesHands.Carte_Jam else CartesHands.Carte_Steal

ImgH(T : texture, L : float, H : float) : texture_block =
    texture_block{DefaultImage := T, DefaultDesiredSize := vector2{X := L, Y := H}}

# un clic sur un bouton de l'interface envoie son code a la partie
clic_hands := class:
    Ev : event(int)
    Code : int
    Quand(M : widget_message) : void = Ev.Signal(Code)

PlaceH(W : widget, AX : float, AY : float, X : float, Y : float, L : float, H : float) : canvas_slot =
    canvas_slot{Widget := W, Anchors := anchors{Minimum := vector2{X := AX, Y := AY}, Maximum := vector2{X := AX, Y := AY}},
        Alignment := vector2{X := 0.5, Y := 0.5}, Offsets := margin{Left := X, Top := Y, Right := L, Bottom := H}, SizeToContent := false}

TexteH(S : string, AX : float, AY : float, X : float, Y : float) : canvas_slot =
    canvas_slot{Widget := text_block{DefaultText := TexteHands(S), DefaultTextColor := color{R := 1.0, G := 1.0, B := 1.0}},
        Anchors := anchors{Minimum := vector2{X := AX, Y := AY}, Maximum := vector2{X := AX, Y := AY}},
        Alignment := vector2{X := 0.5, Y := 0.5}, Offsets := margin{Left := X, Top := Y, Right := 0.0, Bottom := 0.0}, SizeToContent := true}

hands_manager := class(creative_device):
    # --- A REMPLIR DANS UEFN ---------------------------------------------------
    # Une place par joueur autour de la table (accessoires invisibles poses devant chaque chaise)
    @editable Places : []creative_prop = array{}
    # La machine : le centre (Corps), la machoire du haut (Gueule) et les 24 boutons DANS L'ORDRE Bouton_01..Bouton_24
    @editable Centre : creative_prop = creative_prop{}
    @editable Gueule : creative_prop = creative_prop{}
    @editable Touches : []creative_prop = array{}
    @editable Plaque : creative_prop = creative_prop{}
    # Son de rotation (Audio Player en BOUCLE, lecture automatique NON) : il joue tant que la machine tourne
    @editable SonRotation : audio_player_device = audio_player_device{}
    # Direction (degres, vue du dessus dans UEFN) vers laquelle la gueule regarde au depart. Ajuste si elle
    # ne fait pas face au bon joueur (ex. 90, 180, -90).
    @editable FaceDepart : float = 0.0
    @editable DureeRotation : float = 1.75       # secondes pour pivoter vers le joueur suivant
    # true = sens des aiguilles d'une montre (vu du dessus). Mets false si elle tourne a l'envers.
    @editable SensHoraire : logic = true
    # Sons (Audio Player : lecture automatique NON)
    @editable SonClic : audio_player_device = audio_player_device{}
    @editable SonBoom : audio_player_device = audio_player_device{}
    @editable SonCarte : audio_player_device = audio_player_device{}
    # Animation "se pencher et appuyer" (Mixamo -> squelette Fortnite). Vide = pas d'animation.
    @editable AnimAppui : ?animation_sequence = false
    # Reglages
    @editable JoueursMinimum : int = 2
    # TEST : true = on peut jouer TOUT SEUL (la manche dure jusqu'a ce que tu tombes sur un piege).
    # Decoche avant de publier.
    @editable TestSolo : logic = false
    @editable PiegesParGrille : int = 2
    @editable DureeTour : float = 20.0
    @editable DureeDefi : float = 5.0            # secondes pour crier LIAR! apres une annonce
    @editable AngleFermeture : float = 26.0      # degres pour fermer la machoire
    @editable AxeFermeture : int = 1             # 0 = X, 1 = Y, 2 = Z (change si elle tourne dans le mauvais sens)
    @editable Enfoncement : float = 2.0          # cm : un bouton appuye descend de ca
    Colonnes : int = 4
    MainMax : int = 3

    Choix : event(int) = event(int){}
    var BaseTouches : []transform = array{}
    var BaseGueule : transform = transform{}
    var BaseCentre : transform = transform{}
    var BasePlaque : transform = transform{}
    var LacetMachine : float = 0.0               # rotation actuelle de toute la machine (degres)
    var Enfoncee : []logic = array{}
    var Piegee : []logic = array{}
    var Assis : []player = array{}
    var Vivants : []player = array{}
    var Mains : [player][]int = map{}
    var Sens : int = 1
    var Bloque : int = 0
    var Ecrans : [player]canvas = map{}
    var Chronos : [player]text_block = map{}
    var Bandeaux : [player]text_block = map{}
    # BLUFF : l'annonce en cours (les autres peuvent crier LIAR!)
    var DefiEnCours : logic = false
    var DefiCarte : int = 0
    var DefiAuteur : int = 0                     # numero (P1, P2...) de celui qui annonce
    var Penalites : [player]int = map{}          # boutons en plus au prochain tour (mauvaise accusation)

    OnBegin<override>()<suspends> : void =
        set BaseTouches = for (T : Touches) do T.GetTransform()
        set BaseGueule = Gueule.GetTransform()
        set BaseCentre = Centre.GetTransform()
        set BasePlaque = Plaque.GetTransform()
        set Enfoncee = for (T : Touches) do false
        set Piegee = for (T : Touches) do false
        loop:
            Presents := GetPlayspace().GetPlayers()
            Requis := if (TestSolo?) then 1 else Max(2, JoueursMinimum)
            if (Presents.Length >= Requis):
                Manche()
                Sleep(6.0)
            else:
                Bandeau("WAITING FOR PLAYERS {Presents.Length}/{Requis}")
                Sleep(1.0)

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
        set Mains = map{}
        set Penalites = map{}
        set DefiEnCours = false
        set Sens = 1
        set Bloque = 0
        for (I -> J : Liste):
            Asseoir(J, I)
            if (set Mains[J] = array{TirerCarte()}) {}
        NouvelleGrille()
        for (N := 0..2):
            Bandeau("ROUND STARTS IN {3 - N}")
            Sleep(1.0)
        Bandeau("")
        var Index : int = GetRandomInt(0, Max(0, Vivants.Length - 1))
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
        if (G := Vivants[0]):
            Bandeau("P{NumeroDe(G)} WINS THE ROUND!")
        else:
            Bandeau(if (TestSolo?) then "GAME OVER - THE TRAP GOT YOU" else "NO WINNER")
        Sleep(4.0)
        Bandeau("")
        for (J : Assis, Perso := J.GetFortCharacter[]):
            Perso.ReleaseFromStasis()

    # le joueur est pose a sa place, tourne vers la machine, et ne bouge plus
    Asseoir(J : player, I : int) : void =
        if (Pl := Places[I], Perso := J.GetFortCharacter[]):
            Ici := Pl.GetTransform().Translation
            C := Centre.GetTransform().Translation
            Lacet := ArcTan(C.Y - Ici.Y, C.X - Ici.X) * 180.0 / PiFloat
            if (Perso.TeleportTo[Ici + vector3{X := 0.0, Y := 0.0, Z := 20.0}, MakeRotationFromYawPitchRollDegrees(Lacet, 0.0, 0.0)]) {}
            # assis : il ne peut pas se deplacer, mais il peut tourner la tete (et faire des emotes)
            Perso.PutInStasis(stasis_args{AllowTurning := true, AllowFalling := false, AllowEmotes := true})

    TirerCarte()<transacts> : int = GetRandomInt(0, 5)

    EstLa(J : player)<transacts> : logic =
        var Trouve : logic = false
        for (X : GetPlayspace().GetPlayers(), X = J):
            set Trouve = true
        Trouve

    NumeroDe(J : player) : int =
        var N : int = 0
        for (I -> X : Assis, X = J):
            set N = I + 1
        N

    # =========================================================================
    #  LA GRILLE
    # =========================================================================
    NouvelleGrille() : void =
        set Enfoncee = for (T : Touches) do false
        set Piegee = for (T : Touches) do false
        var Poses : int = 0
        var Essais : int = 0
        loop:
            if (Poses >= Min(PiegesParGrille, Touches.Length - 1) or Essais > 500):
                break
            set Essais += 1
            K := GetRandomInt(0, Touches.Length - 1)
            if (not Piegee[K]?, set Piegee[K] = true):
                set Poses += 1
        for (K -> T : Touches, B := BaseTouches[K]):
            spawn{ Bouger(T, Tournee(B, LacetMachine), 0.25) }

    # une piece de la machine, tournee de Lacet degres autour du centre de la machine
    Tournee(B : transform, Lacet : float) : transform =
        R := MakeRotation(vector3{X := 0.0, Y := 0.0, Z := 1.0}, DegreesToRadians(Lacet))
        C := BaseCentre.Translation
        transform{Translation := C + R.RotateVector(B.Translation - C), Rotation := B.Rotation.RotateBy(R), Scale := B.Scale}

    # TOUTE la machine pivote vers le joueur J, avec le son de rotation (coupe a l'arret)
    TournerVers(J : player)<suspends> : void =
        I := NumeroDe(J) - 1
        if (Pl := Places[I]):
            Ici := Pl.GetTransform().Translation
            C := BaseCentre.Translation
            Cible := ArcTan(Ici.Y - C.Y, Ici.X - C.X) * 180.0 / PiFloat - FaceDepart
            var Ecart : float = Cible - LacetMachine
            # toujours dans le meme sens (aiguilles d'une montre) : ecart ramene entre 0 et 360 (ou -360 et 0)
            loop:
                if (Ecart < 360.0):
                    break
                set Ecart -= 360.0
            loop:
                if (Ecart >= 0.0):
                    break
                set Ecart += 360.0
            if (not SensHoraire?, Ecart > 0.0):
                set Ecart -= 360.0
            if (Abs(Ecart) > 1.0, Abs(Ecart) < 359.0):
                Duree := Max(0.2, DureeRotation)
                Pas := if (N := Ceil[Abs(Ecart) / 8.0]) then Max(1, N) else 1
                Dt := Duree / (Pas * 1.0)
                Depart := LacetMachine
                SonRotation.Play()
                for (K := 1..Pas):
                    L := Depart + Ecart * (K * 1.0) / (Pas * 1.0)
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
    #  UN TOUR : piocher, (annoncer une carte - vraie ou bluff), appuyer
    #  renvoie true si le joueur est elimine
    #  Codes des clics : 0-23 bouton de la machine, 100+Id annoncer une carte, 200+I voler a la place I,
    #  300 annuler le vol, 400 montrer un bouton a tous (apres PEEK), 500+I LIAR! de la place I
    # =========================================================================
    TourDe(J : player)<suspends> : logic =
        TournerVers(J)
        if (M := Mains[J], M.Length < MainMax, set Mains[J] = M + array{TirerCarte()}):
            SonCarte.Play()
        Penalite := if (P := Penalites[J]) then P else 0
        if (set Penalites[J] = 0) {}
        var Requis : int = 1 + Bloque + Penalite
        set Bloque = 0
        var CarteJouee : logic = false
        var Bouclier : logic = false
        var ModeVol : logic = false
        var ModeMontrer : logic = false
        var PeekFait : logic = false
        var Vu : int = -1
        var FinVu : float = 0.0
        var Elimine : logic = false
        var Fini : logic = false
        var Fin : float = GetSimulationElapsedTime() + DureeTour
        loop:
            if (Fini?):
                break
            Afficher(J, Requis, CarteJouee, ModeVol, ModeMontrer, PeekFait, Vu)
            # attente : un clic, ou la fin du temps (bouton au hasard), ou la fin du PEEK
            var Code : int = -2
            loop:
                Maintenant := GetSimulationElapsedTime()
                Reste := Fin - Maintenant
                MajChronos(Reste)
                if (Reste <= 0.0):
                    set Code = -1
                    break
                if (Vu >= 0, Maintenant >= FinVu):
                    set Vu = -1
                    set Code = -3
                    break
                var Recu : int = -2
                race:
                    Sleep(Min(1.0, Reste))
                    block:
                        set Recu = Choix.Await()
                # (un LIAR! hors annonce est ignore)
                if (Recu <> -2, Recu < 500):
                    set Code = Recu
                    break
            K := if (Code = -1) then BoutonLibre() else Code
            # --- PEEK : le joueur MONTRE un bouton a tout le monde (vrai ou faux !) au lieu d'appuyer
            if (ModeMontrer?, Code >= 0, Code < Touches.Length, not Enfoncee[Code]?):
                set ModeMontrer = false
                set PeekFait = false
                BandeauSauf(J, "P{NumeroDe(J)} SAYS BUTTON {Code + 1} IS SAFE")
                Avertir(J, "YOU TOLD EVERYONE BUTTON {Code + 1} IS SAFE")
            # --- un bouton (ou le temps ecoule : bouton au hasard)
            else if (K >= 0, K < Touches.Length, not Enfoncee[K]?):
                set ModeMontrer = false
                Appuyer(J, K)
                if (Piegee[K]?):
                    if (Bouclier?):
                        set Bouclier = false
                        Avertir(J, "DEFUSED! THE TRAP DIDN'T BITE")
                        if (PiegesRestants() = 0):
                            NouvelleGrille()
                    else:
                        Croc(J)
                        set Elimine = true
                    set Fini = true
                else:
                    set Requis -= 1
                    if (Requis <= 0):
                        set Fini = true
            # --- ANNONCE d'une carte (vraie ou bluff), une fois par tour
            else if (Code >= 100, Code <= 105, not CarteJouee?):
                set CarteJouee = true
                Id := Code - 100
                Possede := IndexCarte(J, Id)
                Debut := GetSimulationElapsedTime()
                Accusateur := Annoncer(J, Id)
                # le temps de l'annonce ne compte pas dans le temps du tour
                set Fin += GetSimulationElapsedTime() - Debut
                var Effet : logic = true
                if (A := Accusateur?):
                    if (Possede < 0):
                        # il mentait : pas d'effet, 1 bouton de plus
                        set Effet = false
                        set Requis += 1
                        SonBoom.Play()
                        Bandeau("P{NumeroDe(J)} WAS LYING! +1 BUTTON")
                    else:
                        # il disait vrai : l'accusateur perd une carte et appuiera sur 1 bouton de plus
                        RetirerCarteAuHasard(A)
                        PA := if (P := Penalites[A]) then P else 0
                        if (set Penalites[A] = PA + 1) {}
                        Bandeau("P{NumeroDe(J)} TOLD THE TRUTH! P{NumeroDe(A)} LOSES A CARD AND +1 BUTTON")
                else:
                    Bandeau("NOBODY CALLED LIAR - {NomCarte(Id)} WORKS")
                spawn{ EffacerBandeau(2.5) }
                # s'il avait vraiment la carte, elle est defaussee
                if (Possede >= 0, Effet?):
                    RetirerCarte(J, Possede)
                if (Effet?):
                    SonCarte.Play()
                    if (Id = 0):
                        set Bouclier = true
                    else if (Id = 1):
                        set Vu = BoutonSur()
                        set FinVu = GetSimulationElapsedTime() + 3.0
                        set PeekFait = true
                    else if (Id = 2):
                        set Fini = true
                    else if (Id = 3):
                        set Sens = -Sens
                    else if (Id = 4):
                        set Bloque += 1
                    else if (Id = 5):
                        set ModeVol = true
            # --- STEAL : le joueur a choisi sa victime (une carte au hasard)
            else if (Code >= 200, Code < 300, ModeVol?, Cible := Assis[Code - 200], MC := Mains[Cible], MC.Length > 0):
                I := GetRandomInt(0, MC.Length - 1)
                if (Volee := MC[I]):
                    RetirerCarte(Cible, I)
                    if (MJ := Mains[J], MJ.Length < MainMax, set Mains[J] = MJ + array{Volee}) {}
                set ModeVol = false
                SonCarte.Play()
                BandeauSauf(J, "P{NumeroDe(J)} STOLE A CARD FROM P{NumeroDe(Cible)}")
            else if (Code = 300):
                set ModeVol = false
            else if (Code = 400, PeekFait?):
                set ModeMontrer = true
        FermerEcrans()
        Elimine

    # l'annonce : DureeDefi s pendant lesquelles les autres joueurs en jeu peuvent crier LIAR!
    # renvoie le premier accusateur (ou rien)
    Annoncer(J : player, Id : int)<suspends> : ?player =
        set DefiEnCours = true
        set DefiCarte = Id
        set DefiAuteur = NumeroDe(J)
        SonCarte.Play()
        Afficher(J, 0, true, false, false, false, -1)
        var Accuse : ?player = false
        # seul (TEST SOLO) : personne ne peut crier LIAR, on n'attend qu'une seconde
        FinDefi := GetSimulationElapsedTime() + (if (TestSolo?) then 1.0 else DureeDefi)
        loop:
            Reste := FinDefi - GetSimulationElapsedTime()
            MajChronos(Reste)
            if (Reste <= 0.0 or Accuse?):
                break
            var Recu : int = -2
            race:
                Sleep(Min(0.5, Reste))
                block:
                    set Recu = Choix.Await()
            if (Recu >= 500, Recu < 600, A := Assis[Recu - 500], A <> J, Contient(Vivants, A)?):
                set Accuse = option{A}
                Bandeau("P{NumeroDe(A)} SAYS P{NumeroDe(J)} IS LYING!")
                Sleep(1.2)
        set DefiEnCours = false
        Accuse

    Contient(Liste : []player, J : player)<transacts> : logic =
        var Trouve : logic = false
        for (X : Liste, X = J):
            set Trouve = true
        Trouve

    EffacerBandeau(Apres : float)<suspends> : void =
        Sleep(Apres)
        if (not DefiEnCours?):
            Bandeau("")

    # place de la carte Id dans la main du joueur (-1 s'il ne l'a pas)
    IndexCarte(J : player, Id : int)<transacts> : int =
        var Trouve : int = -1
        if (M := Mains[J]):
            for (I -> X : M, X = Id, Trouve < 0):
                set Trouve = I
        Trouve

    NombreDe(J : player)<transacts> : int =
        if (M := Mains[J]) then M.Length else 0

    RetirerCarte(J : player, Index : int) : void =
        if (M := Mains[J], set Mains[J] = for (I -> X : M, I <> Index) do X) {}

    RetirerCarteAuHasard(J : player) : void =
        if (M := Mains[J], M.Length > 0):
            RetirerCarte(J, GetRandomInt(0, M.Length - 1))

    # le personnage se penche (animation), puis le bouton s'enfonce
    Appuyer(J : player, K : int)<suspends> : void =
        if (Anim := AnimAppui?, Perso := J.GetFortCharacter[], Controle := Perso.GetPlayAnimationController[]):
            Controle.Play(Anim)
            Sleep(0.6)
        if (set Enfoncee[K] = true) {}
        if (T := Touches[K], B0 := BaseTouches[K]):
            B := Tournee(B0, LacetMachine)
            Bouger(T, transform{Translation := B.Translation - vector3{X := 0.0, Y := 0.0, Z := Enfoncement}, Rotation := B.Rotation, Scale := B.Scale}, 0.1)
        SonClic.Play()
        Sleep(0.4)

    # piege : la machoire claque, flash rouge pour la victime, puis elle se rouvre et la grille repart a zero
    Croc(J : player)<suspends> : void =
        Axe := if (AxeFermeture = 0) then vector3{X := 1.0, Y := 0.0, Z := 0.0} else if (AxeFermeture = 2) then vector3{X := 0.0, Y := 0.0, Z := 1.0} else vector3{X := 0.0, Y := 1.0, Z := 0.0}
        Lacet := MakeRotation(vector3{X := 0.0, Y := 0.0, Z := 1.0}, DegreesToRadians(LacetMachine))
        PoseG := Tournee(BaseGueule, LacetMachine)
        Fermee := PoseG.Rotation.RotateBy(MakeRotation(Lacet.RotateVector(Axe), DegreesToRadians(AngleFermeture)))
        SonBoom.Play()
        spawn{ FlashRouge(J) }
        Gueule.MoveTo(PoseG.Translation, Fermee, 0.12)
        Bandeau("P{NumeroDe(J)} LOST A HAND!")
        Sleep(1.6)
        Gueule.MoveTo(PoseG.Translation, PoseG.Rotation, 0.8)
        Bandeau("")
        NouvelleGrille()

    FlashRouge(J : player)<suspends> : void =
        if (UI := GetPlayerUI[J]):
            Voile := color_block{DefaultColor := color{R := 0.8, G := 0.0, B := 0.0}, DefaultOpacity := 0.55}
            C := canvas{Slots := array{canvas_slot{Widget := Voile, Anchors := anchors{Minimum := vector2{X := 0.0, Y := 0.0}, Maximum := vector2{X := 1.0, Y := 1.0}}, Offsets := margin{}}}}
            UI.AddWidget(C)
            Sleep(0.5)
            UI.RemoveWidget(C)

    # =========================================================================
    #  INTERFACE
    # =========================================================================
    BoutonCode(S : string, Code : int) : button_regular =
        B := button_regular{DefaultText := TexteHands(S)}
        B.OnClick().Subscribe(clic_hands{Ev := Choix, Code := Code}.Quand)
        B

    FermerEcrans() : void =
        for (J -> C : Ecrans, UI := GetPlayerUI[J]):
            UI.RemoveWidget(C)
        set Ecrans = map{}
        set Chronos = map{}

    MajChronos(Reste : float) : void =
        if (S := Ceil[Reste]):
            for (J -> T : Chronos):
                T.SetText(TexteHands("{Max(0, S)}"))

    # l'ecran de chaque joueur : SA main en images (secrete), le nombre de cartes des autres,
    # et pour le joueur actif la grille + les 6 cartes qu'il peut ANNONCER (vraies ou bluff)
    Afficher(Actif : player, Requis : int, CarteJouee : logic, ModeVol : logic, ModeMontrer : logic, PeekFait : logic, Vu : int) : void =
        FermerEcrans()
        Libres := LibresRestants()
        Risque := if (Libres > 0, P := Floor[PiegesRestants() * 100.0 / (Libres * 1.0) + 0.5]) then P else 0
        for (J : Assis, EstLa(J)?, UI := GetPlayerUI[J]):
            var S : []canvas_slot = array{}
            Chrono := text_block{DefaultText := TexteHands(""), DefaultTextColor := color{R := 1.0, G := 0.85, B := 0.2}}
            set S += array{canvas_slot{Widget := Chrono, Anchors := anchors{Minimum := vector2{X := 0.5, Y := 0.0}, Maximum := vector2{X := 0.5, Y := 0.0}},
                Alignment := vector2{X := 0.5, Y := 0.5}, Offsets := margin{Left := 0.0, Top := 150.0, Right := 0.0, Bottom := 0.0}, SizeToContent := true}}
            set S += array{TexteH("DANGER {Risque}%", 0.5, 0.0, 0.0, 185.0)}
            set S += array{TexteH("YOU ARE P{NumeroDe(J)}", 0.0, 0.0, 120.0, 40.0)}
            # le nombre de cartes de chacun (les mains sont secretes)
            var Ligne : float = 80.0
            for (I -> X : Assis, X <> J, Contient(Vivants, X)?):
                set S += array{TexteH("P{I + 1} : {NombreDe(X)} CARD(S)", 0.0, 0.0, 120.0, Ligne)}
                set Ligne += 32.0
            # SA main, en images, en bas de l'ecran (lui seul la voit)
            Main : []int = if (M := Mains[J]) then M else array{}
            for (I -> Id : Main):
                # (images 1024 x 1024 : la carte, plus haute que large, est au milieu de l'image carree)
                X := (I * 1.0 - (Main.Length - 1) * 0.5) * 180.0
                set S += array{PlaceH(ImgH(ImageCarte(Id), 240.0, 240.0), 0.5, 1.0, X, -135.0, 240.0, 240.0)}
            var Clavier : logic = false
            if (DefiEnCours?):
                # une annonce est en cours : LIAR! pour les autres joueurs encore en jeu
                set S += array{PlaceH(ImgH(ImageCarte(DefiCarte), 340.0, 340.0), 0.5, 0.5, 0.0, -40.0, 340.0, 340.0)}
                if (J = Actif):
                    set S += array{TexteH("YOU CLAIMED {NomCarte(DefiCarte)} - WILL THEY BELIEVE YOU?", 0.5, 0.0, 0.0, 110.0)}
                else if (Contient(Vivants, J)?):
                    set S += array{TexteH("P{DefiAuteur} CLAIMS {NomCarte(DefiCarte)}! LYING?", 0.5, 0.0, 0.0, 110.0)}
                    set S += array{PlaceH(BoutonCode("LIAR!", 500 + NumeroDe(J) - 1), 0.5, 0.5, 0.0, 150.0, 260.0, 80.0)}
                    set Clavier = true
            else if (J = Actif):
                set Clavier = true
                if (ModeVol?):
                    # choisir la victime du STEAL
                    set S += array{TexteH("STEAL FROM WHO?", 0.5, 0.5, 0.0, -120.0)}
                    var N : int = 0
                    for (I -> X : Assis, X <> J, Contient(Vivants, X)?, NombreDe(X) > 0):
                        set S += array{PlaceH(BoutonCode("P{I + 1} ({NombreDe(X)})", 200 + I), 0.5, 0.5, -200.0 + N * 200.0, -40.0, 180.0, 60.0)}
                        set N += 1
                    set S += array{PlaceH(BoutonCode("CANCEL", 300), 0.5, 0.5, 0.0, 60.0, 180.0, 60.0)}
                else:
                    Consigne := if (ModeMontrer?) then "CLICK THE BUTTON TO SHOW EVERYONE (TRUE OR FALSE!)" else "YOUR TURN - PRESS {Requis} BUTTON(S)"
                    set S += array{TexteH(Consigne, 0.5, 0.0, 0.0, 110.0)}
                    # la grille : rangee du haut = fond de la machine
                    for (R := 0..5, C0 := 0..Colonnes - 1, K := R * Colonnes + C0, K < Touches.Length):
                        Q := Colonnes - 1 - C0
                        X := (Q * 1.0 - (Colonnes - 1) * 0.5) * 92.0 + 330.0
                        Y := (R * 1.0 - 2.5) * 70.0 - 60.0
                        if (Enfoncee[K]?):
                            set S += array{PlaceH(color_block{DefaultColor := color{R := 0.08, G := 0.08, B := 0.08}, DefaultOpacity := 0.8}, 0.5, 0.5, X, Y, 84.0, 60.0)}
                        else:
                            if (K = Vu):
                                set S += array{PlaceH(color_block{DefaultColor := color{R := 0.1, G := 0.9, B := 0.2}}, 0.5, 0.5, X, Y, 94.0, 70.0)}
                            set S += array{PlaceH(BoutonCode("{K + 1}", K), 0.5, 0.5, X, Y, 84.0, 60.0)}
                    if (not CarteJouee?):
                        # ANNONCER une carte : n'importe laquelle des 6 (celles qu'il a sont marquees IN HAND)
                        set S += array{TexteH("CLAIM A CARD (YOU CAN BLUFF!)", 0.5, 0.5, -560.0, -260.0)}
                        for (Id := 0..5):
                            Y := -200.0 + Id * 62.0
                            set S += array{PlaceH(BoutonCode(NomCarte(Id), 100 + Id), 0.5, 0.5, -600.0, Y, 200.0, 54.0)}
                            Info := if (IndexCarte(J, Id) >= 0) then "IN HAND" else AideCarte(Id)
                            set S += array{TexteH(Info, 0.5, 0.5, -390.0, Y)}
                    if (PeekFait?, not ModeMontrer?):
                        set S += array{PlaceH(BoutonCode("SHOW A BUTTON TO ALL", 400), 0.5, 0.5, -560.0, 200.0, 320.0, 60.0)}
            else:
                set S += array{TexteH("P{NumeroDe(Actif)} IS PLAYING...", 0.5, 0.0, 0.0, 110.0)}
            C := canvas{Slots := S}
            if (Clavier?):
                UI.AddWidget(C, player_ui_slot{InputMode := ui_input_mode.All})
            else:
                UI.AddWidget(C)
            if (set Ecrans[J] = C, set Chronos[J] = Chrono) {}

    # message en haut de l'ecran pour tout le monde ("" = efface)
    Bandeau(S : string) : void =
        for (J : GetPlayspace().GetPlayers()):
            MessagePour(J, S)

    BandeauSauf(Auteur : player, S : string) : void =
        for (J : GetPlayspace().GetPlayers(), J <> Auteur):
            spawn{ MessageBref(J, S) }

    Avertir(J : player, S : string) : void =
        spawn{ MessageBref(J, S) }

    MessageBref(J : player, S : string)<suspends> : void =
        MessagePour(J, S)
        Sleep(2.5)
        MessagePour(J, "")

    MessagePour(J : player, S : string) : void =
        if (T := Bandeaux[J]):
            T.SetText(TexteHands(S))
        else if (UI := GetPlayerUI[J]):
            T := text_block{DefaultText := TexteHands(S), DefaultTextColor := color{R := 1.0, G := 1.0, B := 1.0}}
            UI.AddWidget(canvas{Slots := array{canvas_slot{Widget := T, Anchors := anchors{Minimum := vector2{X := 0.5, Y := 0.0}, Maximum := vector2{X := 0.5, Y := 0.0}},
                Alignment := vector2{X := 0.5, Y := 0.5}, Offsets := margin{Left := 0.0, Top := 60.0, Right := 0.0, Bottom := 0.0}, SizeToContent := true}}})
            if (set Bandeaux[J] = T) {}
