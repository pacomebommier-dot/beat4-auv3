# BEAT//4 — Contrat consolidé R10 — source unique pour le codage

**Date :** 13 novembre 2026. **Statut : VALIDÉ PAR L’UTILISATEUR — 14/14 FIX approuvés le 13 novembre 2026 ; prêt pour transmission à Codex.** Validation du périmètre et des règles fonctionnelles, **pas** validation de leur implémentation AUv3 ni des tests matériels.

## A. Architecture / sources

- AUM est le **maître musical** : transport (PLAY, STOP, PAUSE si exposé), BPM effectivement observé, position musicale en beats/mesures. BEAT//4 dérive la mesure/beat depuis la timeline AUM ; aucune seconde horloge maîtresse, aucun compteur libre substitué à AUM. Auditer les callbacks hôtes réellement disponibles plutôt que supposer.
- Circuit Tracks est source/destination de Program Changes. **Un PC n'est pas un PLAY**. Un PC reçu de Circuit n'est **jamais renvoyé automatiquement à Circuit** (anti-écho). Un pad local demande un PC à émettre vers Circuit selon la politique de synchronisation / MIDI auditable.
- 64 projets visibles : labels 01–64, valeurs MIDI 0–63 côté projet ; les valeurs queued 64–127 peuvent coder le même projet avec comportement différent, **à vérifier sur le matériel / documentation**, sans déduire un changement déjà effectif.
- Une seule page musicale à la fois : navigation circulaire `MÉTRONOME → PC 01–32 → PC 33–64 → MÉTRONOME`. Swipe seulement sur la zone des barres/grilles ; pas de changement musical causé par le swipe. Réception PC ne force pas la page.

## B. États exclusifs par PC, visibles partout

- `OFF` : pad sombre ; `SELECTED` : projet demandé et en attente, pad **gris** ; `ACTIVE` : projet réellement courant, pad **blanc**.
- Un et un seul ACTIVE ; au maximum un SELECTED distinct. Pendant PLAY avec attente A ACTIVE blanc, B SELECTED gris, tous les autres OFF. Ce sont les mêmes états sur les deux grilles après swipe et dans le bandeau MÉTRONOME (texte distinct ACTIVE/SELECTED). Ne jamais présenter B comme actif avant la frontière estimée/confirmée.
- À transition effective, effectuer d'un coup la bascule A→OFF, B→ACTIVE et la mise à jour des valeurs de SONG, BPM, MODE propre au PC. Ne pas recalculer l'identité courante sur simple pression sur B.

## C. QUEUE : politique unique, PAS de Q ON/OFF

- La QUEUE appartient au **PC actuellement actif A** et gouverne la transition A→B en PLAY : **jamais celle du PC destination B**.
- Paramètre manuel optionnel **en beats entiers par SONG/PC**, mémorisé indépendamment du BPM et du MODE, sans SAVE. Discret et éditable sur les pages PC. Le PC **édité** doit être identifié explicitement et ne doit pas devenir ACTIVE du seul fait de l'édition.
- **Valeur absente** ne veut ni dire zéro ni immédiat pendant PLAY : attendre **le début du prochain BAR AUM**, juste après le beat 4 en 4/4. S'il est déjà passé, attendre la prochaine frontière future. Pas quatre beats après l'appui ; pas au beat 4 lui-même.
- **Valeur présente** : respecter la frontière de cycle définie pour A à partir du repère de phase AUM. Ne pas coder un simple temporisateur en temps réel « N beats après appui » par défaut. Les conventions pour le début et la phase du cycle doivent être identifiées et testées ; si non observables pour un PC externe queued, le signaler (état de synchronisation incertain) au lieu d'inventer l'instant de déclenchement.
- **STOP** : sélection PC immédiate, aucune queue ; n'envoie jamais PLAY. **PAUSE** : le rappel du BPM suit le contrat V08 (comme STOP) ; l'attente QUEUE du PC et le devenir des demandes pending pendant PAUSE doivent être gérés explicitement et testés, sans supposition implicite.
- Plusieurs sélections successives, STOP pendant pending, resynchronisation après PLAY et perte de position : prévoir transitions déterministes, aucun ancien PC queued ne doit réapparaître. Si arbitrage métier nouveau requis, rendre visible dans rapport comme point à valider avant le MIDI réel.

## D. Interface — changements strictement limités

- Référence **R02 figée** ; R05 est la dernière maquette web antérieure, R10 la prévisualisation de la mise en conformité.
- Dans le bandeau haut, remplacer **AUM** par `MÉTRONOME`, `PC 01–32` ou `PC 33–64` selon la page (maintenir libellé PC courant distinct ; afficher PC sélectionné discrètement durant une attente).
- Grilles **8×4** (32 pads/page) ; pad OFF sombre, SELECTED gris, ACTIVE blanc ; contraste lisible sur petit iPhone paysage et iPad.
- Éditer discrètement **QUEUE (beats)** du PC/SONG identifié (pas de toggle ON/OFF). Champ non renseigné = « — » ; exemple d'indication `QUEUE —` pour absence ; sauvegarde automatique. Conserver la visualisation BPM, MODE, SAVE, SONG et le sélecteur de transport tels que V08/R02.
- La page MÉTRONOME conserve les quatre barres et leur animation, KICK/SUB/F/LEVEL alignés R02. Les transitions UI ne doivent pas changer la musique ou la page.

