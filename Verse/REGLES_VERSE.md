# Regles Verse apprises sur ce projet (a relire avant chaque modification)

- 3104 : jamais de signature de fonction coupee sur 2 lignes.
- 3506 : jamais de condition `if (...)` coupee sur plusieurs lignes ; une seule ligne.
- 3506 : `Respawn` vient de `using { /Fortnite.com/FortPlayerUtilities }` et s'appelle sur l'AGENT (`Joueur.Respawn(Pos, Rot)`), pas sur le fort_character.
- 3509 : un `?type` doit etre annote explicitement (`X : ?explosive_device = false`).
- 3509 : `input_trigger_device.ReleasedEvent` envoie `tuple(agent, float)`, pas `agent`.
- 3512 : une fonction appelee dans une condition `if`/`for` doit etre `<transacts>` (ou appelee avant, dans une variable).
- 3532 / 3588 : ne pas reutiliser un nom deja pris par Verse ou par le fichier (`Distance`, `Ecran`...).
- Les degats faits par code : `Victime.Damage(damage_args{Instigator := option{Tireur}, Amount := X})` pour que le kill compte.
- Signal Remote Manager : son "Palier" doit etre la meme rarete que la telecommande donnee.
- 3532 : une variable locale ne doit JAMAIS avoir le nom d'un membre de la classe ou d'une fonction du fichier (verifier avec grep avant).
- 3532 (sens inverse) : un NOUVEAU membre ne doit pas avoir le nom d'une variable locale deja utilisee dans une autre fonction (`PlusProche` existait en local) : grep le nom partout avant de l'ajouter.
- 3532 : ne jamais nommer une variable comme un dossier d'assets (Cartes, Interface, Police, Celebrations...).
- AVANT CHAQUE ENVOI : lancer python3 Outils/verifier_verse.py
- JAMAIS 'not' devant une action qui peut echouer (TeleportTo[...], set...) : Verse annule ses effets. Faire : X := if (Action[]) then true else false ; puis if (not X?).
- 3512 : jamais de fonction <suspends> (Await, Sleep...) DANS option{...} : faire X := Ev.Await() puis option{X}.
- 3509 : un MATERIAU s'utilise avec {} : T.SetMaterial(Dossier.Mon_Materiau{}) (c'est un type, pas une valeur). Les textures, elles, s'utilisent sans {}.
- Verse n'a PAS de 'continue' dans une boucle : utiliser if / else et break.
