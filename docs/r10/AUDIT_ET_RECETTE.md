# BEAT//4 — audit et livraison de développement R10

Base auditée : `pacomebommier-dot/beat4-auv3`, main `25f789f1a787d268c021b3543930df27e9083f8b`. Clone neuf, aucun travail local préexistant écrasé. Branche `fix/r10-consolidated`, non fusionnée. Contrat R10 prioritaire et contrat V08 archivés dans ce dossier. Ceci est une livraison source de développement, pas une validation matérielle ni une livraison IPA.

## Audit ciblé avant corrections

| Domaine | État au HEAD initial | Action |
|---|---|---|
| Horloge/transport | `transportStateBlock`, `musicalContextBlock`, `HostMemory` raccordés dans le rendu ; STOP/PAUSE inférés, non distinguables avec certitude | Conservation ; lecture du downbeat courant pour la QUEUE |
| PC Circuit | Entrée canal 16, 128 valeurs brutes, activation immédiate ; aucune grille | 64 projets canoniques ; distinction demande/activation ; entrée immédiate vs queued ; sortie locale séparée |
| BPM | Mémoire existante et glissement entier ; émission lors d’édition titre/BPM/SUB et dès PC | Suppression des effets tempo de l’édition ; rappel seulement à activation |
| MODE/SAVE/rampes | Absents | MODE global et mémoire PC optionnelle ; SAVE MODE seul ; rampes en beats AUM |
| Transport UI | PLAY, PAUSE et STOP avec SysEx MMC | Toggle seul ; retrait MMC du code exécuté ; CC119 canal 15 à mapper explicitement dans AUM |
| KICK/SUB/LEVEL/LED | Implémentés et couverts par tests portables | Moteur audio/gate/enveloppe conservés |
| Persistance | `beat4.songs.v1`, 128 slots bruts | v2 canonique ; v1 conservé intégralement ; slots supérieurs non fusionnés arbitrairement |
| UI | Une page native ; socle existant distinct de la maquette web | Trois pages ; barres et outils conservés, ajout des contrôles limités R10 |
| Session AUM physique | Aucun fichier de session AUM ni appareil dans le dépôt/environnement | Procédure ci-dessous, NON TESTÉ |

Les cinq suites initiales passaient avant modification. L’ancienne CI réussie ne constituait pas une preuve pour le HEAD R10.

## FIX codés

- Navigation circulaire sur la seule région musicale ; grilles 8×4, 01–64 ; aucune navigation sur réception PC.
- OFF sombre, SELECTED gris, ACTIVE blanc ; snapshot cohérent d’identité/attente/transport pour une frame UI ; label distinct ACTIVE/SELECTED et MODE PC.
- QUEUE optionnelle positive par PC, saisie en beats entiers, autosauvegarde ; appui long sur un pad pour éditer sans activer. Valeur vide affichée « — ». Aucun Q ON/OFF ni deuxième paramètre Drum 1.
- Queue du PC sortant ; absence = frontière de mesure strictement future depuis le downbeat AUM ; cycle explicite ancré sur l’activation locale, jamais N beats après la demande.
- Dernière demande locale en attente traitée avant l’activation due du même rendu ; pas d’ancien pending réactivé après hold/perte de position.
- PC local émis en valeur immédiate 0–63 au moment de la frontière calculée, canal 16, sortie Circuit dédiée ; PC entrant jamais retransmis.
- PC externe 64–127 conservé SELECTED/phase incertaine. Il faut une nouvelle observation immédiate 0–63 pour l’activer ; aucun acquittement Circuit inventé.
- BPM entier autosauvé ; BPM observé distinct ; SAVE enregistre exclusivement MODE PC ; global inchangé au rappel. Modes 0, 1 (8 mesures), 2 (2 beats) ; annulation au hold/perte de position ; pas de reprise automatique.
- Refus/absence de sortie MIDI PC : ancienne identité conservée et demande incertaine. Une émission locale acceptée reste indiquée « estimé » : cela ne prouve pas l’état matériel.
- Journal borné sans allocation audio : `diagnosticLog` retourne les 128 derniers événements avec PC, origine et beat AUM. Codes 1=entrée brute, 2=demande locale, 3=activation logique, 4=émission acceptée, 5=phase incertaine, 6=erreur sortie, 7=attente modifiée. Origines : 0=externe, 1=local, 2=tempo.

## Décisions et limites à valider

