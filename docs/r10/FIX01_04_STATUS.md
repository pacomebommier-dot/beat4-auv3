# État de travail — FIX-01 à FIX-04

Base 2dc3aba, branche fix/r10-fix01-04 ; version candidate0.5.14 build14.
Plan : docs/superpowers/plans/2026-11-16-fix01-04.md.

- Audit terminé : voir FIX01_04_AUDIT.md ; source réelle distincte du HTML.
- Modèle SET intégré ; tests de transitions et géométrie ajoutés.
- UIKit et AU intégrés ; commande courte résolue au release (seuil technique0,5s,
  convention UILongPress existante), longue déjàSTOPPED sans redémarrage.
- Revue indépendante :4défauts identifiés et corrigés (START en attente/STOP,
  échecBPM avantSTART, rappelPagePCactif, activation accessible). TestPagePC
  RED puisGREEN ; assertions natives pour les chemins de sortie.
- Vérification supplémentaire : RESET après rappel externe du SONG doit garder
  l'information du terminal atteint. Régression reproduiteRED puis corrigée.
- XONE retrouvé dans Drive : canal15 note12, press/release. ScriptMozaicV3
  immédiat incompatible avec gesteslongs ; intégrationV4 fournie, à compiler
  et tester dans Mozaic suriPad. SessionAUM originale préservée.
- Persistance UserDefaults :8affectations, curseur, dernièrepositionatteinte,
  ON/OFF et marqueurRESET ; niQUEUE, niSTART, niSONGactif restaurés.
- 0.5.13 IPA historique téléchargée et vérifiée : version/build/arm64 etSHA256
  cc218dc7d01a21160782ee4737d756a0693d509142a9336eaeb7ee984b937ea8.
- CI candidate et recette physique : résultats définitifs à compléter aprèsCI.

Limites connues : les modes0/1/2 ne gouvernent déjà plus les rampes dans la base
0.5.13 ; ils n'ont pas été réintroduits sans contrat de migration. PC0–63
Circuit restent des confirmations matérielles immédiates, distinctes des
requêtes64–127 quantifiées surIn1. Les contrôleurs indépendants utilisentIn2 :
leursPC sont des demandes de rappel quantifiées, sans déplacement du curseur. Le SET réutilise strictement l'uniqueQUEUE moteur.
CollisionSTOP/frontière : événements/commandes observés dansbuffer traités avant
advance ; RESET confirmé aprèsadvance. Aucune promesse sample-exact intrabuffer.
Recette matérielle : FIX01_04_RECETTE.md, statutÀEXÉCUTER.
