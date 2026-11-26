# Dr Santé – outils (Heidi → Dr Santé)

Prompts Heidi, raccourcis AutoHotkey et rangement du dossier patient, partagés entre confrères et mis à jour automatiquement.

## Installer sur un nouveau poste (confrère)

Coller dans PowerShell (menu Démarrer → « PowerShell ») :

- Dépôt public : `& ([scriptblock]::Create((irm https://raw.githubusercontent.com/geoffroydg/drsante-outils/main/Installer.ps1)))`
- Dépôt privé : la ligne exacte (avec jeton) est affichée par `Publier.bat`.

L'installateur : installe AutoHotkey v2, demande le dossier patient du poste et l'imprimante à étiquettes (oui/non), crée le démarrage automatique et un raccourci bureau « Copier prompt Heidi ».

## Au quotidien

- Les mises à jour se téléchargent seules à l'ouverture de Windows.
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
