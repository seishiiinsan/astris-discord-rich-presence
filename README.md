# Astris Discord Rich Presence

App barre de menus macOS qui ajoute le Discord Rich Presence à [Astris](https://github.com/V380-Ori/Astris.Binaries) (émulateur Switch basé sur Ryujinx).

Affiche : nom du jeu, jaquette (via TitleID), temps de jeu. Hors jeu : « Dans le menu ».

## Fonctionnement

- Détecte Astris via les apps lancées (`NSWorkspace`).
- Lit les logs Ryujinx d'Astris et repère `Application Loaded: <Jeu> v<ver> [<TitleID>]`. Aucune permission macOS requise.
- Parle à Discord via le socket local `discord-ipc-N`.
- Jaquette : `https://tinfoil.media/ti/<TitleID>/512/512`.

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
- Choisir dossier logs… (si détection auto échoue)
- Ouvrir log actuel

## Logs

Recherche auto dans `~/Library/Application Support/*{Astris,Ryujinx}*`, `~/Library/Logs`, et `~/Library/Containers/*astris*`. Sinon, choisir le dossier à la main.

Si la fin de partie n'est pas détectée (Astris reste sur le jeu après retour au menu), ouvrir le log et chercher la ligne écrite à l'arrêt, puis l'ajouter à `stopRegex` dans `Sources/AstrisRPC/LogWatcher.swift`.
