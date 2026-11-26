# Points à vérifier

1. **Prompt Heidi** : comparer `prompts/heidi_consultation.txt` avec la version v8 utilisée dans Heidi. La ligne « Drapeau rouge = gras + souligné HTML exactement : » doit se terminer par la balise `<u>**texte**</u>` (les balises HTML ont pu disparaître à la copie depuis le projet).
2. **Certificat d'inaptitude** : CORRIGÉ — décret n° 88-977 du 11 octobre 1988 (vérifié : arrêté du 13 septembre 1989 et tableau CNOM 04/2025). Il ne concerne que l'EPS : retiré du certificat de contre-indication au sport en club.
3. **Postes de confrères** : les raccourcis AHK dépendent de la disposition des champs de Dr Santé (nombre de tabulations). À tester sur chaque poste.
4. **Étiquettes** : nécessitent P-touch Editor + SDK b-PAC et le modèle `.lbx` sur le poste concerné.
5. **Certificats** : vérifier que Heidi recopie bien `{NomPrenomPatient}` et `{DateNaissancePatient}` sans les modifier, et que Dr Santé les remplace dans un document de type certificat.
6. **NB du certificat sport** : SUPPRIMÉ à la demande du médecin (contredisait le CNOM : chaque fédération fixe le contenu des examens du CACI).
7. **Nom du médecin** : `{AuteurNomLong}` affiche « Docteur NOM Prénom » (vérifié par le médecin) : pas de « Dr » à ajouter. Heidi double parfois les accolades (`{{…}}`) : corrigé automatiquement au collage.
