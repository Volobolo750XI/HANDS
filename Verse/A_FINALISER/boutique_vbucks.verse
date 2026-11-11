# ============================================================================
#  MISE A JOUR 3 - BOUTIQUE V-BUCKS (achats integres, objets durables)
#
#  NE PAS METTRE DANS Content TANT QUE la mise a jour 1 + 2 ne compile pas.
#  Les noms de l'API Epic ci-dessous n'ont pas pu etre verifies (doc inaccessible) : envoie les erreurs.
#  Sans ce fichier, le jeu marche : l'onglet PREMIUM affiche "COMING SOON!".
#  Icones : dossier Boutique (Icone_401, Icone_402, Icone_403, Icone_107).
#
#  A INSTALLER : poser UN appareil "boutique_vbucks" dans la carte (rien a remplir).
#  Avant publication : verifier la regle 4.4 des Developer Rules (chapeau vendu en V-Bucks).
# ============================================================================
using { /Fortnite.com/Devices }
using { /Verse.org/Simulation }
using { /UnrealEngine.com/Marketplace }

TexteVB<localizes>(S : string) : message = "{S}"

# --- LES OBJETS (durables : MaxCount 1, non consommables) ---------------------------------------
machine_demon := class(entitlement):
    Name<override> : message = TexteVB("Demon Machine")
    Description<override> : message = TexteVB("During your turn, the machine turns into a demon machine.")
    ShortDescription<override> : message = TexteVB("Demon machine skin")
    Icon<override> : texture = Boutique.Icone_401
    MaxCount<override> : int = 1
    Consumable<override> : logic = false

machine_doree := class(entitlement):
    Name<override> : message = TexteVB("Golden Machine")
    Description<override> : message = TexteVB("During your turn, the machine turns to gold.")
    ShortDescription<override> : message = TexteVB("Golden machine skin")
    Icon<override> : texture = Boutique.Icone_402
    MaxCount<override> : int = 1
    Consumable<override> : logic = false

machine_arcenciel := class(entitlement):
    Name<override> : message = TexteVB("Rainbow Machine")
    Description<override> : message = TexteVB("During your turn, the machine shines with all the colors.")
    ShortDescription<override> : message = TexteVB("Rainbow machine skin")
    Icon<override> : texture = Boutique.Icone_403
    MaxCount<override> : int = 1
    Consumable<override> : logic = false

couronne_feu := class(entitlement):
    Name<override> : message = TexteVB("Fire Crown")
    Description<override> : message = TexteVB("A crown of flames on your head.")
    ShortDescription<override> : message = TexteVB("Fire crown")
    Icon<override> : texture = Boutique.Icone_107
    MaxCount<override> : int = 1
    Consumable<override> : logic = false

# --- LES OFFRES (prix en V-Bucks) -----------------------------------------------------------------
offre_machine_demon := class(entitlement_offer):
    Name<override> : message = TexteVB("Demon Machine")
    Description<override> : message = TexteVB("During your turn, the machine turns into a demon machine.")
    ShortDescription<override> : message = TexteVB("Demon machine skin")
    Icon<override> : texture = Boutique.Icone_401
    EntitlementType<override> : castable_subtype(entitlement) = machine_demon
    Price<override> : int = 600

offre_machine_doree := class(entitlement_offer):
    Name<override> : message = TexteVB("Golden Machine")
    Description<override> : message = TexteVB("During your turn, the machine turns to gold.")
    ShortDescription<override> : message = TexteVB("Golden machine skin")
    Icon<override> : texture = Boutique.Icone_402
    EntitlementType<override> : castable_subtype(entitlement) = machine_doree
    Price<override> : int = 800

offre_machine_arcenciel := class(entitlement_offer):
    Name<override> : message = TexteVB("Rainbow Machine")
    Description<override> : message = TexteVB("During your turn, the machine shines with all the colors.")
    ShortDescription<override> : message = TexteVB("Rainbow machine skin")
    Icon<override> : texture = Boutique.Icone_403
    EntitlementType<override> : castable_subtype(entitlement) = machine_arcenciel
    Price<override> : int = 1000

offre_couronne_feu := class(entitlement_offer):
    Name<override> : message = TexteVB("Fire Crown")
    Description<override> : message = TexteVB("A crown of flames on your head.")
    ShortDescription<override> : message = TexteVB("Fire crown")
    Icon<override> : texture = Boutique.Icone_107
    EntitlementType<override> : castable_subtype(entitlement) = couronne_feu
    Price<override> : int = 600

# --- LE VENDEUR : appele par la boutique du jeu (onglet PREMIUM) ----------------------------------
# 401 demoniaque, 402 doree, 403 arc-en-ciel, 107 couronne de feu
vendeur_vbucks := class(vendeur_premium):
    Acheter<override>(J : player, Id : int)<suspends> : logic =
        Offre : offer = if (Id = 401) then offre_machine_demon{} else if (Id = 402) then offre_machine_doree{}
            else if (Id = 403) then offre_machine_arcenciel{} else offre_couronne_feu{}
        # la fenetre d'achat Epic s'ouvre ; true = achete
        if (BuyOffer(J, Offre)?) then true else false

# l'appareil a poser dans la carte : il branche le vendeur sur la boutique du jeu
boutique_vbucks := class(creative_device):
    OnBegin<override>()<suspends> : void =
        if (set Vendeurs[GetSession()] = vendeur_vbucks{}) {}
