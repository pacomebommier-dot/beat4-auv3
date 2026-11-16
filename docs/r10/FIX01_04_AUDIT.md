# Audit FIX-01 à FIX-04 — 16 novembre 2026

Base : `origin/fix/r10-cycles-16-32-0513`, `2dc3aba` (code `dc1879e`).
Main `25f789f` est antérieur. Clone initial propre ; aucune modification locale
non publiée disponible. Les branches distantes sont conservées.
CI précédente : https://github.com/pacomebommier-dot/beat4-auv3/actions/runs/43805675217
succès ; artifacts IPA unsigned et captures non expirés au moment de l'audit.
IPA historique 0.5.13 build13, SHA256 indiqué dans CYCLES_16_32_0513.md ; pas de recette physique.

| Fonction | État initial | Preuve |
|---|---|---|
| FIX-01 symbole | partiel | ViewController : police 24 × scale ; petit sur iPad |
| FIX-02 alignement | défaillant géométriquement | Layout : tailles SAVE/pcMode distinctes, centres différents malgré baseline commune |
| FIX-03 titre interactif | absent | host UILabel ; navigation UISwipeGestureRecognizer |
| FIX-04 SET et éditeur | absent | aucun modèle SET, stockage ou API |
| QUEUE unique / 16–32 | déjà implémenté | ProgramEngine.selected, schedule ; tests portables PASS |
| PC Circuit | déjà implémenté | canal16, 0–63 confirmations, 64–127 demandes queued |
| BPM à l'arrêt | partiel | activate applique BPM ; rappel du SONG déjà actif retourne avant application |
| TEMPO MODE 0/1/2 | partiel | mémoire legacy présente ; moteur 0.5.13 à rampes indépendantes du mode ; sélecteur UI 16/32 |
| transport AUM | déjà implémenté | CC110/111 canal16, anti-doublon, release au buffer suivant |
| gestes XONE | absent | seuls realtime FA/FB/FC et PC décodés ; aucun press/release XONE vérifié |
| persistance | partiel | SONGS UserDefaults v2 ; pas de SET ; ni transport ni queue restaurés |

La référence HTML protégée a été lue par le connecteur Vercel : géométrie issue
du même Layout.hpp ; simulation sans MIDI. Aucun SET n'y est intégré.
Pas d'assimilation HTML/AUv3.

Contraintes réelles : ce Linux ne contient pas Xcode. Le réseau doit être autorisé explicitement ; gh authentifié fonctionne avec cet accès.
Les octets XONE ne figurent pas dans le dépôt initial. La recherche Drive a retrouvé
MODE_EMPLOI_XONE_SAFE_V1.txt (1r5irgGF5tocB9uL43CZBpKVnGaWhuqy8) et
XONE_COMPLET_V3.txt (1S8W714b_zIK_EJrwPVgFt-lI2MZgCrdM) : canal15 note12,
NoteOn velocity0 ou NoteOff au release. Le script V3 consomme la note et
émet immédiatement CC110/111 : il faut le remplacer pour le SET, faute de quoi
BEAT4 ne reçoit pas la durée. Le nouveau script d'intégration conserve LED/mute
et délègue les gestes à BEAT4 via une liaison matérielle directe distincte.
La demande externe queued et la confirmation matérielle Circuit doivent rester
distinctes : quantifier une confirmation déjà exécutée sur Circuit désynchroniserait
l'affichage et le matériel.

Complément Drive : le ZIP BEAT4_CODEX_PAQUET_R10.zip du 13 novembre
(ID 1M6scgZvxs57w2qHe9UYafnjXUllPffFK) contient neuf fichiers HTML/CSS/JS
et documents, sans source AUv3 non publiée. In1 reste dédié au protocole
Circuit existant ; In2 distingue les demandes indépendantes à quantifier.
