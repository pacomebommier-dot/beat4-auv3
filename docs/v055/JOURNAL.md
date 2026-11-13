# BEAT4 V0.5.5 — journal

Cause reproduite : en V0.5.4, barBrightness(active,active,0)=0 puis la barre monte pendant son propre beat. Son pic arrive à la frontière suivante. Le test PEAK-01 a échoué sur cette assertion avant correction.

Correctif local : barre active = (1-f)^1.5 ; barre suivante = f^1.5. Retrait du mécanisme d'éligibilité de la barre précédente, désormais toujours noire. Les états de pause et de fondu STOP restent mémorisés comme en V0.5.4.

Validation locale : les 6 exécutables C++ passent normalement puis sous GCC ASan/UBSan. Tests explicites de maximum à fraction zéro, montée anticipée, décroissance, continuité de la même barre à la frontière, 16 frontières dont pré-roll négatif et passage 4->1. Régressions STOP, PAUSE, MIDI et audio passent. Plists app/extension : version 0.5.5 build 5.

Modifications : Beat4Display.hpp, Beat4Lights.hpp, tests ; étiquettes version et workflow ; script de vérification V0.5.5. Audio, transport MIDI et mémoire SONG non modifiés.

Compilation iOS : NON EXÉCUTÉE. Essai AUM/iPad : NON EXÉCUTÉ. Cette correction mathématique ne prouve pas la synchronisation physique écran/audio.

La revue automatique a refusé la publication sur une nouvelle branche du même dépôt GitHub public, y compris après vérification des accords précédents et du dépôt. Elle exige un accord explicite pour cette V0.5.5. Demande regroupée présentée à l'utilisateur : publication du correctif dans pacomebommier-dot/beat4-auv3, puis livraison des sources et de l'IPA non signée dans BEAT4/V0.5.5_PICS_SUR_BEATS. Aucun autre canal de publication tenté.

Base : 1cfce29792d5cfc3cae5e10500aa489970b4c6e4. Les versions précédentes restent inchangées.
