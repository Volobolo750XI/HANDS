#  LES COCHONS DU LOBBY : ils se promenent d'un point de passage a l'autre, au hasard, s'arretent un moment
#  (animation a l'arret), tournent parfois la tete / le corps, puis repartent (animation de marche).
#
#  A INSTALLER DANS UEFN :
#   - pour CHAQUE cochon, 2 accessoires (Blueprint de type "Creative Prop" / accessoire creatif) avec ton
#     cochon : un dont l'animation est la MARCHE, un dont l'animation est l'ARRET (les deux en boucle).
#     Pose les deux au meme endroit. Le code cache celui qui ne sert pas.
#   - des points de passage : des accessoires (petit cube) INVISIBLES et SANS collision, poses au sol, la ou
#     les cochons peuvent aller. Entre deux points proches, le chemin doit etre libre (pas de mur).
#   - un appareil "cochons_manager" (ce fichier) : remplis les listes ci-dessous.

using { /Fortnite.com/Devices }
using { /Verse.org/Simulation }
using { /Verse.org/Random }
using { /UnrealEngine.com/Temporary/SpatialMath }

cochons_manager := class(creative_device):
    # Tes accessoires cochon. MEME ORDRE dans les deux listes : CochonsMarche[1] et CochonsRepos[1] = le meme cochon
    @editable CochonsMarche : []creative_prop = array{}
    @editable CochonsRepos : []creative_prop = array{}
    # Les points de passage (accessoires invisibles, sans collision, au sol)
    @editable PointsCochons : []creative_prop = array{}
    # FACULTATIF : les points d'apparition (accessoires invisibles, au sol). Au debut, chaque cochon apparait sur
    # l'un d'eux, tire au hasard (deux cochons jamais au meme). Vide = il apparait la ou tu l'as pose.
    @editable SpawnsCochons : []creative_prop = array{}
    # Vitesse de marche (cm par seconde)
    @editable VitesseCochon : float = 90.0
    # Temps d'arret entre deux promenades (secondes, tire au hasard entre les deux)
    @editable PauseMin : float = 3.0
    @editable PauseMax : float = 8.0
    # Un cochon ne va que vers un point a moins de cette distance (cm) : il ne traverse pas toute la grange
    @editable DistanceMaxCochon : float = 1200.0
    # Si le cochon marche de cote ou a reculons : 90, -90 ou 180
    @editable CorrectionCochon : float = 0.0
    # Chance (0 a 1) qu'il tourne un peu sur place pendant une pause
    @editable ChanceTourSurPlace : float = 0.35
    # Si les cochons flottent ou s'enfoncent : monte (+) ou descends (-) en cm (ex. -40)
    @editable DecalageSol : float = 0.0
    # FACULTATIF : un Lecteur audio par cochon (MEME ORDRE), lecture automatique NON, en boucle NON.
    # Il suit son cochon et joue de temps en temps quand le cochon est a l'arret.
    @editable SonsCochons : []audio_player_device = array{}
    # Chance (0 a 1) qu'il grogne pendant une pause
    @editable ChanceGrogne : float = 0.25

    # les points deja choisis comme destination (deux cochons ne visent pas le meme point)
    var Reserves : []int = array{}
    var SpawnsPris : []int = array{}

    OnBegin<override>()<suspends> : void =
        # SECURITE : les points de passage / d'apparition sont invisibles et sans collision, les grognements ne
        # jouent pas tout seuls au lancement
        for (P : PointsCochons):
            P.Hide()
        for (P : SpawnsCochons):
            P.Hide()
        for (Son : SonsCochons):
            Son.Stop()
        for (I -> M : CochonsMarche, R := CochonsRepos[I]):
            spawn{ VieCochon(I, M, R) }

    Rot(Lacet : float)<transacts> : rotation =
        MakeRotationFromYawPitchRollDegrees(Lacet + CorrectionCochon, 0.0, 0.0)

    Contient(L : []int, X : int)<transacts> : logic =
        var Trouve : logic = false
        for (Y : L, Y = X):
            set Trouve = true
        Trouve

    # montre le cochon qui marche OU celui a l'arret, a la position Ici
    Afficher(Marche : creative_prop, Repos : creative_prop, Ici : vector3, Lacet : float, EnMarche : logic) : void =
        R := Rot(Lacet)
        if (EnMarche?):
            if (Marche.TeleportTo[Ici, R]) {}
            Marche.Show()
            Repos.Hide()
        else:
            if (Repos.TeleportTo[Ici, R]) {}
            Repos.Show()
            Marche.Hide()

    # une destination au hasard parmi les points proches et libres (-1 = aucune)
    ChoisirPoint(Actuel : int, Ici : vector3) : int =
        Candidats := for (K -> P : PointsCochons, K <> Actuel, not Contient(Reserves, K)?, Ecart := P.GetTransform().Translation - Ici, Ecart.X * Ecart.X + Ecart.Y * Ecart.Y <= DistanceMaxCochon * DistanceMaxCochon) do K
        var Choisi : int = -1
        if (Candidats.Length > 0, C := Candidats[GetRandomInt(0, Candidats.Length - 1)]):
            set Choisi = C
            set Reserves += array{C}
        Choisi

    Liberer(K : int) : void =
        set Reserves = for (X : Reserves, X <> K) do X

    VieCochon(I : int, Marche : creative_prop, Repos : creative_prop)<suspends> : void =
        Depart := Repos.GetTransform()
        F := Depart.Rotation.GetLocalForward()
        # la HAUTEUR du cochon ne change jamais : c'est celle ou tu l'as pose (au sol) + DecalageSol ;
        # les points de passage et d'apparition ne donnent que la position au sol (X, Y)
        var Ici : vector3 = Depart.Translation + vector3{X := 0.0, Y := 0.0, Z := DecalageSol}
        var Lacet : float = ArcTan(F.Y, F.X) * 180.0 / PiFloat - CorrectionCochon
        var Actuel : int = -1
        # point d'apparition au hasard parmi ceux encore libres
        Libres := for (K -> S : SpawnsCochons, not Contient(SpawnsPris, K)?) do K
        if (Libres.Length > 0, K := Libres[GetRandomInt(0, Libres.Length - 1)], S := SpawnsCochons[K]):
            set SpawnsPris += array{K}
            P0 := S.GetTransform().Translation
            set Ici = vector3{X := P0.X, Y := P0.Y, Z := Ici.Z}
            set Lacet = GetRandomFloat(-180.0, 180.0)
        # le cochon qui marche est cale sur celui a l'arret (meme position), puis cache
        Afficher(Marche, Repos, Ici, Lacet, false)
        # chaque cochon commence a un moment different
        Sleep(GetRandomFloat(0.5, 4.0))
        loop:
            # PAUSE : a l'arret, il bouge la tete (animation), et parfois se tourne un peu
            Pause := GetRandomFloat(PauseMin, Max(PauseMin, PauseMax))
            # parfois il grogne, a un moment au hasard de sa pause (son a l'endroit du cochon)
            if (Son := SonsCochons[I], GetRandomFloat(0.0, 1.0) < ChanceGrogne):
                Avant := GetRandomFloat(0.0, Pause)
                Sleep(Avant)
                if (Son.TeleportTo[Ici, Rot(Lacet)]) {}
                Son.Play()
                Sleep(Pause - Avant)
            else:
                Sleep(Pause)
            if (GetRandomFloat(0.0, 1.0) < ChanceTourSurPlace):
                set Lacet = Lacet + GetRandomFloat(-70.0, 70.0)
                Repos.MoveTo(Ici, Rot(Lacet), 0.8)
                Sleep(GetRandomFloat(1.0, 3.0))
            # PROMENADE vers un point proche et libre
            Cible := ChoisirPoint(Actuel, Ici)
            if (Pt := PointsCochons[Cible]):
                P1 := Pt.GetTransform().Translation
                Dest := vector3{X := P1.X, Y := P1.Y, Z := Ici.Z}
                V := Dest - Ici
                Dist := V.Length()
                if (Dist > 20.0):
                    # il se tourne d'abord vers sa destination, puis il marche
                    set Lacet = ArcTan(V.Y, V.X) * 180.0 / PiFloat
                    Repos.MoveTo(Ici, Rot(Lacet), 0.6)
                    Afficher(Marche, Repos, Ici, Lacet, true)
                    Marche.MoveTo(Dest, Rot(Lacet), Dist / Max(10.0, VitesseCochon))
                    set Ici = Dest
                    Afficher(Marche, Repos, Ici, Lacet, false)
                Liberer(Actuel)
                set Actuel = Cible
            Sleep(0.1)