1. **Hold STOP/PAUSE :** le flag Moving ne prouve pas l’identité de la commande. Un nouveau rappel lorsque Moving=false applique le BPM immédiatement ; le passage à hold annule pending et rampe sans rappel. Coût si cette politique métier ne convient pas : adapter le devenir des demandes pending ; aucune reprise fantôme actuellement.
2. **Phase de cycle :** ancrage de l’app à l’activation locale, ou au premier beat PLAY observé après une sélection à l’arrêt. Ce repère ne prouve pas la phase Drum 1. Coût si Circuit n’est pas aligné : transition physiquement décalée ; T15 obligatoire. Externe queued reste incertain.
3. **Résolution du rendu :** le moteur décide aux observations du callback audio. L’activation peut être retardée d’un buffer ; `eventSampleTime` entrant n’est pas encore utilisé pour un sous-découpage du buffer. Il ne s’agit pas d’un ordonnanceur MIDI vérifié à l’échantillon. À qualifier/compléter avant diffusion scène.
4. **Transport AUM :** nouveau mapping proposé CC119 canal 15 en impulsion 127/0, à apprendre sur le front montant uniquement pour le toggle. La prise en charge effective n’est pas prouvée. Le pitch bend canal 15 conserve le mapping BPM 20–240 préexistant ; les consignes envoyées ne sont jamais affichées comme BPM observé.
5. **Mémoires héritées :** les anciennes entrées brutes 64–127 restent dans v1, sans fusion silencieuse. Auditer leurs éventuels conflits avec 0–63 avant toute migration manuelle. Aucun paramètre Drum 1 du LAB web n’est importé.
6. **Référence graphique :** dessin des barres/enveloppe et outils natifs préservé depuis la base auditée. L’équivalence pixel avec la référence R02 web n’est pas prouvée ; captures natives et validation visuelle restent à faire. Pour hauteur <310, l’espace des barres est ajusté afin d’éviter les chevauchements des nouveaux contrôles.
7. **Initialisation :** aucun ACTIVE fictif avant le premier rappel valide (identité inconnue au chargement). Le mode global et les mémoires persistent ; transport et pending ne persistent pas.

## Recette R10 — preuve disponible

PASS ci-dessous désigne uniquement la preuve précisée. Aucune ligne ne constitue un PASS AUM physique.

| ID | Statut logiciel | Preuve / reste à faire |
|---|---|---|
| T01 | PASS moteur de navigation ; NON TESTÉ geste natif | `test_layout`, cycle dans les deux sens ; swipe et absence MIDI à capturer sur appareil |
| T02 | NON TESTÉ visuellement | Titre natif codé ; captures comparées à R02 non réalisées |
| T03 | PASS moteur ; NON TESTÉ UI native | `test_program` ; blanc/gris/sombre à capturer |
| T04 | PASS simulé | prochain BAR, pas beat 4 ni quatre beats après appui ; `test_program`, `test_tempo_modes` |
| T05 | PASS simulé ; NON TESTÉ AUM | ancrage et absence de dérive ; phase physique à vérifier |
| T06 | PASS moteur/octets ; NON TESTÉ routage | rappel tenu immédiat ; sortie PC distincte du transport |
| T07 | PASS moteur/octets ; NON TESTÉ sonde physique | action externe sans sendPC ; canal et octets dans `test_r10_midi_memory` |
| T08 | PASS simulé | queued externe incertain ; pas de faux ACTIVE ; journal branché |
| T09 | PASS simulé | queue A=8, queue B=16 ; `test_program` |
| T10 | PASS simulé | remplacement, frontière de rendu, hold ; `test_program` |
| T11 | PASS simulé | BPM absent neutre ; `test_tempo_modes` |
| T12 | PASS simulé ; NON TESTÉ AUM | modes 0/1/2, 32 beats et 2 beats ; `test_tempo_modes` |
| T13 | PASS validation portable ; test natif fourni | `test_r10_midi_memory`, `test_persistence.mm` ; résultat macOS CI à lire |
| T14 | PASS simulé | annulation hold, pas de reprise ; `test_program`, `test_tempo_modes` |
| T15 | NON TESTÉ | iPad/AUM et Circuit Tracks indisponibles dans cet environnement |
| T16 | PASS portables ; NON TESTÉ natif/AUM | suites gate/audio/enveloppe/layout ; automation LEVEL et audition à vérifier |

Responsive : géométrie des pads/contrôles testée à 720×400, 667×375, 1024×768, 390×844 et six autres tailles. Ce ne sont pas des captures UIKit. Persistance native : test exécuté uniquement si le job macOS le confirme. Le contrôle LSan local est incompatible avec ptrace ; ASan/UBSan locaux passent avec `detect_leaks=0`, la CI Linux exécute la commande complète.

## Procédure AUM / Circuit avant IPA

- Charger l’instrument AUv3 dans un canal audio AUM ; vérifier les callbacks et la position à PLAY, hold, retour zéro, changement de tempo/métrique.
- Circuit MIDI canal16 vers BEAT4. Sortie **Circuit Projects** exclusivement vers Circuit. Sortie **AUM Control** exclusivement vers MIDI Control AUM. Ne pas reboucler Circuit Projects vers l’entrée du plugin.
- Mapper PB canal15 sur BPM avec bornes 20–240 ; mapper CC119 canal15 sur toggle transport, front montant. Vérifier une seule action par appui, avec le retour AUM observé comme autorité. Si la configuration ne le permet pas, ne pas annoncer le transport fonctionnel.
- Activer Program Change Tx/Rx sur Circuit. Vérifier les valeurs 0–63 immédiates et 64–127 queued ; test de double queue après émission locale.
- Exécuter T01–T16 avec sonde MIDI horodatée, filmer AUM et Circuit pour T15 ; inclure PC successifs, STOP/PAUSE pending, interruption de rampe, démarrage milieu de timeline et perte de phase.
- Relancer l’app/l’extension et la session pour vérifier BPM, MODE, QUEUE, titre et SUB. Audition KICK/SUB/LEVEL, LEDs, screenshots aux quatre tailles de recette.
- Seulement après résultat CI du dernier code et recette physique satisfaisante : signature/provisionnement Apple et packaging IPA. Le workflow R10 compile sans fabriquer d’IPA.
