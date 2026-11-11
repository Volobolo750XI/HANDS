# ============================================================================
#  MISE A JOUR 3 - BOUTIQUE V-BUCKS (achats integres, objets durables)
#
#  NE PAS METTRE DANS Content TANT QUE :
#   1. les ICONES existent (dossier Boutique : Icone_MachineDoree, Icone_MachineDemon, Icone_MachineNoel,
#      Icone_CouronneFeu, Icone_Strobe) - fournies par l'autre Claude ;
#   2. ce fichier compile (les noms de l'API Epic ci-dessous n'ont pas pu etre verifies : doc inaccessible).
#  Sans ce fichier, le jeu marche : l'onglet PREMIUM affiche "COMING SOON!".
#
#  A INSTALLER : poser UN appareil "boutique_vbucks" dans la carte (rien a remplir).
#  Avant publication : verifier la regle 4.4 des Developer Rules (chapeaux vendus en V-Bucks).
# ============================================================================
using { /Fortnite.com/Devices }
using { /Verse.org/Simulation }
using { /UnrealEngine.com/Marketplace }

TexteVB<localizes>(S : string) : message = "{S}"

# --- LES OBJETS (durables : MaxCount 1, non consommables) ---------------------------------------
machine_doree := class(entitlement):
    Name<override> : message = TexteVB("Golden Machine")
    Description<override> : message = TexteVB("During your turn, the machine turns to gold.")
    ShortDescription<override> : message = TexteVB("Golden machine skin")
    Icon<override> : texture = Boutique.Icone_MachineDoree
    MaxCount<override> : int = 1
    Consumable<override> : logic = false

machine_demon := class(entitlement):
    Name<override> : message = TexteVB("Demon Machine")
    Description<override> : message = TexteVB("During your turn, the machine gets red eyes and smoke.")
    ShortDescription<override> : message = TexteVB("Demon machine skin")
    Icon<override> : texture = Boutique.Icone_MachineDemon
    MaxCount<override> : int = 1
    Consumable<override> : logic = false

machine_noel := class(entitlement):
    Name<override> : message = TexteVB("Xmas Machine")
    Description<override> : message = TexteVB("During your turn, the machine is dressed for Christmas.")
    ShortDescription<override> : message = TexteVB("Christmas machine skin")
    Icon<override> : texture = Boutique.Icone_MachineNoel
    MaxCount<override> : int = 1
    Consumable<override> : logic = false

couronne_feu := class(entitlement):
    Name<override> : message = TexteVB("Fire Crown")
    Description<override> : message = TexteVB("An animated crown of flames on your head.")
    ShortDescription<override> : message = TexteVB("Animated fire crown")
    Icon<override> : texture = Boutique.Icone_CouronneFeu
    MaxCount<override> : int = 1
    Consumable<override> : logic = false

lampe_strobe := class(entitlement):
    Name<override> : message = TexteVB("Strobe Lamp")
    Description<override> : message = TexteVB("The lamp above the table flashes during your turn.")
    ShortDescription<override> : message = TexteVB("Flashing lamp")
    Icon<override> : texture = Boutique.Icone_Strobe
    MaxCount<override> : int = 1
    Consumable<override> : logic = false

# --- LES OFFRES (prix en V-Bucks) -----------------------------------------------------------------
offre_machine_doree := class(entitlement_offer):
    Name<override> : message = TexteVB("Golden Machine")
    Description<override> : message = TexteVB("During your turn, the machine turns to gold.")
    ShortDescription<override> : message = TexteVB("Golden machine skin")
    Icon<override> : texture = Boutique.Icone_MachineDoree
    EntitlementType<override> : castable_subtype(entitlement) = machine_doree
    Price<override> : int = 800

offre_machine_demon := class(entitlement_offer):
    Name<override> : message = TexteVB("Demon Machine")
    Description<override> : message = TexteVB("During your turn, the machine gets red eyes and smoke.")
    ShortDescription<override> : message = TexteVB("Demon machine skin")
    Icon<override> : texture = Boutique.Icone_MachineDemon
    EntitlementType<override> : castable_subtype(entitlement) = machine_demon
    Price<override> : int = 1000

offre_machine_noel := class(entitlement_offer):
    Name<override> : message = TexteVB("Xmas Machine")
    Description<override> : message = TexteVB("During your turn, the machine is dressed for Christmas.")
    ShortDescription<override> : message = TexteVB("Christmas machine skin")
    Icon<override> : texture = Boutique.Icone_MachineNoel
    EntitlementType<override> : castable_subtype(entitlement) = machine_noel
    Price<override> : int = 600

offre_couronne_feu := class(entitlement_offer):
    Name<override> : message = TexteVB("Fire Crown")
    Description<override> : message = TexteVB("An animated crown of flames on your head.")
    ShortDescription<override> : message = TexteVB("Animated fire crown")
    Icon<override> : texture = Boutique.Icone_CouronneFeu
    EntitlementType<override> : castable_subtype(entitlement) = couronne_feu
    Price<override> : int = 600

offre_lampe_strobe := class(entitlement_offer):
    Name<override> : message = TexteVB("Strobe Lamp")
    Description<override> : message = TexteVB("The lamp above the table flashes during your turn.")
    ShortDescription<override> : message = TexteVB("Flashing lamp")
    Icon<override> : texture = Boutique.Icone_Strobe
    EntitlementType<override> : castable_subtype(entitlement) = lampe_strobe
    Price<override> : int = 400

# --- LE VENDEUR : appele par la boutique du jeu (onglet PREMIUM) ----------------------------------
vendeur_vbucks := class(vendeur_premium):
    Acheter<override>(J : player, Id : int)<suspends> : logic =
        Offre : offer = if (Id = 401) then offre_machine_doree{} else if (Id = 402) then offre_machine_demon{}
            else if (Id = 403) then offre_machine_noel{} else if (Id = 107) then offre_couronne_feu{} else offre_lampe_strobe{}
        # la fenetre d'achat Epic s'ouvre ; true = achete
        if (BuyOffer(J, Offre)?) then true else false

# l'appareil a poser dans la carte : il branche le vendeur sur la boutique du jeu
boutique_vbucks := class(creative_device):
    OnBegin<override>()<suspends> : void =
        if (set Vendeurs[GetSession()] = vendeur_vbucks{}) {}
