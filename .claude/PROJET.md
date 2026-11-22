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

## Règles du projet
- Pas de nom de famille ni d'email de Driss dans le code ou les métadonnées (auteur : Ligrade).
- Pas de dépendance externe ; consommation minimale.
