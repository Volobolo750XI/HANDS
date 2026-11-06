# ============================================================================
#  MORSURE - jeu de table de bluff, ambiance horreur.
#  Les joueurs sont assis autour de la machine. Chacun son tour, on appuie SOI-MEME sur un bouton de la
#  machine : on vise le bouton avec la camera (il devient blanc) et on clique. Certains boutons sont pieges :
#  la machoire se referme et le joueur est elimine de la manche. Le dernier en jeu gagne.
#
#  BLUFF : au debut de son tour, on peut ANNONCER une carte, meme si on ne l'a pas. Les autres ont DureeDefi s
#  pour crier LIAR! (en cliquant) :
#    - personne n'accuse        -> l'effet s'applique (meme si c'etait un mensonge)
#    - accuse et il mentait     -> pas d'effet, le menteur appuie sur 1 bouton de plus
#    - accuse mais c'etait vrai -> l'effet s'applique, l'accusateur perd une carte et appuiera sur 1 bouton de plus
#  Les jeux de chacun sont secrets : les autres ne voient que le NOMBRE de cartes.
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
relique_cliquable := class:
    Ev : event(int)
    Fin : event()
    Code : int
    Image : texture_block
    Normale : texture
    Survol : texture
    Zone : TEST1

    Suivre()<suspends> : void =
        race:
            Fin.Await()
            loop:
                Zone.Clic.Await()
                Ev.Signal(Code)
            loop:
                Zone.Entre.Await()
                Image.SetImage(Survol)
                Zone.Sort.Await()
                Image.SetImage(Normale)

