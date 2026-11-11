# ============================================================================
#  MISE A JOUR 3 - BOUTIQUE V-BUCKS (achats integres, objets durables)
#  Ecrit a partir du modele officiel d'Epic (marketplace_setup_device).
#
#  A INSTALLER :
#   - ce fichier dans Content (il remplace le modele marketplace_setup_device.verse) ;
#   - les icones dans le dossier Content/Boutique (Icone_401, Icone_402, Icone_403) ;
#   - poser UN appareil "boutique_vbucks" dans la carte (rien a remplir).
#  La boutique du jeu (onglet PREMIUM) l'utilise toute seule.
# ============================================================================
using { /Fortnite.com/Devices }
using { /UnrealEngine.com/Marketplace }
using { /Verse.org/Assets }
using { /Verse.org/Simulation }

# --- LES TEXTES (noms et descriptions affiches par Epic) -----------------------------------------
InfosHands<public> := module:
    MachineDemon<public> := module:
        Name<public><localizes>:message = "Demon Machine"
        Description<public><localizes>:message = "During your turn, the machine turns into a demon machine. Cosmetic only."
        ShortDescription<public><localizes>:message = "Demon machine skin"

    MachineDoree<public> := module:
        Name<public><localizes>:message = "Golden Machine"
        Description<public><localizes>:message = "During your turn, the machine turns to gold. Cosmetic only."
        ShortDescription<public><localizes>:message = "Golden machine skin"

    MachineArcEnCiel<public> := module:
        Name<public><localizes>:message = "Rainbow Machine"
        Description<public><localizes>:message = "During your turn, the machine shines with all the colors. Cosmetic only."
        ShortDescription<public><localizes>:message = "Rainbow machine skin"

# --- LES OBJETS (durables : on les garde pour toujours, purement cosmetiques) --------------------
ObjetsHands<public> := module:
    using {InfosHands}

    # la base de TOUS les objets du jeu
    objet_hands<public> := class<abstract><castable>(entitlement){}

    machine_demon<public> := class<concrete>(objet_hands):
        var Name<override>:message = MachineDemon.Name
        var Description<override>:message = MachineDemon.Description
        var ShortDescription<override>:message = MachineDemon.ShortDescription
        var Icon<override>:texture = Boutique.Icone_401
        PaidRandomItem<override>:logic = false
        PaidArea<override>:logic = false
        ConsequentialToGameplay<override>:logic = false

    machine_doree<public> := class<concrete>(objet_hands):
        var Name<override>:message = MachineDoree.Name
        var Description<override>:message = MachineDoree.Description
        var ShortDescription<override>:message = MachineDoree.ShortDescription
        var Icon<override>:texture = Boutique.Icone_402
        PaidRandomItem<override>:logic = false
        PaidArea<override>:logic = false
        ConsequentialToGameplay<override>:logic = false

    machine_arcenciel<public> := class<concrete>(objet_hands):
        var Name<override>:message = MachineArcEnCiel.Name
        var Description<override>:message = MachineArcEnCiel.Description
        var ShortDescription<override>:message = MachineArcEnCiel.ShortDescription
        var Icon<override>:texture = Boutique.Icone_403
        PaidRandomItem<override>:logic = false
        PaidArea<override>:logic = false
        ConsequentialToGameplay<override>:logic = false

# --- LES OFFRES (prix en V-Bucks, par 50) ----------------------------------------------------------
OffresHands<public> := module:
    using {InfosHands}

    machine_demon<public> := class(entitlement_offer):
        var Name<override>:message = MachineDemon.Name
        var Description<override>:message = MachineDemon.Description
        var ShortDescription<override>:message = MachineDemon.ShortDescription
        var Icon<override>:texture = Boutique.Icone_401
        EntitlementType<override>:concrete_subtype(entitlement) = ObjetsHands.machine_demon
        Price<override>:price_dimension = MakePriceVBucks(600.0)

    machine_doree<public> := class(entitlement_offer):
        var Name<override>:message = MachineDoree.Name
        var Description<override>:message = MachineDoree.Description
        var ShortDescription<override>:message = MachineDoree.ShortDescription
        var Icon<override>:texture = Boutique.Icone_402
        EntitlementType<override>:concrete_subtype(entitlement) = ObjetsHands.machine_doree
        Price<override>:price_dimension = MakePriceVBucks(800.0)

    machine_arcenciel<public> := class(entitlement_offer):
        var Name<override>:message = MachineArcEnCiel.Name
        var Description<override>:message = MachineArcEnCiel.Description
        var ShortDescription<override>:message = MachineArcEnCiel.ShortDescription
        var Icon<override>:texture = Boutique.Icone_403
        EntitlementType<override>:concrete_subtype(entitlement) = ObjetsHands.machine_arcenciel
        Price<override>:price_dimension = MakePriceVBucks(1000.0)

# --- LE VENDEUR : appele par la boutique du jeu (onglet PREMIUM) -----------------------------------
# 401 demoniaque, 402 doree, 403 arc-en-ciel
vendeur_vbucks := class(vendeur_premium):
    Acheter<override>(J : player, Id : int)<suspends> : logic =
        Offre : entitlement_offer = if (Id = 401) then OffresHands.machine_demon{}
            else if (Id = 402) then OffresHands.machine_doree{} else OffresHands.machine_arcenciel{}
        # la fenetre d'achat Epic s'ouvre
        Resultat := BuyOffer(J, Offre)
        if (Resultat?) then true else false

# l'appareil a poser dans la carte : il branche le vendeur sur la boutique du jeu
boutique_vbucks := class(creative_device):
    OnBegin<override>()<suspends> : void =
        if (set Vendeurs[GetSession()] = vendeur_vbucks{}) {}
