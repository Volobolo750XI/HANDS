#  LES COCHONS DU LOBBY : ils se promenent d'un point de passage a l'autre, au hasard, s'arretent un moment
#  (animation a l'arret), tournent parfois la tete / le corps, puis repartent (animation de marche).
#
#  A INSTALLER DANS UEFN :
#   - pour CHAQUE cochon, 2 appareils "Maillage anime" (Animated Mesh) avec ton modele de cochon :
#       un regle sur l'animation de MARCHE, un regle sur l'animation A L'ARRET (les deux en boucle).
#     Pose les deux au meme endroit. Le code cache celui qui ne sert pas (il le passe sous le sol).
#   - des points de passage : des accessoires (petit cube) INVISIBLES et SANS collision, poses au sol, la ou
#     les cochons peuvent aller. Entre deux points proches, le chemin doit etre libre (pas de mur).
#   - un appareil "cochons_manager" (ce fichier) : remplis les listes ci-dessous.

using { /Fortnite.com/Devices }
using { /Verse.org/Simulation }
using { /Verse.org/Random }
using { /UnrealEngine.com/Temporary/SpatialMath }

cochons_manager := class(creative_device):
    # MEME ORDRE dans les deux listes : CochonsMarche[1] et CochonsRepos[1] = le meme cochon
    @editable CochonsMarche : []animated_mesh_device = array{}
    @editable CochonsRepos : []animated_mesh_device = array{}
    # Les points de passage (accessoires invisibles, sans collision, au sol)
    @editable PointsCochons : []creative_prop = array{}
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

    # les points deja choisis comme destination (deux cochons ne visent pas le meme point)
    var Reserves : []int = array{}

    OnBegin<override>()<suspends> : void =
        for (I -> M : CochonsMarche, R := CochonsRepos[I]):
            spawn{ VieCochon(M, R) }

    Rot(Lacet : float)<transacts> : rotation =
        MakeRotationFromYawPitchRollDegrees(Lacet + CorrectionCochon, 0.0, 0.0)

    SousLeSol(P : vector3)<transacts> : vector3 =
        P + vector3{X := 0.0, Y := 0.0, Z := -10000.0}

    Contient(L : []int, X : int)<transacts> : logic =
        var Trouve : logic = false
        for (Y : L, Y = X):
            set Trouve = true
        Trouve

    # montre le cochon qui marche OU celui a l'arret, a la position Ici
    Afficher(Marche : animated_mesh_device, Repos : animated_mesh_device, Ici : vector3, Lacet : float, EnMarche : logic) : void =
        R := Rot(Lacet)
        if (EnMarche?):
            if (Marche.TeleportTo[Ici, R]) {}
            if (Repos.TeleportTo[SousLeSol(Ici), R]) {}
            Repos.Pause()
            Marche.Play()
        else:
            if (Repos.TeleportTo[Ici, R]) {}
            if (Marche.TeleportTo[SousLeSol(Ici), R]) {}
            Marche.Pause()
            Repos.Play()

    # une destination au hasard parmi les points proches et libres (-1 = aucune)
    ChoisirPoint(Actuel : int, Ici : vector3) : int =
        Candidats := for (K -> P : PointsCochons, K <> Actuel, not Contient(Reserves, K)?, Ecart := P.GetTransform().Translation - Ici, Ecart.Length() <= DistanceMaxCochon) do K
        var Choisi : int = -1
        if (Candidats.Length > 0, C := Candidats[GetRandomInt(0, Candidats.Length - 1)]):
            set Choisi = C
            set Reserves += array{C}
        Choisi

    Liberer(K : int) : void =
        set Reserves = for (X : Reserves, X <> K) do X

    VieCochon(Marche : animated_mesh_device, Repos : animated_mesh_device)<suspends> : void =
        Depart := Repos.GetTransform()
        F := Depart.Rotation.GetLocalForward()
        var Ici : vector3 = Depart.Translation
        var Lacet : float = ArcTan(F.Y, F.X) * 180.0 / PiFloat - CorrectionCochon
        var Actuel : int = -1
        Afficher(Marche, Repos, Ici, Lacet, false)
        # chaque cochon commence a un moment different
        Sleep(GetRandomFloat(0.5, 4.0))
        loop:
            # PAUSE : a l'arret, il bouge la tete (animation), et parfois se tourne un peu
            Sleep(GetRandomFloat(PauseMin, Max(PauseMin, PauseMax)))
            if (GetRandomFloat(0.0, 1.0) < ChanceTourSurPlace):
                set Lacet = Lacet + GetRandomFloat(-70.0, 70.0)
                Repos.MoveTo(Ici, Rot(Lacet), 0.8)
                Sleep(GetRandomFloat(1.0, 3.0))
            # PROMENADE vers un point proche et libre
            Cible := ChoisirPoint(Actuel, Ici)
            if (Pt := PointsCochons[Cible]):
                Dest := Pt.GetTransform().Translation
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
