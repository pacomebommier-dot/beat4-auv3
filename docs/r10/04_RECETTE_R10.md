# BEAT//4 — Recette minimale R10

| ID | Scénario | Résultat attendu | Preuve |
|---|---|---|---|
| T01 | Swipe ×3 sur Métronome | PC 01–32 → PC 33–64 → Métronome, sans MIDI ni changement PC | UI |
| T02 | Page Métronome | Titre MÉTRONOME (plus AUM), 4 barres R02 préservées | Capture |
| T03 | PLAY A=08 puis demande B=40 | A blanc, B gris, autre sombre ; même état après swipe | UI + moteur |
| T04 | Queue A absente, demande beat 2 | B s'active seulement beat 1 du prochain BAR | Horloge simulée |
| T05 | Queue A=8, demande en milieu de cycle | Attente de frontière de cycle relative à un ancrage explicite | Horloge simulée + AUM |
| T06 | STOP puis B | B actif immédiatement, aucun PLAY émis | MIDI/transport |
| T07 | PC reçu Circuit | B reconnu, jamais retransmis automatiquement vers Circuit | Sonde MIDI |
| T08 | PC reçu queued | Pas de statut actif prématuré ; phase incertaine tracée si non connue | Sonde + diagnostic |
| T09 | PC précédent A avec queue=8, nouveau B queue=16 | Transition se base sur A=8, jamais sur B=16 | Unitaire |
| T10 | B puis C avant frontière | Politique déterministe, aucune activation tardive B | Unitaire |
| T11 | BPM PC absent | AUM ne change pas BPM | Hôte simulé |
| T12 | BPM connu, STOP/PAUSE/PLAY modes 0/1/2 | Conformité V08 ; rampe seulement sur activation effective | Hôte + CI |
| T13 | Save MODE puis glissement BPM | Mémoire BPM distincte de SAVE ; global MODE inchangé au rappel | Persistance |
| T14 | STOP/PAUSE pendant rampe | Annuler au BPM observé ; pas de reprise au PLAY | Hôte |
| T15 | AUM réelle timeline + Circuit physique | Synchronisation observable des mesures et PC ; pas de double queue | iPad/Circuit, non simulable |
| T16 | KICK, SUB note, LEVEL, LED fade, transport | Zéro régression | AUM/CI |

**Attention :** un test web ne prouve pas T15 ni le fonctionnement AUv3. Exiger statut PASS/FAIL/NON TESTÉ par ligne.
