# BEAT//4 V0.5 — état technique au 10 novembre 2026

| Domaine | État | Preuve / reste à faire |
|---|---|---|
| C++ Host beat projection | TESTÉ | `Tests/test_beat4.cpp` |
| C++ Transport estimation | TESTÉ | `Tests/test_transport.cpp` |
| SONGS / encodage PBEND / note du sub | TESTÉ | `Tests/test_songs_kick.cpp` |
| Kick trigger across buffers | CORRIGÉ + TESTÉ | `Tests/test_beat_gate.cpp` à plusieurs sample rates |
| Responsive layout geometry | TESTÉ | `Tests/test_layout.cpp` sur 8 viewports |
| Memory SONGS sur disque iOS | À VALIDER | Chargement et changement PG dans AUM |
| AUv3 audio + MIDI I/O | À COMPILER | Nécessite Xcode et AUM |
| AUM tempo MIDI mapping | À VALIDER | Vérifier BPM cible et BPM réel dans AUM |
| MMC transport feedback | À VALIDER | Vérifier le routage MIDI vers `MIDI Control` |
| Kick sound | PREVIEW | `audio-demo/BEAT4_kick_F1_128BPM.wav`, pas un test de rendu iOS |
| GitHub Actions macOS | PRÉPARÉ, NON LANCÉ | Aucun nouveau dépôt BEAT4 disponible ; XONE inchangé |
| IPA installable | NON PRODUIT | Dépend de la compilation et de la signature iOS |