## E. BPM et MODE : conserver intégralement le contrat V08

- Deux valeurs séparées : BPM AUM observé vs BPM entier mémorisé par PC et modifié par glissement (sauvegarde automatique hors SAVE). BPM mémoire absent neutre. Orange si cible mémorisée diffère du BPM hôte.
- Sélecteur MODE toujours GLOBAL 0/1/2 ; MODE PC optionnel mémorisé par SAVE exclusivement, avec indicateur `PC MODE n`. MODE effectif = MODE PC si enregistré, sinon global.
- En STOP et PAUSE déjà actifs lors du rappel effectif : application immédiate du BPM mémorisé si présent, sans rampe ; en PLAY : MODE 0 sans tempo action, MODE 1 rampe 8 mesures, MODE 2 rampe 2 beats. AUM BPM réellement observé est le départ d'une nouvelle rampe ; ne jamais écraser les mémoires.
- En présence d'une QUEUE, une demande de PC **ne doit pas lancer prématurément** le changement de SONG/BPM/MODE actif ; déclencher le comportement de réception V08 lorsque le nouveau PC devient effectif. Cette précision temporelle prime sur la formulation V08 « à réception du PC » en cas de PC queued.
- STOP ou PAUSE pendant rampe : annule définitivement au BPM AUM observé ; pas de reprise automatique. Changement global MODE pendant rampe : ne la modifie pas.

## F. Transport / audio / réseau MIDI

- Un seul contrôle PLAY/STOP toggle sans PAUSE graphique ; état fidèlement reflété depuis AUM ; pas de MMC ; éviter double commandes ou commandes jamais prises en charge par AUM.
- Conserver KICK, SUB, note SUB éditable, F, LEVEL, fades LEDs et routage musical existant : *ne pas réécrire les fonctions non concernées*. Tester non-régression.
- Vérifier le routage PC Circuit→BEAT//4→AUM et BEAT//4→Circuit dans la session AUM ; distinguer les sorties pour ne pas boucler les événements ; journaliser PC reçu, PC demandé, pending, frontière, émission, PC actif, origine et timestamp musical.

## G. Anciennes règles retirées / supersédées

1. R06 : `QUEUE absente = aucun délai en PLAY` **SUPPRIMÉ** ; repli = prochain BAR.
2. R06 : `ne pas montrer le PC pending sur la grille` **SUPPRIMÉ** ; R07 : SELECTED gris.
3. R04/R05 : PC pending en **ambre**, PC actif en **vert** **SUPPRIMÉ** ; gris et blanc.
4. Tout toggle `Q ON/OFF` ou question A/B/C sur le « type de queue » **SUPPRIMÉ**.
5. R08 : ambiguïté « beat 4 » **SUPPRIMÉE** ; R09 : **après beat 4 = beat 1 prochain BAR**.
6. R03/R04 : activation sur PC queued dès sa réception **SUPPRIMÉE**.
7. L'ancien raccourci `prochain BAR` ne se substitue pas à une QUEUE renseignée du PC précédent ; c'est seulement la règle de défaut.
8. Le champ initial `DRUM 1 CYCLE` du prototype R05 n'est **pas un deuxième paramètre à créer en parallèle** de QUEUE. Pour migration, vérifier la sémantique des anciennes mémoires avant de les traiter comme identiques ; garder les archives historiques.

## H. Points de vérification techniques (ne pas inventer de faits)

1. Récupération effective de la timeline musicale AUM dans l'AUv3 et conversion en BAR/BEAT, cas STOP/PAUSE, changements de métrique/tempo.
2. Ancrage de phase du cycle QUEUE lorsque renseigné, en particulier lors d'un PC queued **initié directement sur Circuit** ; **une horloge AUM maître ne prouve pas à elle seule que le pattern Drum 1 a la même origine de cycle**. Étudier l'initialisation/alignement au PLAY, puis recette sur Circuit physique.
3. Moment d'émission PC vers Circuit pour éviter de demander une queue native supplémentaire après la frontière AUM ; vérifier le mapping PC et le canal et l'exécution réelle.
4. Deux PC demandés rapidement, un STOP/PAUSE pendant pending, changement transport, perte de phase et cas PC inconnu.

**Ces quatre vérifications sont des tests de faisabilité et des garde-fous, pas des raisons de réintroduire une autre horloge maîtresse ni d'arrêter les correctifs déterministes.**
