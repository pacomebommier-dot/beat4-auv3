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
- Toucher le pad ACTIVE annule une attente sans le sélectionner lui-même ni réémettre son PC. Un PC immédiat externe identique reste un rappel V08. Dernière demande locale en attente traitée avant l’activation due du même rendu ; pas d’ancien pending réactivé après hold/perte de position.
- PC local émis en valeur immédiate 0–63 au moment de la frontière calculée, canal 16, sortie Circuit dédiée ; PC entrant jamais retransmis.
- PC externe 64–127 conservé SELECTED/phase incertaine. Il faut une nouvelle observation immédiate 0–63 pour l’activer ; aucun acquittement Circuit inventé.
- BPM entier autosauvé ; BPM observé distinct ; SAVE enregistre exclusivement MODE PC ; global inchangé au rappel. Modes 0, 1 (8 mesures), 2 (2 beats) ; annulation au hold/perte de position ; pas de reprise automatique.
- Refus/absence de sortie MIDI PC : ancienne identité conservée et demande incertaine. Une émission locale acceptée reste indiquée « estimé » : cela ne prouve pas l’état matériel.
- Journal borné sans allocation audio : `diagnosticLog` retourne les 128 derniers événements avec PC, origine et beat AUM. Codes 1=entrée brute, 2=demande locale, 3=activation logique, 4=émission acceptée, 5=phase incertaine, 6=erreur sortie, 7=attente modifiée. Origines : 0=externe, 1=local, 2=tempo.

## Décisions et limites à valider

1. **Hold STOP/PAUSE :** le flag Moving ne prouve pas l’identité de la commande. Un nouveau rappel lorsque Moving=false applique le BPM immédiatement ; le passage à hold annule pending et rampe sans rappel. Coût si cette politique métier ne convient pas : adapter le devenir des demandes pending ; aucune reprise fantôme actuellement.
2. **Phase de cycle :** ancrage de l’app à l’activation locale, ou au premier beat PLAY observé après une sélection à l’arrêt. Ce repère ne prouve pas la phase Drum 1. Coût si Circuit n’est pas aligné : transition physiquement décalée ; T15 obligatoire. Externe queued reste incertain.
3. **Queue en cours d’attente :** l’échéance capture la QUEUE du sortant à la demande. Une édition ne recalcule pas rétroactivement l’attente déjà engagée ; une nouvelle demande utilise la nouvelle valeur. Cette politique doit être qualifiée en recette.

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
| T03 | PASS moteur et UIKit sur hôte simulé | `test_program` + 12 captures natives ; états des deux grilles vérifiés dans le harness |
| T04 | PASS simulé | prochain BAR, pas beat 4 ni quatre beats après appui ; `test_program`, `test_tempo_modes` |
| T05 | PASS simulé ; NON TESTÉ AUM | ancrage et absence de dérive ; phase physique à vérifier |
| T06 | PASS moteur et adaptateur AUv3 simulé | PC à l’arrêt émis sur câble Circuit ; aucun PLAY ; routage AUM physique NON TESTÉ |
| T07 | PASS moteur et adaptateur AUv3 simulé | PC entrants immédiat et queued sans retransmission ; sonde physique NON TESTÉE |
| T08 | PASS moteur et adaptateur AUv3 simulé | événement MIDI queued garde A actif et phase incertaine ; trace JSON générée |
| T09 | PASS simulé | queue A=8, queue B=16 ; `test_program` |
| T10 | PASS simulé | remplacement, frontière de rendu, hold ; `test_program` |
| T11 | PASS simulé | BPM absent neutre ; `test_tempo_modes` |
| T12 | PASS simulé ; NON TESTÉ AUM | modes 0/1/2, 32 beats et 2 beats ; `test_tempo_modes` |
| T13 | PASS validation portable et persistance native macOS | `test_r10_midi_memory`, `test_persistence.mm` exécutés avec succès en CI |
| T14 | PASS simulé | annulation hold, pas de reprise ; `test_program`, `test_tempo_modes` |
| T15 | NON TESTÉ | iPad/AUM et Circuit Tracks indisponibles dans cet environnement |
| T16 | PASS portables ; NON TESTÉ natif/AUM | suites gate/audio/enveloppe/layout ; automation LEVEL et audition à vérifier |

Responsive : géométrie des pads/contrôles testée à 720×400, 667×375, 1024×768, 390×844 et six autres tailles. Ce ne sont pas des captures UIKit. Persistance native : PASS macOS Intel au commit `8b2253c`, exécution `43498164859`. Le contrôle LSan local est incompatible avec ptrace ; ASan/UBSan locaux passent avec `detect_leaks=0`, la CI Linux exécute la commande complète.

## Procédure AUM / Circuit avant IPA

