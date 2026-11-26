# Contexte pour Claude Code

Projet : outils d'un médecin généraliste (Reims) pour automatiser Heidi (transcription) → Dr Santé (logiciel métier). Dépôt partagé avec des confrères, mis à jour automatiquement sur leurs postes.

## Règles impératives

- **Aucune donnée patient** dans le dépôt (ni exemple réel, ni capture). Jamais de `config.ini`, de jeton, de dossier patient.
- Heidi : « ne jamais inventer » — tout prompt garde la règle : rien d'ajouté qui n'a pas été dit en consultation.
- Les raccourcis AHK dépendent des balises du prompt (`[ANAMNESE]…[FIN_DRSANTE]`, `[COURRIER]`, `[KINE]`, `[INFIRMIER]`). Toute modification d'une balise se fait **dans les deux fichiers** (prompt + `scripts/DrSante.ahk`).
- Bloc étiquette : garder les marqueurs `#@ETIQUETTE_DEBUT` / `#@ETIQUETTE_FIN` dans `prompts/heidi_consultation.txt`.
- Fichiers `.ps1` / `.ahk` : UTF-8 **avec BOM** (Windows PowerShell 5.1). `config.ini` : UTF-16 (lu par AHK et PowerShell).
- Après chaque modification validée : `Publier.bat` (commit + push). Les postes se mettent à jour seuls à l'ouverture de Windows.

## Style de travail attendu

Réponses courtes. Quand une action de l'utilisateur est nécessaire : texte exact à copier-coller et geste précis. Débutant en informatique.

## Prochaines étapes (dans cet ordre)

1. `modeles/certificats/` : certificats d'enfant malade, d'aptitude et de contre-indication à une activité physique (+ autres) — améliorer la rédaction, déclencheurs et balises pour collage AHK.
2. `modeles/examens/` : prescriptions d'examens complémentaires — examen demandé, contexte clinique, élément recherché.
3. Intégrer ces modèles au prompt (`prompts/heidi_consultation.txt`) et au script (nouveau raccourci si besoin).
4. Voir `docs/points_a_verifier.md`.
