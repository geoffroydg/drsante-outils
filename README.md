# Dr Santé – outils (Heidi → Dr Santé)

Prompts Heidi, raccourcis AutoHotkey et rangement du dossier patient, partagés entre confrères et mis à jour automatiquement.

## Installer sur un nouveau poste (confrère)

Coller dans PowerShell (menu Démarrer → « PowerShell ») :

- Dépôt public : `& ([scriptblock]::Create((irm https://raw.githubusercontent.com/geoffroydg/drsante-outils/main/Installer.ps1)))`
- Dépôt privé : la ligne exacte (avec jeton) est affichée par `Publier.bat`.

L'installateur ouvre une fenêtre : dossier d'installation des outils, dossier patient (choisi ou créé), imprimante à étiquettes, lancement au démarrage de Windows **en mode administrateur** (une seule autorisation Windows, via une tâche planifiée « Dr Sante outils »), raccourci bureau « Copier prompt Heidi ». Il installe AutoHotkey v2, crée le menu Démarrer « Dr Sante outils » (Copier prompt Heidi, Rechercher une mise à jour) et propose de copier le prompt Heidi. Relancer l'installateur permet de changer ces choix.

## Au quotidien

- À l'ouverture de Windows, si une nouvelle version est publiée : une fenêtre propose de l'installer (Oui / Non). Sans réponse « Oui », elle est reproposée au démarrage suivant.
- Vérification à la demande : menu Démarrer → « Dr Sante outils » → « Rechercher une mise à jour ».
- Si le prompt Heidi change : une fenêtre propose de le copier ; il suffit de le coller dans Heidi.
- Raccourcis (dans Dr Santé) : Ctrl+clic molette = consultation adulte · Alt+clic molette = enfant · Maj+clic molette = courrier · Win+clic molette = kiné · Ctrl+Alt+clic molette = soins infirmiers · Ctrl+Alt+V = vider le dossier patient.

## Pour l'administrateur

Après toute modification : double-clic sur `Publier.bat` (ou demander à Claude Code). Premier lancement : crée le dépôt GitHub (privé par défaut ; `Publier.bat -Public` pour public).

## Contenu

- `prompts/heidi_consultation.txt` : prompt Heidi unique. Le bloc étiquette carnet de santé est entouré de `#@ETIQUETTE_DEBUT` / `#@ETIQUETTE_FIN` : retiré automatiquement sur les postes sans imprimante.
- `scripts/` : AutoHotkey, rangement du dossier patient, démarrage, mise à jour.
- `modeles/` : certificats et prescriptions d'examens (à venir).
- `docs/` : points à vérifier.

Réglages propres à chaque poste : `%APPDATA%\DrSanteOutils\config.ini` (jamais écrasé, jamais publié).

**Aucune donnée patient dans ce dépôt.**