- Charger l’instrument AUv3 dans un canal audio AUM ; vérifier les callbacks et la position à PLAY, hold, retour zéro, changement de tempo/métrique.
- Circuit MIDI canal16 vers BEAT4. Sortie **Circuit Projects** exclusivement vers Circuit. Sortie **AUM Control** exclusivement vers MIDI Control AUM. Ne pas reboucler Circuit Projects vers l’entrée du plugin.
- Mapper PB canal15 sur BPM avec bornes 20–240 ; mapper CC119 canal15 sur toggle transport, front montant. Vérifier une seule action par appui, avec le retour AUM observé comme autorité. Si la configuration ne le permet pas, ne pas annoncer le transport fonctionnel.
- Activer Program Change Tx/Rx sur Circuit. Vérifier les valeurs 0–63 immédiates et 64–127 queued ; test de double queue après émission locale.
- Exécuter T01–T16 avec sonde MIDI horodatée, filmer AUM et Circuit pour T15 ; inclure PC successifs, STOP/PAUSE pending, interruption de rampe, démarrage milieu de timeline et perte de phase.
- Relancer l’app/l’extension et la session pour vérifier BPM, MODE, QUEUE, titre et SUB. Audition KICK/SUB/LEVEL, LEDs, screenshots aux quatre tailles de recette.
- Seulement après résultat CI du dernier code et recette physique satisfaisante : signature/provisionnement Apple et packaging IPA. Le workflow R10 compile sans fabriquer d’IPA.

## Vérification complémentaire du 13 novembre — reprise

Le runner `macos-15` ARM n’avait acquis aucun job après plusieurs tentatives : échec d’infrastructure, sans exécution du build. Retour au runner `macos-15-intel`, puis exécution complète réussie :

- Commit code/tests/CI vérifié : `8b2253ca9d6fbb7165144b4fa495b2bed48d7e37`.
- CI : https://github.com/pacomebommier-dot/beat4-auv3/actions/runs/43498164859 — **SUCCESS**.
- Neuf exécutables portables, ASan/UBSan : PASS.
- Persistance Foundation/macOS (migration v1, v2, indépendance BPM/MODE/QUEUE) : PASS.
- Build Release iOS unsigned du container et de l’extension : PASS.
- Harness iOS Simulator compilant les vrais `Beat4AudioUnit.mm` et `Beat4ViewController.mm` : PASS ; douze rendus UIKit (trois pages × quatre tailles), assertions des labels ACTIVE/SELECTED et des couleurs OFF/gris/blanc.
- Injection de vrais `AURenderEvent` PC dans le render block de l’AUv3 avec callbacks hôte simulés : PASS anti-écho, queued sans activation prématurée, PC local vers câble Circuit uniquement et aucun PLAY implicite. Trace `mock-host-midi-trace.json` dans l’artefact.
- Artefact GitHub : **R10-native-UIKit-snapshots** de cette exécution. Captures hors écran dans un vrai processus iOS Simulator ; ce ne sont ni des captures AUM ni une simulation web.

Le téléchargement des PNG depuis le stockage GitHub Azure reste refusé par le proxy (403 CONNECT vers `productionresultssa13.blob.core.windows.net`), y compris après l’autorisation déclarée du domaine et une nouvelle connexion. Les images sont générées et conservées dans GitHub, mais pas inspectées visuellement ici ni transférées dans Drive. La conformité graphique R02 pixel/typographie et les gestes réels restent NON VALIDÉS. Les assertions UIKit ne remplacent pas cette inspection.

Les erreurs de compilation du harness (capture `__block` par lambda puis liaison CoreGraphics manquante) ont été corrigées. Aucun changement au code musical de production depuis la livraison `9ba8524` durant cette reprise : seuls CI, tests et documentation ont changé. Les différences d’un éventuel commit final de documentation avec `8b2253c` sont vérifiables par `git diff` ; les fichiers de code/build/tests sont identiques.

AUM/Circuit physiques, signature Apple et IPA restent non réalisés. Aucun PASS matériel ni confirmation de phase Circuit ajouté.

## Reprise de la livraison IPA habituelle

À la demande explicite de l’utilisateur (« on faisait ça à l’arrache avant, regarde les précédents »), reprise de la méthode de la livraison V0.5.6 : construire puis livrer une **IPA non signée à signer avec la procédure habituelle**, sans exiger une nouvelle configuration Apple dans cette session. Cette demande remplace le report du packaging jusqu’à recette matérielle. Elle ne transforme aucun test matériel en PASS.

Référence retrouvée : `3f18d0042c03ed0ff389ab46731141e1024fa5ca`, run `43318936011`, IPA V0.5.6 build6 et contrôle des deux plists. Nouvelle version : **0.5.7 build 7** dans l’application et l’extension, identifiants conservés. Packaging placé après les tests et le build ; contrôle bloquant de la structure Payload, des deux versions, des identifiants et des exécutables Mach-O arm64. Résultat de la nouvelle IPA à confirmer par la CI avant livraison.

### Correction de non-régression transport avant IPA

L’inspection de la V0.5.6 a retrouvé `Beat4SafetyMIDI.hpp` et son mapping AUM : **CC110 START / CC111 STOP, canal 16**, avec release au buffer suivant avant toute nouvelle pression. Ce mapping est conservé dans le nouveau toggle unique, toujours sans MMC ; la proposition CC119 canal15 des sections précédentes est donc **retirée et remplacée**. Cela évite de demander à l’utilisateur un nouveau mapping arbitraire. Les impulsions sont couvertes par tests portables et par le harness AUv3 natif. Le retour AUM réel demeure l’autorité ; aucun PC ne déclenche ces commandes.
