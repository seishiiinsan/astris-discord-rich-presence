# Astris Discord Rich Presence

App barre de menus macOS qui ajoute le Discord Rich Presence à [Astris](https://github.com/V380-Ori/Astris.Binaries) (émulateur Switch basé sur Ryujinx).

Affiche : nom du jeu, jaquette (via TitleID), chrono de session, temps total joué (`timespan_played` d'Astris), boutons « Voir sur l'eShop » / « Astris ». Hors jeu : « Dans le menu ».

## Fonctionnement

- Détecte Astris via les apps lancées (`NSWorkspace`).
- Repère le jeu ouvert par Astris (`lsof` : `.xci/.xcz/.nsp/.nsz/.nro`) et son TitleID via `~/Library/Application Support/Astris/games/<TitleID>/gui/metadata.json` (modifié au lancement). Aucune permission macOS requise.
- Parle à Discord via le socket local `discord-ipc-N`.
- Jaquette : 1ʳᵉ image valide parmi tinfoil.media et api.nlib.cc (TitleID puis jeu de base), sinon logo Astris.
- Logo Astris (menu) : `Resources/AstrisLogo.png` servi via raw.githubusercontent.

## Installation

Télécharger `AstrisRPC.dmg` depuis les [Releases](https://github.com/seishiiinsan/astris-discord-rich-presence/releases), l'ouvrir, glisser l'app dans `Applications`. App non notarisée : au 1er lancement, retirer la quarantaine :

```bash
xattr -dr com.apple.quarantine /Applications/AstrisRPC.app
```

Nouvelle release : changer `VERSION` sur `main` (ou Actions → Release → Run workflow, ou push d'un tag `vX.Y.Z`). La CI build et publie.

## Build

Prérequis : macOS 13+, Xcode ou Command Line Tools.

```bash
./build.sh   # puis ./dmg.sh pour un .dmg
cp -R build/AstrisRPC.app /Applications/
open /Applications/AstrisRPC.app
```

Puis menu 🎮 → « Lancer au démarrage ».

## Menu

- État jeu / Discord
- Activer Rich Presence
- Lancer au démarrage
