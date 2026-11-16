# BEAT4 R10 — FIX-01 à FIX-04 — candidate 0.5.14 build 14

16 novembre 2026. **Aucun test physique iPad/AUM/XONE effectué ici.**

- Branche : `fix/r10-fix01-04`.
- Commit du code et du build final : `fe6edf31558fa4c9eb063f92001d4e5bab11b220`.
- Base : `2dc3abac3b3a8af8f2019a2e56666f4d9e69a919`, dernière branche 0.5.13.
- PR : https://github.com/pacomebommier-dot/beat4-auv3/pull/6

Aucun merge dans main. Les branches et anciennes livraisons sont conservées.

## Audit et changements

| Élément | État initial | Changement réel |
|---|---|---|
| FIX-01 | symbole petit et décentré sur iPad | Police 28 × scale hors portrait, contre 24 auparavant ; centré sur UNKNOWN. Aucun changement MIDI par cette retouche. |
| FIX-02 | Centres et tailles SAVE / ACTIF STEPS différents | Même hauteur et même police ; logique STEPS et SAVE conservée. |
| FIX-03 | Titre passif, navigation par swipe | Tap du titre : MÉTRONOME → PC 01–32 → PC 33–64 → MÉTRONOME. Swipe supprimé. Aucun appel moteur lors du changement de vue. |
| FIX-04, interface | SET absent | Huit mini-pads fixes sur UNE ligne du titre ; hauteur limitée à 0,65 × la police, vérifiée aussi par rapport à capHeight UIKit. Toujours visibles ON/OFF ; zones tactiles distinctes. SET et `/` sur UNKNOWN. |
| FIX-04, moteur | SET absent | Huit positions, vides ignorés, doublons par occurrence, fin sans boucle ni STOP. Curseur, SONG actif, origine et occurrence en attente séparés. |
| Édition | Absente | Choisir un pad puis un SONG sur les pages PC ; appui long pour supprimer ; sauvegarde automatique ; `/` termine. Aucun SAVE supplémentaire. |
| QUEUE | Un seul QUEUE historique | Réutilisation de ProgramEngine.selected. PLAY répétés depuis l’occurrence déjà demandée. Un PC indépendant ne déplace pas le curseur SET. |
| RESET | Absent | Confirmation explicite ; affectations et QUEUE conservés. Terminal atteint mémorisé. À la frontière, QUEUE exécuté avant RESET ; FIFO préservé si PLAY suit RESET dans le même buffer. |
| XONE | Toggle Mozaic immédiat au press | Note 12, canal 15 ; Note On à vélocité zéro ou Note Off au release. Seuil technique 0,5 s, aucun NEXT au press. Script V4 fourni pour préserver LED et mute. |
| BPM à l’arrêt | Rappeler le SONG déjà actif sautait son BPM | Défaut reproduit et corrigé. PC/BPM avant START ; START bloqué si l’envoi du BPM échoue. |
| Persistance | SONGS uniquement | Huit affectations, ON/OFF, curseur, dernière position atteinte et marqueur RESET. Aucun QUEUE ou START périmé restauré. |

L’audit détaillé est dans `FIX01_04_AUDIT.md`. Le paquet Drive préexistant
BEAT4_CODEX_PAQUET_R10.zip, daté du 13 novembre, contient seulement HTML/CSS/JS
et documents : aucune source AUv3 non publiée. Le clone Git initial était propre.
La référence HTML protégée a été lue via Vercel ; elle reste la référence graphique.

L’ancienne IPA 0.5.13 a été téléchargée et vérifiée : app et extension arm64,
version/build 13, SHA256 `cc218dc7d01a21160782ee4737d756a0693d509142a9336eaeb7ee984b937ea8`.

## Vérifications

- 20 exécutables C++ : PASS local et CI Linux.
- ASan/UBSan : PASS local et CI. La détection de fuites est désactivée localement, car non prise en charge dans ce conteneur.
- Vérificateur de paquet IPA : test de régression PASS ; vérification du vrai paquet final 0.5.14/build 14 vérifié après téléchargement : PASS.
- Vérification supplémentaire : les 256 combinaisons de positions vides/remplies, soit 2 550 transitions avec doublons, passent sous ASan/UBSan.
- Revue indépendante : quatre défauts corrigés — STOP avant confirmation d’un START, échec BPM avant START, rappel du SONG actif depuis PC, activation accessible.
- Tests AU/UIKit ajoutés : PC/BPM/START, QUEUE, STOP, RESET, gestes XONE, restauration, hauteur des pads, navigation sans effet musical et captures de plusieurs formats.
- CI intermédiaire complète, commit 18b4aa1 : SUCCESS — https://github.com/pacomebommier-dot/beat4-auv3/actions/runs/43926613166
- CI finale, commit fe6edf3 : SUCCESS — https://github.com/pacomebommier-dot/beat4-auv3/actions/runs/43927933565

