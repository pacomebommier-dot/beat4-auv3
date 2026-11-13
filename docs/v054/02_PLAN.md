# BEAT4 V0.5.4 Implementation Plan
Exécution directe autorisée par « go pour le script etc » ; pas de fusion dans main.
Goal: corriger callbacks/transport, offrir CC START/STOP exclusifs du MMC, puis LED/audio.
Architecture: conserver l'AU Objective-C++, extraire des politiques C++ testables pour MIDI, enveloppes LED et gain audio. AUM reste maître de la phase.
Tech Stack: UIKit, AUv3, C++17, tests shell et GitHub Actions macOS.
Spec: 01_CONTRATS.md.

## Contraintes
Conserver IDs AU, préférences SONG, mapping PB canal 15, sources et IPA précédents. Pas de timer musical autonome. Pas de MIDI PAUSE de secours. Ne pas annoncer une validation iPad sans essai réel.

## Review Focus
Lecture invalide -> aucune fausse confirmation ; STOP déjà arrêté -> Learn possible sans répétition MMC ; STOP/START rapides -> aucune requête périmée ; callbacks de rendu absents -> diagnostic honnête ; reprise après pause -> aucune LED précédente fantôme.

## Tâches
- [x] 1. Tests de non-régression : CALL-02/03 avec anciennes fonctions ; LED-01/02/03 et AUD-01/02/03 avec nouveaux composants. Montrer les échecs avant code.
- [x] 2. Modifier Beat4MMC.hpp et Beat4AudioUnit.mm : validité de lecture, délai 250 ms, gestion timestamp, reset allocation. Ajouter Beat4SafetyMIDI.hpp, mode API/UI, impulsions CC, diagnostic. Préserver l'envoi tempo.
- [x] 3. Ajouter Beat4Lights.hpp : update(beat,moving,synced,stopIntent,dt), énergie et animation. Intégrer au canvas et au display link même à l'arrêt pendant le fondu.
- [x] 4. Ajouter Beat4AudioGain.hpp : rampes de transport/volume ; intégrer KickVoice et rendu. Tests de transitions audio sur échantillons.
- [ ] 5. Exécuter Tests/run.sh, sanitizers, git diff --check ; consigner résultats et limites. Préparer script de recette et archive sources+manifest ; publier dans Drive.

Fichiers de test : Tests/test_v054.cpp plus Tests/test_transport.cpp ; nouveau test ajouté à Tests/run.sh. Les interfaces nouvelles sont définies dans leurs en-têtes et consommées par le rendu et le canvas, aucun lien Xcode supplémentaire requis pour les en-têtes.
