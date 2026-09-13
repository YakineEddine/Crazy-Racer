# Crazy Racer — JOUER (Godot 4.x)

Jeu de kart complet style Mario Kart / KartRider : Course, Grand Prix (4 manches), Contre-la-montre,
14 objets, pieces, drift a paliers, aspiration, caoutchouc IA, audio 100% procedural, records sauvegardes.
Aucun asset externe requis.

## 1. Lancer

1. **Godot 4.2+** (Standard). `Importer` → `project.godot` → `Ouvrir`.
2. **F5** (scene principale : `res://scenes/main.tscn`).

## 2. Modes

- **🏁 COURSE** : format (1v1/Duo/Squad/FFA) + circuit → lobby (salon prive possible) → 3 tours.
- **🏆 GRAND PRIX** : 4 manches enchainees (Neon → Swamp → Glace → Ferme), points 15/12/10/9/8...,
  sacre du champion + compteur de victoires sauvegarde.
- **⏱ CONTRE-LA-MONTRE** : solo, sans objets ni chaos (pieces et pads conserves), records par circuit
  sauvegardes dans `user://crazy_racer.cfg`, fanfare en cas de record.

## 3. Controles

- Clavier : `↑` accelerer (manuel : sans appui le kart s'arrete), `↓` freiner, `←/→` diriger,
  `Espace` drift, `E` objet. Maintenir `↑` pendant le decompte = **depart turbo**.
- Tactile : joystick + `DRIFT` + gros bouton objet, toggle `AUTO` (auto-acceleration une-main).
- Le jeu bascule auto/manuel selon le dernier peripherique touche.

## 4. Systeme de course (façon Mario Kart)

- **Drift a paliers** : etincelles bleues (mini-turbo) → orange (super) → violet (ultra), jauge dans le HUD.
- **Pieces** (lignes sur la piste, max 10) : +1,5% vitesse max chacune, -3 quand on se fait toucher.
- **Pads bleus** : boost a chaque passage. **Aspiration** : reste dans le sillage pour un boost gratuit.
- **Hors-piste** (herbe/sable/eau) : ralenti ×0,62 (velo ×0,8).
- **Roulette** : les boites `?` affichent un tirage qui defile 0,9s avant de donner l'objet.
- **Bots** : remplissent la grille, ramassent et utilisent des objets, caoutchouc (reviennent si largues).

## 5. Objets (14)

Banane, Triple Banane (pieges 6s), Champignon, Triple Champi, Carapace Verte (tout droit),
Carapace Rouge (tete chercheuse), Bouclier (bloque un coup), Etoile (6s invincible + rapide),
Foudre (retrecit tous les adversaires), Pistolet Inverseur (4s), Rayon Reducteur (5s, baignoire),
Pluie de Poulets (3s), Banana Super Boost (+piege), Rocket Pingouin (7s exactement).

## 6. Audio (zero asset)

`Audio` (autoload) : moteur dont le regime suit la vitesse, blips de roulette, fanfares de pieces,
whoosh de boost, bips 3-2-1-GO, impacts — tout est synthetise en WAV au demarrage.

## 7. Design (niveau Mario Kart)

- **Karts modelises** (`vehicle_mesh_builder`) : chassis peint par classe, siege, volant, aileron,
  doubles echappements metal, phares + feu stop, roues pneu+jante qui braquent devant, camion benne,
  moto carenee, velo cadre fin — + pilote casque a visiere (**driver_builder** : humain/croco/pingouin/poulet,
  le Rocket reconstruit un vrai pingouin avec bec et ventre blanc).
- **Pseudo au-dessus des karts** (Label3D), **traces de derapage** au sol, **etincelles** par palier.
- **Circuits thematiques denses** : Neon (26 gratte-ciel + neons, lampadaires, arche lumineuse, lune),
  Swamp (eau centrale, nenuphars, 40 arbres, huttes), Glace (pics translucides, igloos, aurore boreale),
  Ferme (grange, silo, **moulin anime**, clotures, bottes de foin, champ de ble) + vrai ciel degrade,
  bordures, ligne d'arrivee a damier, portique lumineux.
- **UI** : menu en degrade, barres de stats par vehicule au lobby, tour de classement live en course,
  confettis sur les podiums, minimap par equipe.
- **Musique chiptune** generee (C-G-Am-F) + touche **M** ou bouton ♪ pour couper, bruit de derapage.

## 8. Fichiers cles

`scenes/main.tscn` • `autoload/*` (6 + `Audio`) • `scripts/vehicles/vehicle_controller.gd` •
`scripts/items/item_system.gd|projectile.gd|coin.gd|item_box.gd` • `scripts/maps/map_builder.gd` •
`scripts/audio/audio_manager.gd` • `scenes/vehicles/*.tscn` (5) • `scenes/maps/*.tscn` (4) •
`scenes/ui/*.tscn` (5) • `assets/resources/*.tres` (21) • `shaders/gravity_flip.gdshader`
