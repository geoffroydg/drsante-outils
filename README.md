# Dr Santé – outils (Heidi → Dr Santé)

Prompts Heidi, raccourcis AutoHotkey et rangement du dossier patient, partagés entre confrères et mis à jour automatiquement.

## Installer sur un nouveau poste (confrère)

1. Télécharger **[DrSante-Installation.exe](https://github.com/geoffroydg/drsante-outils/releases/download/installeur/DrSante-Installation.exe)**.
2. Double-cliquer dessus. Si Windows affiche « Windows a protégé votre ordinateur » : **Informations complémentaires** → **Exécuter quand même** (le fichier n'est pas signé numériquement).

Autre méthode (PowerShell, menu Démarrer → « PowerShell ») :
`& ([scriptblock]::Create((irm https://raw.githubusercontent.com/geoffroydg/drsante-outils/main/Installer.ps1)))`

L'exe est fabriqué automatiquement par GitHub (`installeur/Installation.cs`, `.github/workflows/installeur.yml`) et télécharge toujours l'installateur le plus récent : inutile de le refaire après une modification.

L'installateur ouvre une fenêtre : dossier d'installation des outils, dossier patient (choisi ou créé), imprimante à étiquettes, lancement au démarrage de Windows **en mode administrateur** (une seule autorisation Windows, via une tâche planifiée « Dr Sante outils »), icône sur le bureau (facultatif). Il installe AutoHotkey v2 puis ouvre la fenêtre **Dr Santé outils**.

## Fenêtre « Dr Santé outils » (menu Démarrer)

- **Prompt Heidi** : indicateur vert (à jour) ou orange (à copier dans Heidi) selon la version des scripts installés ; bouton « Copier le prompt Heidi » ; affichage du texte.
- **Mises à jour** : vérification et installation en un clic.
- **Ce poste** : dossier patient, mode de démarrage, « Modifier les réglages » (relance l'installateur).
- Rappel des raccourcis clavier.

## Au quotidien

- À l'ouverture de Windows, si une nouvelle version est publiée : une fenêtre propose de l'installer (Oui / Non), sinon reproposée au démarrage suivant. Si le prompt Heidi a changé, elle propose d'ouvrir Dr Santé outils pour le copier.
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
