# Astris Discord Rich Presence

<img src="Resources/AppIcon.png" width="96" align="right" alt="">

App macOS de barre de menus qui ajoute le Discord Rich Presence à [Astris](https://github.com/V380-Ori/Astris.Binaries), l'émulateur Switch basé sur Ryujinx pour Mac Apple silicon.

**En jeu** : nom du jeu, jaquette, « Sur Astris · 12 h jouées », chrono de session, boutons « Voir sur l'eShop » et « Astris ».
**Dans le menu d'Astris** : « Dans le menu » avec le logo Astris.

## Installation

1. Télécharger `AstrisRPC.dmg` depuis les [Releases](https://github.com/seishiiinsan/astris-discord-rich-presence/releases).
2. L'ouvrir et glisser l'app dans `Applications`.
3. App non notarisée : au 1er lancement, retirer la quarantaine :
   ```bash
   xattr -dr com.apple.quarantine /Applications/AstrisRPC.app
   ```
4. Menu 🎮 → « Lancer au démarrage ».

Prérequis : macOS 13+, Discord desktop lancé.

## Menu

- Icône : manette pleine en jeu, vide sinon, grisée si Astris fermé ou RPC coupé, ⚠︎ si Discord injoignable
- État : jeu en cours, connexion Discord
- Activer Rich Presence
- Lancer au démarrage
- Mettre à jour vers vX (si dispo) / Rechercher les mises à jour… / version

## Mises à jour

L'app vérifie les releases GitHub au lancement puis toutes les 6 h. L'alerte affiche les notes de version. En un clic : télécharge le `.zip`, remplace l'app, la relance. Les erreurs de vérification s'affichent en alerte.

## Fonctionnement

- **Astris** : notifications de lancement/fermeture (`NSWorkspace`) ; aucune vérification tant qu'Astris est fermé.
- **Jeu** : fichier ouvert par Astris (`.xci .xcz .nsp .nsz .nro`), via libproc toutes les 3 s, `lsof` en secours au plus toutes les 6 s. Aucune permission macOS requise.
- **TitleID, titre, temps joué** : `~/Library/Application Support/Astris/games/<TitleID>/gui/metadata.json` (réécrit au lancement du jeu), ou `[01…]` dans le nom du fichier.
- **Jaquette** : 1ʳᵉ image valide parmi tinfoil.media 1024 px, 512 px et api.nlib.cc (TitleID puis jeu de base), sinon logo Astris.
- **Lien eShop** : fiche du jeu via son NSUID (api.nlib.cc), sinon recherche Nintendo.
- **Discord** : socket local `discord-ipc-N`, Client ID dans `AppDelegate.swift`. Discord fermé : nouvel essai après 3 s, 6 s… jusqu'à 60 s, immédiat dès que Discord se relance.
- **Logo Astris** : `Resources/AstrisLogo.png` servi via raw.githubusercontent (repo public requis).

## Build

Prérequis : Xcode ou Command Line Tools.

```bash
./build.sh                 # build/AstrisRPC.app (version lue dans VERSION)
./dmg.sh                   # build/AstrisRPC.dmg
swift test                 # tests
cp -R build/AstrisRPC.app /Applications/
```

## Release

Changer le numéro dans `VERSION` et merger sur `main`. Le workflow `Release` build sur macOS, crée le tag `vX.Y.Z` et publie `.dmg` + `.zip`. Aussi possible : Actions → Release → Run workflow, ou push d'un tag `vX.Y.Z`.

## Structure

```
Sources/AstrisRPC/
  main.swift           point d'entrée (app accessoire, sans Dock)
  AppDelegate.swift    boucle 3 s, menu, construction de la presence
  GameDetector.swift   jeu en cours (lsof + metadata Astris)
  CoverResolver.swift  choix de la jaquette
  EShopResolver.swift  lien eShop du jeu
  DiscordIPC.swift     client IPC Discord minimal
  Updater.swift        mises à jour via GitHub Releases
Tests/AstrisRPCTests/  tests (CI sur chaque PR)
Resources/             icône app, logo Astris
```