Les exécutions intermédiaires ou en double devenues inutiles ont été annulées.
Une annulation n’est jamais comptée comme un PASS.

## IPA

La compilation Release iphoneos de l’app et de l’extension a réussi pour fe6edf3.
Les tests UIKit ont réussi ; 13 captures et une trace MIDI du host simulé ont été récupérées et inspectées. Le workflow utilise
`CODE_SIGNING_ALLOWED=NO` : IPA NON SIGNÉE, à signer par la procédure habituelle.
Aucune validation matérielle n’est revendiquée.

SHA256 de l’IPA : `8645da10a35d39c248dc88db92b6d2cb368027b70049f89d27d4dbad4aed7135`.
Aucune entrée `_CodeSignature` dans le paquet ; app et extension arm64 vérifiées.

## Livrables Drive

- Candidate : https://drive.google.com/drive/folders/1DnbSKhrnl2UHGsOqq3dX7XiLntzNKCTD
- IPA non signée : https://drive.google.com/file/d/16DdHgUwP8kH6NxEJC3lQMol54sLNBwAW/view
- Captures natives et trace MIDI : https://drive.google.com/file/d/1PFmsMwb1OkLXrblLzoIdCkEx3uFEunfz/view
- Sources fe6edf3 : https://drive.google.com/file/d/14kL9ogSBd6dHKHSya73LGE4QRL9O-yUB/view
- Tests et preuves : https://drive.google.com/file/d/1F-vf13IpYwKhWFV6CXLMqde3AgBLLZrV/view
- Recette physique : https://drive.google.com/file/d/19nNjip2Kszhfq_-lz5G-fYHczef_i0mO/view
- Script Mozaic V4 : https://drive.google.com/file/d/1dsvsK87ZPxBgD6JXmbFoz8shDBFEnGSA/view

SHA256 du ZIP source : `a791b0a88b789df9e8b3ae19c6b3887e4607f224dd28121e997e75f3c271a030`.

Sources dans 02_APP_BEAT4/SOURCE_ET_GITHUB ; tests dans 05_TESTS_DEBUG/TESTS_AUTOMATIQUES ;
recette dans 05/RECETTE_IPAD_AUM ; script dans 04_CIRCUIT_XONE/MOZAIC/SCRIPTS ;
candidate dans 06_LIVRAISONS. La version courante 0.5.13 reste en place jusqu’à recette.

## Vérification sur iPad et limites

1. Signer et installer la candidate, puis vérifier 0.5.14/build 14.
2. Sur une copie de session, remplacer le toggle Mozaic V3 par V4. Router le K2 brut vers BEAT4 et conserver LED/mute. Ne pas envoyer le retour LED vers BEAT4 ni conserver l’ancien toggle immédiat en parallèle. Le script doit encore être compilé et essayé dans Mozaic sur iPad.
3. Circuit → In1 conserve les confirmations PC 0–63 et demandes queued 64–127. Les contrôleurs PC indépendants utilisent In2 pour leurs demandes quantifiées. Cette séparation évite de confondre une confirmation matérielle déjà exécutée avec une intention future.
4. Exécuter la fiche jointe, enregistrer les sondes PRE/POST, tester les frontières et remplir les résultats PASS/FAIL.

**Écart préexistant :** la base 0.5.13 expose 16/32 steps et des rampes indépendantes
des anciens modes 0/1/2. Ces rampes sont conservées ; aucun mode historique n’a été
réinventé. Ce décalage entre la terminologie historique et le code courant reste signalé.

Les collisions sont ordonnées au buffer render : STOP LONG avant advance ; RESET
après le QUEUE échu. L’ordre exact entre événements au sein d’un buffer n’est pas
garanti par le moteur historique. Les captures du harness affichent v1.0, version
de l’application de test ; l’IPA doit être vérifiée séparément en 0.5.14/build 14.
