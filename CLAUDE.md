# Contexte pour Claude Code

Projet : outils d'un médecin généraliste (Reims) pour automatiser Heidi (transcription) → Dr Santé (logiciel métier). Dépôt partagé avec des confrères, mise à jour proposée sur leurs postes.

## Règles impératives

- **Aucune donnée patient** dans le dépôt (ni exemple réel, ni capture). Jamais de `config.ini`, de jeton, de dossier patient.
- Heidi : « ne jamais inventer » — tout prompt garde la règle : rien d'ajouté qui n'a pas été dit en consultation.
- Les raccourcis AHK dépendent des balises du prompt (`[ANAMNESE]…[FIN_DRSANTE]`, `[COURRIER]`, `[KINE]`, `[INFIRMIER]`, `[CERTIFICAT]`, `[IMAGERIE]`). Toute modification d'une balise se fait **dans les deux fichiers** (prompt + `scripts/DrSante.ahk`).
- Bloc étiquette : garder les marqueurs `#@ETIQUETTE_DEBUT` / `#@ETIQUETTE_FIN` dans `prompts/heidi_consultation.txt`.
- Fichiers `.ps1` / `.ahk` : UTF-8 **avec BOM** (Windows PowerShell 5.1). `config.ini` : UTF-16 (lu par AHK et PowerShell).
- **Publication en 2 temps** : toute modification va d'abord sur la branche `test` (reçue seulement par le poste du testeur, Dr Dagher : Ctrl+Maj+T dans la fenêtre Dr Santé outils). Les confrères (branche `main`) ne la reçoivent qu'après validation : bouton « Valider pour les confrères » → workflow GitHub `valider.yml` (avance rapide de `main` jusqu'à `test`). Ne jamais pousser directement sur `main`.
- Sécurité : voir `docs/securite.md` (garde-fous du dossier patient, source des mises à jour figée dans `Commun.ps1`, collage limité à la fenêtre Dr Santé).

Raccourcis : Maj+clic molette = courrier ; tous les autres documents passent par le menu Win+clic molette (`MenuDocumentsDrSante` / `ListerDocuments` dans `scripts/DrSante.ahk`). Un nouveau document = une nouvelle balise ajoutée à `ListerDocuments`, pas un nouveau raccourci.

## Style de travail attendu

Réponses courtes. Quand une action de l'utilisateur est nécessaire : texte exact à copier-coller et geste précis. Débutant en informatique.

## Prochaines étapes (dans cet ordre)

1. `modeles/certificats/` : FAIT (5 modèles dans le prompt, balises `[CERTIFICAT]`, menu Win+clic molette). Reste : test réel dans Heidi et Dr Santé, autres certificats si besoin.
2. `modeles/examens/` : imagerie FAITE (balises `[IMAGERIE]`, menu Win+clic molette). Reste : biologie si souhaitée, test réel.
3. Intégrer ces modèles au prompt (`prompts/heidi_consultation.txt`) et au script (nouveau raccourci si besoin).
4. Voir `docs/points_a_verifier.md`.
