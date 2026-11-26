# Prescriptions d'examens complémentaires

## Imagerie (fait)

Modèle dans `prompts/heidi_consultation.txt` (déclencheur « 2) IMAGERIE », modèle « IMAGERIE »).
Collage dans Dr Santé : **Win + clic molette** → menu des documents → « Imagerie — … » (une ordonnance par modalité).

Pas de titre sur le document (la 1re ligne du bloc, IRM / SCANNER / … / RADIOGRAPHIE, sert seulement de repère dans le menu).

Contenu :
- **Examen** : modalité + zone + côté + incidences / technique, uniquement si cités (une ligne par examen).
- **Contexte clinique** : une seule phrase.
- **Recherche** : hypothèses diagnostiques, uniquement si le médecin les cite (ligne omise sinon).

## Biologie (non prévu)

Volontairement exclue (ordonnance séparée faite par le médecin, hors prompt).
