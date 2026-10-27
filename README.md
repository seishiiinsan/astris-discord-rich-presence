# Astris Discord Rich Presence

App barre de menus macOS qui ajoute le Discord Rich Presence à [Astris](https://github.com/V380-Ori/Astris.Binaries) (émulateur Switch basé sur Ryujinx).

Affiche : nom du jeu, jaquette (via TitleID), temps de jeu. Hors jeu : « Dans le menu ».

## Fonctionnement

- Détecte Astris via les apps lancées (`NSWorkspace`).
- Repère le jeu ouvert par Astris (`lsof` : `.xci/.xcz/.nsp/.nsz/.nro`) et son TitleID via `~/Library/Application Support/Astris/games/<TitleID>/gui/metadata.json` (modifié au lancement). Aucune permission macOS requise.
- Parle à Discord via le socket local `discord-ipc-N`.
- Jaquette : `https://tinfoil.media/ti/<TitleID>/512/512`.

## Installation

Télécharger `AstrisRPC.zip` depuis les [Releases](https://github.com/seishiiinsan/astris-discord-rich-presence/releases), dézipper, mettre dans `/Applications`. App non notarisée : au 1er lancement, retirer la quarantaine :

```bash
xattr -dr com.apple.quarantine /Applications/AstrisRPC.app
```

Nouvelle release : Actions → Release → Run workflow (saisir la version), ou `git tag vX.Y.Z && git push origin vX.Y.Z`.

## Build

Prérequis : macOS 13+, Xcode ou Command Line Tools.

```bash
./build.sh
cp -R build/AstrisRPC.app /Applications/
open /Applications/AstrisRPC.app
```

Puis menu 🎮 → « Lancer au démarrage ».

## Menu

- État jeu / Discord
- Activer Rich Presence
- Lancer au démarrage
