# Fonctionnalités d'Astris RPC

Tout ce que fait l'app, par usage. Aussi dans l'app : menu → **Fonctionnalités…** (⌘?), avec recherche. Installation, build et release : voir le [README](../README.md).

- [Sur Discord](#sur-discord)
- [Menu](#menu)
- [Réglages](#réglages)
- [Raccourcis et liens](#raccourcis-et-liens)
- [Notifications](#notifications)
- [Statistiques](#statistiques)
- [Jaquettes](#jaquettes)
- [Outils](#outils)
- [Lien avec Astris](#lien-avec-astris)
- [Confidentialité](#confidentialité)
- [Dépannage](#dépannage)
- [Fichiers](#fichiers)

## Sur Discord

| Situation | Ce que voient tes amis |
| --- | --- |
| En jeu | nom du jeu, jaquette avec badge Astris (version, mode TV/portable), « Sur Astris · 12 h jouées », chrono de session, boutons « Voir sur l'eShop » et « Astris » |
| En jeu, multijoueur local actif dans Astris | « … · Multijoueur local » ajouté à la ligne 2 |
| En pause (aucune entrée clavier, souris ou manette pendant le délai choisi) | « En pause · Sur Astris », sans chrono |
| Dans le menu d'Astris | « Dans le menu », logo Astris |
| Jeu masqué (liste noire) | « En jeu · Sur Astris », sans nom ni jaquette |
| Astris fermé ou affichage coupé | rien |

**Textes personnalisables** (Réglages → Discord, ou par jeu dans Réglages → Jeux) :

| Variable | Valeur |
| --- | --- |
| `{game}` | nom du jeu (ou nom affiché perso) |
| `{played}` | temps déjà joué, d'après Astris (« 45 min », « 12 h ») |
| `{version}` | version du jeu (« v1.2.0 », « màj 3 ») |
| `{mode}` | « Mode TV » ou « Mode portable » |
| `{multi}` | « Multijoueur local » si actif dans Astris |
| `{status}` | statut du jeu (À faire, En cours, Terminé, 100 %) |

Les parties séparées par « · » dont la variable n'a pas de valeur sont retirées : `Sur Astris · {played} jouées` devient `Sur Astris` pour un jeu jamais lancé. Champ vide = texte par défaut. Texte d'un jeu > texte global > défaut.

**Boutons** : « Voir sur l'eShop » (fiche du jeu, sinon recherche Nintendo) activable, et un bouton perso (libellé + adresse https) à la place d'« Astris ». Discord ne montre pas les boutons sur ton propre profil, seulement aux autres.

**Limites Discord** gérées : textes coupés à 128 caractères (boutons : 32), boutons sans https retirés. Si Discord refuse quand même, le menu affiche « Discord a refusé l'affichage » avec la raison.

## Menu

Icône de manette dans la barre des menus : pleine en jeu, vide sinon, grisée si Astris est fermé ou l'affichage coupé, ⚠︎ si Discord est fermé pendant qu'Astris tourne. En option, le chrono de session à côté (« 1:24 »).

- **État** : jeu en cours (+ temps déjà joué ou « En pause »), état de Discord ; « Discord fermé — Ouvrir Discord » est cliquable.
- **Lancer un jeu…** (⌃⌥⌘G) : lanceur rapide.
- **Jeux récents** : les 5 derniers jeux, avec jaquette. Un clic les ouvre dans Astris.
- **Favoris** : les jeux étoilés.
- **Dernière capture** : copier ou afficher la dernière capture faite dans Astris.
- **Manettes** : manettes connectées et batterie (« Pro Controller · 80 % »).
- **Afficher sur Discord** (⌃⌥⌘D).
- **Masquer ce jeu sur Discord** (⌃⌥⌘H), en jeu seulement.
- **Mode streamer**.
- **Réglages…** (⌘,).
- **Mises à jour** : « Mettre à jour vers vX » quand une version sort, « Rechercher les mises à jour… », version installée.
- **Fonctionnalités…** (⌘?) : cette page, dans l'app.
- **Copier le diagnostic**.
- **Quitter Astris RPC**.

## Réglages

### Général

- Afficher mon jeu sur Discord.
- Ouvrir à la connexion.
- Chrono de session dans la barre des menus.
- Raccourcis clavier globaux (⌃⌥⌘D, ⌃⌥⌘H, ⌃⌥⌘G).
- Afficher « En pause » après : jamais, 5, 10, 15 (défaut) ou 30 min.
- Langue : comme le Mac, français ou anglais (appliquée au relancement, bouton « Relancer »).
- Dossier des jeux : repris d'Astris au premier lancement, modifiable.
- Notifications : Discord déconnecté, mise à jour, bilan de la semaine, paliers et records, batterie de manette, rappel de pause.
- Dépannage : journal sur disque, vider le cache des jaquettes.

### Discord

- Lignes 1 et 2 (variables ci-dessus).
- Mode streamer et ce qu'il cache : temps joué, bouton eShop, jaquettes.
- SteamGridDB : clé API, « Préférer SteamGridDB ».
- Boutons : eShop, bouton perso.

### Jeux

Liste des jeux du dossier (`.xci .xcz .nsp .nsz .nro`, jusqu'à 3 niveaux de sous-dossiers), avec jaquette, recherche, ★ et œil barré pour les jeux masqués. Filtre (tous, favoris, par statut), tri par nom ou par taille, taille totale du dossier, doublons signalés (même jeu de base ou même nom), « Mise à jour dispo » quand une version plus récente que celle installée existe (api.nlib.cc, revérifié chaque jour).

- **Double-clic** ou **Lancer dans Astris** : ouvre le jeu.
- **Clic droit** : lancer, favori, afficher dans le Finder.
- Par jeu :
  - suivi : statut (À faire, En cours, Terminé, 100 %), note sur 5, mémo ;
  - afficher sur Discord ou masquer (liste noire) ;
  - cacher le temps joué ;
  - texte propre au jeu (lignes 1 et 2) ;
  - nom affiché ;
  - jaquette perso : adresse https, ou image glissée sur la jaquette ou choisie (une image locale n'est visible que dans l'app, Discord n'accepte que des images en ligne) ;
  - favori ;
  - type (jeu de base, mise à jour, DLC), TitleID et version.

Les réglages d'un jeu suivent le nom du fichier : déplacer le dossier ne les perd pas.

### Statistiques

Voir [Statistiques](#statistiques).

## Raccourcis et liens

**Raccourcis globaux** (partout dans macOS, sans permission Accessibilité, désactivables) :

| Raccourci | Effet |
| --- | --- |
| ⌃⌥⌘D | afficher / couper l'affichage sur Discord |
| ⌃⌥⌘H | masquer / réafficher le jeu en cours |
| ⌃⌥⌘G | lanceur rapide : tape un nom, ↑↓, ↩︎ pour lancer, esc pour fermer |

**Liens `astrisrpc://`**, pour Raccourcis, Raycast, Alfred ou le Terminal (`open "astrisrpc://toggle"`) :

| Lien | Effet |
| --- | --- |
| `astrisrpc://on` · `off` · `toggle` | affichage sur Discord |
| `astrisrpc://hide-game` | masquer / réafficher le jeu en cours |
| `astrisrpc://streamer` | basculer le mode streamer (`?on=1` / `?on=0` pour forcer) |
| `astrisrpc://launch?game=Zelda` | lancer un jeu par son nom (récents, favoris, puis dossier des jeux) |
| `astrisrpc://settings` | ouvrir les Réglages |

## Notifications

Activables une par une dans Réglages → Général (macOS demande l'autorisation au premier lancement) :

- **Discord déconnecté** pendant que ton jeu était affiché. Nouvel essai automatique : 3 s, 6 s… jusqu'à 60 s, immédiat quand Discord se relance.
- **Mise à jour disponible**, une fois par version.
- **Bilan de la semaine**, le dimanche à partir de 19 h : « 8 h 20 cette semaine sur 3 jeux, surtout Zelda (5 h 10). »
- **Paliers** : 10, 25, 50, 100, 200 et 500 h sur un jeu (une fois chacun), et **record** quand la session dépasse la plus longue jamais comptée (30 min au moins).
- **Rappel de pause** : « Tu joues depuis 2 h », toutes les 1 h, 1 h 30, 2 h ou 3 h (désactivé par défaut).
- **Batterie de manette** sous 20 %, une fois par décharge.
- **Captures d'écran** faites dans Astris (Réglages → Outils), avec copie automatique dans le presse-papiers en option.

## Statistiques

Temps compté par Astris RPC quand un jeu tourne, pauses exclues (une coupure de plus de 60 s démarre une nouvelle session).

- Cette semaine, au total, nombre de jeux lancés.
- Graphe sur 7 jours ou 4 semaines.
- Par jeu : temps total, temps cette semaine, temps compté par Astris à côté (« Astris : 120 h 00 »), dernière partie.
- Tri : plus joué ou plus récent.
- Export CSV (une ligne par session : jeu, fichier, TitleID, début, fin, minutes).
- Effacer l'historique.

## Jaquettes

Ordre de recherche :

1. jaquette perso du jeu (si https) ;
2. tinfoil.media 1024 px puis 512 px, puis api.nlib.cc, avec le TitleID puis celui du jeu de base (pour les mises à jour et les DLC) ;
3. SteamGridDB par nom du jeu, si une clé est réglée (ou en premier avec « Préférer SteamGridDB ») : couvre aussi les homebrew et les jeux sans TitleID ;
4. logo Astris.

Les adresses trouvées sont gardées 30 jours, les absences 3 jours. Une absence due à une coupure réseau n'est pas retenue. Les images ne sont téléchargées qu'une fois.

## Outils

Réglages → Outils.

- **Captures d'écran** : notification, copie automatique, ouvrir le dossier des captures d'Astris.
- **Sauvegardes des jeux** : zip des saves d'Astris (`bis/user/save`) dans `~/Documents/Astris RPC/Sauvegardes`, à la demande, à la fermeture d'un jeu ou chaque semaine (défaut). Les 20 dernières sont gardées. **Restaurer** (Astris fermé) remet une sauvegarde et garde les saves actuelles à côté (« save before restore … »).
- **Export / import des réglages** : un fichier `.astrisrpc` avec tous les réglages, les réglages par jeu, les favoris et l'historique de jeu. L'import remplace tout et relance l'app.

## Lien avec Astris

Rien à configurer, et aucune permission macOS :

- **Jeu en cours** : fichier ouvert par Astris, vérifié toutes les 3 s tant qu'Astris tourne.
- **Titre, TitleID, temps joué** : `games/<TitleID>/gui/metadata.json` d'Astris.
- **Version** : mise à jour choisie dans Astris (`updates.json`), sinon nom du fichier (`[v1.2.0]`, `[v196608]` → màj 3).
- **Config.json d'Astris** : dossier des jeux, mode TV/portable, multijoueur local.
- **Favoris d'Astris** : importés une fois par jeu. Retirer l'étoile dans l'app est respecté.

## Confidentialité

- **Liste noire** par jeu : « En jeu · Sur Astris » sans nom ni jaquette.
- **Mode streamer** : cache d'un coup temps joué, bouton eShop et/ou jaquettes, sur tous les jeux.
- **Temps joué** masquable par jeu.
- ⌃⌥⌘H masque le jeu en cours sans ouvrir les Réglages.
- Rien ne sort du Mac sauf vers Discord (socket local), les sources de jaquettes, api.nlib.cc (lien eShop) et GitHub (mises à jour). Le diagnostic ne contient que des noms de fichiers, jamais de chemins complets.

## Dépannage

- **Copier le diagnostic** (menu) : version, macOS, état d'Astris et de Discord, dernier refus de Discord, jeu, TitleID, version, sources de jaquette, pause, presence envoyée, dossiers Astris trouvés, taille du cache, journal récent. À coller dans une issue.
- **Journal** : 300 derniers événements en mémoire, et sur disque si activé (`~/Library/Logs/AstrisRPC.log`, remis à zéro au-delà de 1 Mo).
- **Vider le cache des jaquettes** si une image reste fausse.
- **Mises à jour** : vérifiées au lancement puis toutes les 6 h. En un clic : téléchargement, remplacement de l'app, relance.

## Fichiers

| Emplacement | Contenu |
| --- | --- |
| Préférences (`defaults read com.seishin.astris-rpc`) | réglages, réglages par jeu, favoris, jeux récents |
| `~/Library/Application Support/AstrisRPC/history.json` | sessions de jeu (statistiques) |
| `~/Library/Application Support/AstrisRPC/Covers/` | jaquettes perso importées |
| `~/Library/Caches/AstrisRPC/` | adresses de jaquettes, liens eShop, SteamGridDB, images |
| `~/Library/Logs/AstrisRPC.log` | journal (si activé) |
| `~/Documents/Astris RPC/Sauvegardes/` | sauvegardes des saves |