hands_manager := class(creative_device):
    # --- A REMPLIR DANS UEFN ---------------------------------------------------
    # Une place par joueur autour de la table (accessoires invisibles poses devant chaque chaise)
    @editable Places : []creative_prop = array{}
    # Une CHAISE (appareil Chaise / Chair) par place, MEME ORDRE que Places. Vide = joueurs figes sur place.
    @editable Chaises : []chair_device = array{}
    # FACULTATIF : une camera fixe par place, MEME ORDRE, posee devant la bouche de la machine et qui regarde
    # le clavier (la machine est tournee vers cette place pendant son tour). Vide = la camera du joueur.
    @editable CamerasClavier : []gameplay_camera_fixed_point_device = array{}
    # La machine : le centre (Corps), la machoire du haut (Gueule) et les 24 boutons DANS L'ORDRE Bouton_01..Bouton_24
    @editable Centre : creative_prop = creative_prop{}
    @editable Gueule : creative_prop = creative_prop{}
    @editable Touches : []creative_prop = array{}
    @editable Plaque : creative_prop = creative_prop{}
    # COULEURS DES BOUTONS : 3 materiaux dans un dossier Teintes du Tiroir a contenu :
    #   T_Base (l'aspect normal d'un bouton), T_Clair (le bouton vise, blanc), T_Sur (le bouton sur du PEEK, vert)
    # Numero de l'emplacement de materiau du bouton (0 en general)
    @editable IndexMateriau : int = 0
    # CLIC : un Declencheur d'entree (Input Trigger) regle sur l'action "Tir" (clic gauche / gachette).
    # Sert a appuyer sur le bouton vise, a crier LIAR! et a choisir la victime d'un STEAL.
    @editable ToucheClic : input_trigger_device = input_trigger_device{}
    # Distance max (cm) entre le regard et le centre d'un bouton pour qu'il soit vise
    @editable PorteeVisee : float = 12.0
    # Son de rotation (Audio Player en BOUCLE, lecture automatique NON) : il joue tant que la machine tourne
    @editable SonRotation : audio_player_device = audio_player_device{}
    # Direction (degres, vue du dessus dans UEFN) vers laquelle la gueule regarde au depart. Ajuste si elle
    # ne fait pas face au bon joueur (ex. 90, 180, -90).
    @editable FaceDepart : float = 0.0
    @editable DureeRotation : float = 1.75       # secondes pour pivoter vers le joueur suivant
    # Sons (Audio Player : lecture automatique NON)
    @editable SonClic : audio_player_device = audio_player_device{}
    @editable SonBoom : audio_player_device = audio_player_device{}
    @editable SonCarte : audio_player_device = audio_player_device{}
    # Animation "se pencher et appuyer" (Mixamo -> squelette Fortnite). Vide = pas d'animation.
    @editable AnimAppui : ?animation_sequence = false
    # Reglages
    @editable JoueursMinimum : int = 2
    # TEST : true = on peut jouer TOUT SEUL (la manche dure jusqu'a ce que tu tombes sur un piege ;
    # entre deux tours, la machine fait un tour complet et revient sur toi). Decoche avant de publier.
    @editable TestSolo : logic = false
    @editable PiegesParGrille : int = 2
    @editable DureeTour : float = 25.0           # temps pour appuyer (le choix de la carte et l'annonce en plus)
    @editable DureeChoixCarte : float = 10.0     # temps pour choisir la carte a annoncer
    @editable DureeDefi : float = 5.0            # secondes pour crier LIAR! apres une annonce
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
    var Chronos : [player]text_block = map{}
    var Bandeaux : [player]text_block = map{}
    var DernierTourne : int = -1                 # place vers laquelle la machine est tournee
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
        ToucheClic.PressedEvent.Subscribe(QuandClic)
        loop:
            Presents := GetPlayspace().GetPlayers()
            Requis := if (TestSolo?) then 1 else Max(2, JoueursMinimum)
            if (Presents.Length >= Requis):
                Manche()
                Sleep(6.0)
            else:
                Bandeau("WAITING FOR PLAYERS {Presents.Length}/{Requis}")
                Sleep(1.0)

    QuandClic(Agent : agent) : void =
        ClicJoueur.Signal(Agent)

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
        set Paquets = map{}
        set Penalites = map{}
        set DefiEnCours = false
        set Sens = 1
        set Bloque = 0
        for (I -> J : Liste):
            Asseoir(J, I)
            if (set Paquets[J] = array{TirerRelique()}) {}
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
        if (G := Vivants[0], not TestSolo?):
            Bandeau("P{NumeroDe(G)} WINS THE ROUND!")
        else:
            Bandeau(if (TestSolo?) then "GAME OVER - THE TRAP GOT YOU" else "NO WINNER")
        Sleep(4.0)
        Bandeau("")
        for (J : Assis, Perso := J.GetFortCharacter[]):
            Perso.ReleaseFromStasis()

    # le joueur va a sa place, tourne vers la machine, et s'assoit sur sa chaise (ou reste fige sur place)
    Asseoir(J : player, I : int) : void =
        if (Pl := Places[I], Perso := J.GetFortCharacter[]):
            Ici := Pl.GetTransform().Translation
            C := Centre.GetTransform().Translation
            Lacet := ArcTan(C.Y - Ici.Y, C.X - Ici.X) * 180.0 / PiFloat
            if (Perso.TeleportTo[Ici + vector3{X := 0.0, Y := 0.0, Z := 20.0}, MakeRotationFromYawPitchRollDegrees(Lacet, 0.0, 0.0)]) {}
            if (Ch := Chaises[I]):
                Ch.Seat(J)
            else:
                # pas de chaise : il ne peut pas se deplacer, mais il peut tourner la tete
                Perso.PutInStasis(stasis_args{AllowTurning := true, AllowFalling := false, AllowEmotes := true})

    # un joueur qui s'est leve de sa chaise y est remis (la chaise ne fait rien s'il est deja assis)
    Rasseoir() : void =
        for (I -> J : Assis, Contient(Vivants, J)?, Ch := Chaises[I]):
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
            if (Abs(Ecart) <= 2.0, TestSolo?, DernierTourne = I):
                set Ecart = 360.0
            set DernierTourne = I
            if (Abs(Ecart) > 2.0):
                Duree := Max(0.2, DureeRotation * (if (Abs(Ecart) > 300.0) then 1.6 else 1.0))
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
    #  UN TOUR : piocher -> (annoncer une carte, vraie ou bluff) -> appuyer soi-meme sur la machine
    #  renvoie true si le joueur est elimine
    # =========================================================================
    TourDe(J : player)<suspends> : logic =
        Rasseoir()
        TournerVers(J)
        if (M := Paquets[J], M.Length < PaquetMax, set Paquets[J] = M + array{TirerRelique()}):
            SonCarte.Play()
        Penalite := if (P := Penalites[J]) then P else 0
        if (set Penalites[J] = 0) {}
        var Requis : int = 1 + Bloque + Penalite
        set Bloque = 0
        var Bouclier : logic = false
        var Vu : int = -1
        var Passe : logic = false
        var Elimine : logic = false

        # --- 1. LA CARTE : les 6 cartes a l'ecran (il peut bluffer), ou NO CARD
        Id := ChoisirRelique(J)
        if (Id >= 0):
            Possede := IndexRelique(J, Id)
            Accusateur := Annoncer(J, Id)
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
                    RetirerReliqueAuHasard(A)
                    PA := if (P := Penalites[A]) then P else 0
                    if (set Penalites[A] = PA + 1) {}
                    Bandeau("P{NumeroDe(J)} TOLD THE TRUTH! P{NumeroDe(A)} LOSES A CARD AND +1 BUTTON")
            else:
                Bandeau("NOBODY CALLED LIAR - {NomRelique(Id)} WORKS")
            spawn{ EffacerBandeau(2.5) }
            # s'il avait vraiment la carte, elle est defaussee
            if (Possede >= 0, Effet?):
                RetirerRelique(J, Possede)
            if (Effet?):
                SonCarte.Play()
                if (Id = 0):
                    set Bouclier = true
                else if (Id = 1):
                    set Vu = BoutonSur()
                    Verdir(Vu)
                else if (Id = 2):
                    set Passe = true
                else if (Id = 3):
                    set Sens = -Sens
                else if (Id = 4):
                    set Bloque += 1
                else if (Id = 5):
                    Voler(J)

        # --- 2. LA MACHINE : il vise un bouton (il devient blanc) et clique, Requis fois
        if (not Passe?):
            if (Camera := CamerasClavier[NumeroDe(J) - 1]):
                Camera.AddTo(J)
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
                        set Requis -= 1
            if (Camera := CamerasClavier[NumeroDe(J) - 1]):
                Camera.RemoveFrom(J)
        Surligner(-1)
        Verdir(-1)
        FermerEcrans()
        Elimine

    # il vise avec la camera : le bouton vise devient blanc ; un clic l'enfonce. Temps ecoule : bouton au hasard.
    ViserEtCliquer(J : player, Requis : int, Vu : int, Fin : float)<suspends> : int =
        EcranVisee(J, Requis, Vu)
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

    # STEAL : il regarde un joueur (son nom s'affiche) et clique. Temps ecoule : un joueur au hasard.
    Voler(J : player)<suspends> : void =
        Victimes := for (X : Vivants, X <> J, NombreDe(X) > 0) do X
        if (Victimes.Length = 0):
            Avertir(J, "NOBODY HAS A CARD TO STEAL")
            return
        var Cible : ?player = false
        var Vue : ?player = false
        Fin := GetSimulationElapsedTime() + 10.0
        loop:
            Reste := Fin - GetSimulationElapsedTime()
            if (Reste <= 0.0):
                if (X := Victimes[GetRandomInt(0, Victimes.Length - 1)]):
                    set Cible = option{X}
                break
            Regarde := JoueurVise(J)
            if (V := Regarde?):
                MessagePour(J, "STEAL FROM P{NumeroDe(V)} ({NombreDe(V)} CARDS)? CLICK!")
            else:
                MessagePour(J, "LOOK AT A PLAYER AND CLICK TO STEAL A CARD")
            set Vue = Regarde
            var Clic : logic = false
            race:
                Sleep(0.1)
                loop:
                    A := ClicJoueur.Await()
                    if (player[A] = J):
                        set Clic = true
                        break
            if (Clic?, V := Vue?):
                set Cible = option{V}
                break
        MessagePour(J, "")
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
    ChoisirRelique(J : player)<suspends> : int =
        EcranReliques(J)
        var Id : int = -1
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
            if (Recu >= 100, Recu <= 105):
                set Id = Recu - 100
                break
            if (Recu = 199):
                break
        FermerEcrans()
        Id

    # l'annonce : DureeDefi s pendant lesquelles les autres joueurs en jeu peuvent CLIQUER pour crier LIAR!
    # renvoie le premier accusateur (ou rien)
    Annoncer(J : player, Id : int)<suspends> : ?player =
        set DefiEnCours = true
        set DefiRelique = Id
        set DefiAuteur = NumeroDe(J)
        SonCarte.Play()
        EcranDefi(J)
        var Accuse : ?player = false
        # seul (TEST SOLO) : personne ne peut crier LIAR, on n'attend qu'une seconde
        FinDefi := GetSimulationElapsedTime() + (if (TestSolo?) then 1.0 else DureeDefi)
        loop:
            Reste := FinDefi - GetSimulationElapsedTime()
            MajChronos(Reste)
            if (Reste <= 0.0 or Accuse?):
                break
            var Qui : ?agent = false
            race:
                Sleep(Min(0.5, Reste))
                block:
                    # (pas d'Await dans option{...} : erreur 3512)
                    Cliqueur := ClicJoueur.Await()
                    set Qui = option{Cliqueur}
            if (Ag := Qui?, A := player[Ag], A <> J, Contient(Vivants, A)?):
                set Accuse = option{A}
                Bandeau("P{NumeroDe(A)} SAYS P{NumeroDe(J)} IS LYING!")
                Sleep(1.2)
        set DefiEnCours = false
        FermerEcrans()
        Accuse

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
        if (Anim := AnimAppui?, Perso := J.GetFortCharacter[], Controle := Perso.GetPlayAnimationController[]):
            Controle.Play(Anim)
            Sleep(0.6)
        if (set Enfoncee[K] = true) {}
        if (T := Touches[K], B0 := BaseTouches[K]):
            B := Tournee(B0, LacetMachine)
            Bouger(T, transform{Translation := B.Translation - vector3{X := 0.0, Y := 0.0, Z := Enfoncement}, Rotation := B.Rotation, Scale := B.Scale}, 0.1)
        SonClic.Play()
        Sleep(0.4)

    # piege : la machoire claque (fermee completement), flash rouge pour la victime, puis elle se rouvre
    # et la grille repart a zero
    Croc(J : player)<suspends> : void =
        Axe := if (AxeFermeture = 0) then vector3{X := 1.0, Y := 0.0, Z := 0.0} else if (AxeFermeture = 2) then vector3{X := 0.0, Y := 0.0, Z := 1.0} else vector3{X := 0.0, Y := 1.0, Z := 0.0}
        Lacet := MakeRotation(vector3{X := 0.0, Y := 0.0, Z := 1.0}, DegreesToRadians(LacetMachine))
        PoseG := Tournee(BaseGueule, LacetMachine)
        Fermee := PoseG.Rotation.RotateBy(MakeRotation(Lacet.RotateVector(Axe), DegreesToRadians(AngleFermeture)))
        SonBoom.Play()
        spawn{ FlashRouge(J) }
        Gueule.MoveTo(PoseG.Translation, Fermee, 0.12)
        Bandeau("P{NumeroDe(J)} GOT BITTEN!")
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
            for (J -> T : Chronos):
                T.SetText(TexteJeu("{Max(0, S)}"))

    # ce que tout le monde voit en haut : chrono, danger, sa place, le nombre de cartes des autres
    Entete(J : player, Chrono : text_block) : []canvas_slot =
        var S : []canvas_slot = array{}
        Libres := LibresRestants()
        Risque := if (Libres > 0, P := Floor[PiegesRestants() * 100.0 / (Libres * 1.0) + 0.5]) then P else 0
        set S += array{canvas_slot{Widget := Chrono, Anchors := anchors{Minimum := vector2{X := 0.5, Y := 0.0}, Maximum := vector2{X := 0.5, Y := 0.0}},
            Alignment := vector2{X := 0.5, Y := 0.5}, Offsets := margin{Left := 0.0, Top := 150.0, Right := 0.0, Bottom := 0.0}, SizeToContent := true}}
        set S += array{TexteH("DANGER {Risque}%", 0.5, 0.0, 0.0, 185.0)}
        set S += array{TexteH("YOU ARE P{NumeroDe(J)}", 0.0, 0.0, 120.0, 40.0)}
        var Ligne : float = 80.0
        for (I -> X : Assis, X <> J, Contient(Vivants, X)?):
            set S += array{TexteH("P{I + 1} : {NombreDe(X)} CARD(S)", 0.0, 0.0, 120.0, Ligne)}
            set Ligne += 32.0
        S

    # sa main, en petit, en bas de l'ecran (non cliquable)
    PaquetEnBas(J : player) : []canvas_slot =
        Paquet : []int = if (M := Paquets[J]) then M else array{}
        for (I -> Id : Paquet):
            PlaceH(ImgH(ImageRelique(Id), 200.0, 200.0), 0.5, 1.0, (I * 1.0 - (Paquet.Length - 1) * 0.5) * 150.0, -110.0, 200.0, 200.0)

    Montrer(J : player, S : []canvas_slot, Chrono : text_block, Souris : logic) : void =
        if (UI := GetPlayerUI[J]):
            C := canvas{Slots := S}
            if (Souris?):
                UI.AddWidget(C, player_ui_slot{InputMode := ui_input_mode.All})
            else:
                UI.AddWidget(C)
            if (set Ecrans[J] = C, set Chronos[J] = Chrono) {}

    NouveauChrono() : text_block =
        text_block{DefaultText := TexteJeu(""), DefaultTextColor := color{R := 1.0, G := 0.85, B := 0.2}}

    # DEBUT DU TOUR : le joueur actif voit les 6 cartes (il peut annoncer n'importe laquelle = bluff) ;
    # celles qu'il a vraiment sont marquees. Les autres attendent.
    EcranReliques(Actif : player) : void =
        FermerEcrans()
        for (J : Assis, EstLa(J)?):
            Chrono := NouveauChrono()
            var S : []canvas_slot = Entete(J, Chrono)
            if (J = Actif):
                set S += array{TexteH("YOUR TURN - CLAIM A CARD (YOU CAN BLUFF!)", 0.5, 0.0, 0.0, 110.0)}
                for (Id := 0..5):
                    X := (Id * 1.0 - 2.5) * 250.0
                    Img := ImgH(ImageRelique(Id), 300.0, 300.0)
                    Zone := TEST1{}
                    B := relique_cliquable{Ev := Choix, Fin := FinEcran, Code := 100 + Id, Image := Img, Normale := ImageRelique(Id), Survol := ImageReliqueSurvol(Id), Zone := Zone}
                    spawn{ B.Suivre() }
                    set S += array{PlaceH(Img, 0.5, 0.5, X, -20.0, 300.0, 300.0), PlaceH(Zone, 0.5, 0.5, X, -20.0, 220.0, 290.0)}
                    N := CombienDe(J, Id)
                    if (N > 0):
                        set S += array{TexteH("OWNED x{N}", 0.5, 0.5, X, 150.0)}
                # pas de carte : on passe directement a la machine
                TexteNo := TexteH("NO CARD - GO TO THE MACHINE", 0.5, 0.5, 0.0, 240.0)
                ZoneNo := TEST1{}
                Rien := relique_cliquable{Ev := Choix, Fin := FinEcran, Code := 199, Image := ImgH(ImageRelique(0), 1.0, 1.0), Normale := ImageRelique(0), Survol := ImageRelique(0), Zone := ZoneNo}
                spawn{ Rien.Suivre() }
                set S += array{TexteNo, PlaceH(ZoneNo, 0.5, 0.5, 0.0, 240.0, 520.0, 60.0)}
                Montrer(J, S, Chrono, true)
            else:
                set S += array{TexteH("P{NumeroDe(Actif)} IS CHOOSING A CARD...", 0.5, 0.0, 0.0, 110.0)}
                set S += PaquetEnBas(J)
                Montrer(J, S, Chrono, false)

    # L'ANNONCE : la carte annoncee au centre pour tout le monde ; les autres joueurs en jeu CLIQUENT pour LIAR!
    EcranDefi(Auteur : player) : void =
        FermerEcrans()
        for (J : Assis, EstLa(J)?):
            Chrono := NouveauChrono()
            var S : []canvas_slot = Entete(J, Chrono)
            set S += array{PlaceH(ImgH(ImageRelique(DefiRelique), 380.0, 380.0), 0.5, 0.5, 0.0, -30.0, 380.0, 380.0)}
            if (J = Auteur):
                set S += array{TexteH("YOU CLAIMED {NomRelique(DefiRelique)} - WILL THEY BELIEVE YOU?", 0.5, 0.0, 0.0, 110.0)}
            else if (Contient(Vivants, J)?):
                set S += array{TexteH("P{DefiAuteur} CLAIMS {NomRelique(DefiRelique)}! CLICK TO CALL LIAR!", 0.5, 0.0, 0.0, 110.0)}
            else:
                set S += array{TexteH("P{DefiAuteur} CLAIMS {NomRelique(DefiRelique)}!", 0.5, 0.0, 0.0, 110.0)}
            set S += PaquetEnBas(J)
            Montrer(J, S, Chrono, false)

    # A LA MACHINE : pas de curseur, il vise avec la camera. PEEK : le bouton sur, sur SON ecran seulement.
    EcranVisee(Actif : player, Requis : int, Vu : int) : void =
        FermerEcrans()
        for (J : Assis, EstLa(J)?):
            Chrono := NouveauChrono()
            var S : []canvas_slot = Entete(J, Chrono)
            if (J = Actif):
                set S += array{TexteH("AIM AT A BUTTON AND CLICK - {Requis} TO PRESS", 0.5, 0.0, 0.0, 110.0)}
                if (Vu >= 0):
                    set S += array{TexteH("THE GREEN BUTTON IS SAFE", 0.5, 0.0, 0.0, 225.0)}
            else:
                set S += array{TexteH("P{NumeroDe(Actif)} IS CHOOSING A BUTTON...", 0.5, 0.0, 0.0, 110.0)}
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

    MessagePour(J : player, S : string) : void =
        if (T := Bandeaux[J]):
            T.SetText(TexteJeu(S))
        else if (UI := GetPlayerUI[J]):
            T := text_block{DefaultText := TexteJeu(S), DefaultTextColor := color{R := 1.0, G := 1.0, B := 1.0}}
            UI.AddWidget(canvas{Slots := array{canvas_slot{Widget := T, Anchors := anchors{Minimum := vector2{X := 0.5, Y := 0.0}, Maximum := vector2{X := 0.5, Y := 0.0}},
                Alignment := vector2{X := 0.5, Y := 0.5}, Offsets := margin{Left := 0.0, Top := 60.0, Right := 0.0, Bottom := 0.0}, SizeToContent := true}}})
            if (set Bandeaux[J] = T) {}
