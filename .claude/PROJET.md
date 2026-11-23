# Hot + — Tableau du projet

## État
App macOS légère de barre de menus qui affiche la température du Mac (°C/°F), un verdict normal/chaud et la pression thermique système. Open-source, v0.1 by Ligrade. Premier fil de création lancé le 2026-11-22.

## Fils
| Titre | Id | Modèle | Statut | Livrable |
|---|---|---|---|---|
| Hot + · Application macOS | local_c29db3cf-59bc-4d46-99c2-68099621ef68 | Opus, moyen | en cours | code (Swift/SwiftUI, build.sh, logo) |
| Hot + · Design | local_49b3fe1d-924c-42ac-bcfa-de9344180da2 | Opus, high | fini | logo, icônes dessinées (thermomètre + cadran, plus d'emoji), popover/À propos/Réglages |
| Hot + · Recette | local_b7de9cbe-82d3-4d23-850c-5764428e3971 | Sonnet, moyen | fini | rapport : pas de bug bloquant ; instance unique + message login à corriger |
| Hot + · Application (correctifs) | local_c29db3cf-59bc-4d46-99c2-68099621ef68 | Sonnet, moyen | en cours | instance unique, état « Lancer au démarrage », `build.sh --install` |

## À faire par Driss
- Tester sur son Mac : clic réel sur le menu clic droit et les Réglages, démarrage au login (depuis /Applications), les deux langues, mode clair du système, rouge réel.
- Dire si les icônes (thermomètre + cadran à 3 états) conviennent, ou s'il voulait des visages.

## Décisions de Driss
- 2026-11-22 : nom « Hot + », v0.1, auteur Ligrade, dépôt GitHub « hot-plus », FR + EN, rafraîchissement 1/3/5/10 s, clic droit : À propos / Réglages / Quitter.

- 2026-11-23 : signalement discret en bas du popover quand une app consomme beaucoup (≥ 40 % d'un cœur, app + ses processus d'aide), mesuré seulement popover ouvert.
- 2026-11-23 : détection affinée par workflow (4 agents Opus) : énergie par coalition du noyau (CPU+GPU+ANE+réveils, comme l'onglet Énergie), outil réel nommé (« Claude Code (dans Claude) »), lissage + hystérésis (apparaît à 1,5 W, disparaît sous 0,9 W). Installée dans /Applications.
- 2026-11-23 : la note détaille ce que l'app consomme : CPU (% d'un cœur), GPU (%), RAM (Go, app + ses processus), la valeur qui pèse en orange.
- 2026-11-23 : ordre CPU, RAM, GPU. Clic sur CPU ou RAM → page « Top 5 » qui glisse dans le popover, valeurs en direct (2 s), retour par « ‹ Utilisation ». Plus de top GPU, plus de mini-menu.
- 2026-11-23 : CPU par app affiché en % de tout le processeur (même base que la ligne CPU : 113 % d'un cœur → 11 %), dans le Top 5 et dans la note.
- 2026-11-23 : les apps du Top 5 ne font rien au clic pour l'instant (avant : mise au premier plan, qui fermait le popover).
- 2026-11-23 : la note « consomme beaucoup » suit ses valeurs CPU, GPU, RAM en direct (toutes les 2 s), avec un point vert qui pulse.
- 2026-11-23 : en haut à droite des pages Top 5, la capacité restante (CPU libre en %, RAM disponible en Go).
- 2026-11-23 : première release GitHub v1.1.1 (zip de l'app, signature ad hoc, non notarisée) : https://github.com/Ligrade/hot-plus/releases/tag/v1.1.1

## Règles du projet
- Pas de nom de famille ni d'email de Driss dans le code ou les métadonnées (auteur : Ligrade).
- Pas de dépendance externe ; consommation minimale.
