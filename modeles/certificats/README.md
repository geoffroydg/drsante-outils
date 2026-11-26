# Certificats médicaux

Les modèles sont dans `prompts/heidi_consultation.txt` (déclencheur « 5) CERTIFICAT » et modèle « CERTIFICAT »).
Collage dans Dr Santé : **Alt + Maj + clic molette** (un certificat par appui ; s'il y en a plusieurs, créer un nouveau document entre deux appuis).

## Les 5 modèles

| Repère (1re ligne, non collée) | Quand | Base |
|---|---|---|
| SPORT — ABSENCE DE CONTRE-INDICATION | licence, club, compétition | Code du sport L231-2 ; formule CNOM « pas de signe clinique apparent » |
| SPORT — CONTRE-INDICATION | arrêt du sport en club / loisir | Code de déontologie art. R.4127-76 |
| EPS — INAPTITUDE | dispense de sport à l'école | Décret n° 88-977 du 11 octobre 1988, arrêté du 13 septembre 1989 (totale / partielle, durée ≤ année scolaire, incapacités fonctionnelles) |
| ENFANT MALADE — COLLECTIVITÉ | crèche, assistante maternelle, école, cantine, éviction | Crèche : absence > 4 jours, maladie contagieuse (CNAF 2011-105, arrêté du 3 mai 1989) |
| ENFANT MALADE — PRÉSENCE PARENTALE | justificatif pour l'employeur du parent | Code du travail L1225-61 |

Identité du patient : Heidi écrit `@IDENTITE@`, le script la remplace par les macros Dr Santé `{NomPatient} {PrenomPatient}, né(e) le {DateNaissancePatient},`.

## Règles appliquées (Ordre des médecins, commentaire de l'art. 76)

- Uniquement ce que le médecin a constaté ce jour ; propos rapportés au conditionnel.
- Aucun diagnostic (document remis à un tiers) ; seule exception : « maladie contagieuse » si dit.
- Jamais « en bonne santé » ni « apte » : « pas de signe clinique apparent de contre-indication ».
- Daté du jour de la consultation, jamais antidaté. Durée seulement si dictée.
- Remis en main propre à l'intéressé ou à son représentant légal. Signature manuscrite (pas de cachet seul).

## Rappels pour le médecin (non écrits dans le certificat)

- **Pas de texte qui l'impose** (tableau CNOM mineurs, 04/2025) : absence à l'école ou à la cantine (hors maladie contagieuse), retour à l'école ou à la crèche, absence de crèche < 4 jours, participation au cours d'EPS, sortie scolaire, licence d'un mineur dont le questionnaire QS-Sport est entièrement négatif. Le médecin peut refuser.
- **Disciplines à contraintes particulières** (décret n° 2023-853) : plongée, sports de combat avec KO en compétition, tir / biathlon, sports mécaniques en compétition (sauf karting), motonautisme → certificat de moins d'un an après un **examen médical spécifique**.
- **Majeurs** : chaque fédération décide si un certificat est nécessaire et à quelle fréquence.
- **Sporticlic** (https://www.sporticlic.fr/publications/) : pour chaque sport, contre-indications définitives / temporaires et examens recommandés (ECG, épreuve d'effort…). À consulter pendant l'examen ; rien n'est ajouté automatiquement au certificat.

## Sources (consultées le 26/11/2026)

- CNOM, « Les certificats médicaux pour mineurs » et « … pour majeurs », tableaux mis à jour 04/2025 — conseil-national.medecin.fr, fiches pratiques.
- CNOM, Code de déontologie commenté, article 76 (MAJ février 2024).
- Arrêté du 13 septembre 1989 et son annexe (modèle de certificat d'inaptitude EPS).
- Service-public.fr, « Un certificat médical est-il obligatoire pour faire du sport ? » (vérifié le 30/10/2026).
- Sporticlic (thèse de médecine générale, A. Bargoin, Clermont-Ferrand) — sporticlic.fr.
