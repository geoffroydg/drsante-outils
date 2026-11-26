# Sécurité — audit du 26/11/2026

Méthode : relecture de tout le code en se mettant à la place d'un attaquant (programme malveillant sur le PC, mauvaise manipulation, compte GitHub compromis). **Aucun test sur un vrai Windows** : les corrections sont à vérifier sur un poste.

## Failles trouvées et corrigées

| # | Gravité | Faille | Correction |
|---|---|---|---|
| 1 | **Critique** | Le dossier patient est vidé définitivement (chaque soir et par Ctrl+Alt+V), en mode administrateur. Si le dossier choisi à l'installation était « Documents », le Bureau, le profil ou une racine de disque, **tout son contenu était supprimé** (et ses sous-dossiers « aplatis »). Même chose si `config.ini` était modifié par un programme malveillant. | Dossiers sensibles refusés (racine, profil, Bureau, Documents, Téléchargements, Windows, Program Files…). Fichier marqueur caché `.dossier_patient_drsante` exigé : posé à l'installation seulement dans un dossier **vide ou nouveau**. Sans marqueur : ni rangement, ni nettoyage, ni Ctrl+Alt+V. |
| 2 | Élevée | Les mises à jour, lancées en mode administrateur, lisaient l'adresse du dépôt dans `config.ini` (modifiable sans droits) : un programme malveillant pouvait faire installer **son propre code en administrateur**. | Dépôt et branche figés dans le code (`Commun.ps1`). Réponse de GitHub vérifiée. Installation de la version exacte vérifiée, archive incomplète refusée. |
| 3 | Élevée | Chemin de P-touch Editor lu dans `config.ini` puis lancé en administrateur : n'importe quel programme pouvait être exécuté. | Seul `ptedit*.exe` situé dans Program Files est accepté ; le modèle doit être un `.lbx` existant. |
| 4 | Élevée (fuite) | Le collage envoyait Ctrl+V dans la fenêtre active : si une autre fenêtre surgissait (messagerie, navigateur, notification), **les données du patient y étaient collées**. | Avant chaque collage : vérification que Dr Santé est au premier plan, sinon arrêt immédiat avec message. |
| 5 | Moyenne (fuite) | Les textes copiés par le script (synthèses Heidi) entraient dans l'historique du presse-papiers Windows (Win+V) et la **synchronisation cloud Microsoft**. | Texte marqué « exclu de l'historique et du cloud ». |
| 6 | Moyenne (sécurité patient) | Après la consultation, la synthèse restait dans le presse-papiers : risque de la coller dans le dossier du **patient suivant**. | Ctrl+Alt+V (fin de consultation) vide aussi le presse-papiers. |
| 7 | Moyenne (fuite) | Étiquettes du carnet de santé (nom, mensurations) gardées **30 jours** dans le dossier temporaire. | Supprimées après 12 h et à chaque démarrage. |
| 8 | Moyenne | Si une erreur survenait pendant le collage d'un courrier, clavier et souris pouvaient rester **bloqués**. | Déblocage garanti dans tous les cas. |
| 9 | Faible | Le jeton GitHub (ancien dépôt privé) passait en clair dans la ligne de commande (visible par les autres programmes). | Supprimé (dépôt public). |
| 10 | Faible | Une valeur contenant un retour à la ligne pouvait ajouter des réglages dans `config.ini`. | Retours à la ligne neutralisés. |
| 11 | Info | Dossier patient dans OneDrive / Dropbox : documents patients copiés sur internet. | Avertissement à l'installation et dans la fenêtre ; par défaut, dossier hors OneDrive. |

## Points solides (vérifiés)

- Le script ne « tape » jamais le texte de Heidi : il colle (Ctrl+V). Une phrase dictée en consultation ne peut donc pas déclencher de commande.
- Aucune donnée patient dans le dépôt, ni dans les journaux (compteurs seulement).
- Connexions uniquement vers GitHub, en HTTPS (TLS 1.2).

## Risques restants (à traiter avec un PC de test)

1. **Compte GitHub = clé de tous les postes.** Quiconque prend le contrôle du compte `geoffroydg` peut publier du code exécuté en administrateur chez tous les confrères. **À faire tout de suite : activer la double authentification** (GitHub → Settings → Password and authentication → Two-factor authentication), ne donner l'accès en écriture à personne.
2. **Dossier d'installation modifiable sans droits.** Le démarrage en administrateur exécute les scripts de `%LOCALAPPDATA%\DrSanteOutils\app`, modifiables par un programme lancé par l'utilisateur. Correction prévue : installer dans Program Files (protégé) et faire les mises à jour par la tâche planifiée. À faire avec un PC de test (risque de casser les mises à jour).
3. **Signature des mises à jour.** Les postes font confiance à GitHub. Possible : signature numérique de chaque version, vérifiée par les postes.
4. **Exe non signé** (alerte Windows SmartScreen) : un certificat de signature de code coûte environ 100 à 300 € par an.
5. Historique Win+V : le texte copié **depuis Heidi** (navigateur) y entre quand même ; désactiver l'historique du presse-papiers sur les postes (Paramètres → Système → Presse-papiers).
