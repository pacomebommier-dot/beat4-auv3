# État de travail — FIX-01 à FIX-04

Base `2dc3aba`, branche `fix/r10-fix01-04`. Candidate 0.5.14 build 14.
Code final `fe6edf31558fa4c9eb063f92001d4e5bab11b220`.

- Audit, modèle SET, intégration AU et UIKit réalisés.
- 20 exécutables portables et ASan/UBSan passent localement et dans la CI Linux.
- Vérification supplémentaire : 256 masques de positions SET, 2 550 transitions avec doublons, PASS sous ASan/UBSan.
- Revue indépendante : quatre défauts corrigés (STOP avant confirmation START, échec BPM avant START, rappel du SONG actif depuis PC, activation accessible).
- RESET après PC externe et FIFO RESET/PLAY vérifiés en complément.
- XONE retrouvé dans Drive : canal 15, note 12 ; Note On 0 ou Note Off au release.
- Le Mozaic V3 consomme cette note et commute immédiatement le transport. Le V4 fourni conserve LED/mute et laisse BEAT4 décider via les notes brutes reçues du matériel. Compilation Mozaic et recette iPad restent à faire.
- Persistance : huit affectations, curseur, dernière position atteinte, ON/OFF et marqueur RESET. Aucun QUEUE, transport ou SONG actif restauré.
- IPA 0.5.13 historique téléchargée et vérifiée : version/build/arm64 et SHA256 concordants.
- CI finale : https://github.com/pacomebommier-dot/beat4-auv3/actions/runs/43927933565 — SUCCESS : tests natifs et captures UIKit, build iOS et paquet IPA réussis.

Limites : les anciens modes 0/1/2 ne gouvernent déjà plus les rampes dans la
base 0.5.13. Ces rampes sont conservées. In1 garde le protocole Circuit
(confirmations PC 0–63, demandes queued 64–127) ; In2 reçoit les demandes de
contrôleurs indépendants, quantifiées sans déplacement du curseur SET.

STOP LONG est traité avant advance dans le même buffer. RESET exécute d’abord
le QUEUE échu, puis applique la remise du parcours, en conservant l’ordre FIFO
avec les commandes suivantes. Aucun ordre sample-exact intra-buffer promis.

Rapport : FIX01_04_LIVRAISON.md. Recette : FIX01_04_RECETTE.md, À EXÉCUTER.
