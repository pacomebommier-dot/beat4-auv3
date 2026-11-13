# BEAT//4 — FIX PC / BPM / MODE — Contrat V08

**Date :** 13 novembre 2026  
**Statut :** cadrage fonctionnel, avant implémentation Codex ; aucun code modifié pour ce FIX.  
**Référence visuelle impérative :** `BEAT4/00_REFERENCE_INTERFACE/BEAT4_INTERFACE_REFERENCE_V056_RECONSTITUTION_CODE V2.png` (V02 créée par l'utilisateur).  
**Historique :** V01 à V07 conservées. La V08 ajoute le **choix A confirmé : PC reçu lorsque AUM est déjà en PAUSE = application immédiate du BPM mémorisé, comme à STOP, sans rampe**, quel que soit le MODE. Les décisions V01 à V07 sont conservées.

## 1. Concepts et données séparés

- **BPM actif AUM :** valeur effectivement observée sur l'hôte ; ne pas la confondre avec une consigne MIDI envoyée.
- **BPM mémorisé pour chaque PC :** entier que l'utilisateur définit par glissement. À la fin du geste, le BPM du PC est automatiquement mémorisé, sans SAVE. Un rappel PC ne réécrit jamais cette valeur ; le host ne l'écrase pas non plus.
- **MODE courant/global :** sélecteur à trois positions `0 / 1 / 2`.
- **MODE enregistré par PC :** valeur optionnelle sauvegardée par **SAVE**, qui ne sauvegarde **que** ce MODE, jamais le BPM.
- **MODE effectif lors de la réception d'un PC :** MODE sauvegardé par ce PC s'il existe ; sinon MODE courant/global à l'instant de la réception.

## 2. Affichage et édition

- PC sans BPM saisi manuellement : BPM mémoire absent, indication légèrement grisée, pas de demande de changement de tempo à son rappel.
- BPM du PC saisi par glissement : dernière valeur entière réglée automatiquement enregistrée dans ce PC ; ce geste seul ne modifie pas le BPM effectif AUM et ne déclenche pas de rampe.
- À réception du PC, retrouver le BPM précédemment mémorisé **sans le réécrire**.
- BPM du PC **orange** lorsqu'il est connu et différent du BPM effectivement lu sur AUM ; couleur normale lorsqu'il correspond. Ne pas confondre affichage BPM du PC et BPM de l'hôte.
- Afficher `PC 007`, et non `PG 007` ; conserver la numérotation et les index MIDI existants.

## 3. Actions sur le tempo uniquement à réception d'un PC

| État du host à l'arrivée du PC | BPM mémoire du PC | MODE effectif | Action sur le BPM AUM |
| --- | --- | --- | --- |
| STOP | Présent | 0, 1 ou 2 | Appliquer immédiatement le BPM mémorisé |
| PAUSE (déjà dans cet état à la réception) | Présent | 0, 1 ou 2 | Appliquer immédiatement le BPM mémorisé, sans rampe |
| STOP | Absent | 0, 1 ou 2 | Aucun changement |
| PAUSE (déjà dans cet état à la réception) | Absent | 0, 1 ou 2 | Aucun changement |
| PLAY | Présent | 0 | Aucun changement |
| PLAY | Présent | 1 | Rampe vers BPM mémorisé en 8 mesures (4/4) |
| PLAY | Présent | 2 | Rampe vers BPM mémorisé en 2 beats |
| PLAY | Absent | 0, 1 ou 2 | Aucun changement |

La **réception du PC** est l'événement déclencheur. Passer à STOP ou à PLAY, à soi seul, **ne réapplique pas** un BPM mémorisé. Les rampes commandent uniquement le BPM du host, jamais la mémoire du PC. Une nouvelle valeur BPM réglée par glissement ne déclenche pas de nouvelle rampe sans nouveau PC.

## 4. PC suivant reçu pendant une rampe — choix A confirmé en V03

- Annuler immédiatement la rampe précédente sans terminer sa cible ni revenir au BPM de départ.
- Lire comme nouveau point de départ le **BPM réellement atteint sur AUM** au moment du nouveau PC.
- Appliquer les règles normales du nouveau PC : MODE propre sauvegardé s'il existe, sinon MODE courant ; STOP impose immédiatement un BPM connu, PLAY MODE 0 garde la valeur atteinte, MODE 1 / 2 lance la nouvelle rampe complète ; PC sans BPM conserve le BPM atteint.
- Ne jamais écraser les mémoires BPM des PC.

**Test :** 128 → 135 en 8 mesures ; nouveau PC alors qu'AUM atteint 131, cible 140, MODE 2 → rampe **131 → 140 en 2 beats**, sans saut vers 135.

## 5. STOP pendant une rampe — choix A confirmé en V04

- Le passage réel de l'hôte à STOP annule définitivement la rampe.
- Conserver le dernier BPM réellement atteint/observé sur AUM, sans forcer la cible ni rétablir le BPM initial.
- Ni STOP seul ni le PLAY suivant ne rappellent un BPM PC ou ne reprennent la rampe interrompue.
- Les mémoires PC (BPM et MODE) restent inchangées ; une nouvelle réception PC à STOP peut appliquer immédiatement le BPM de ce PC.

**Test :** 128 → 135, STOP lorsque AUM atteint environ 131 → conserver ce BPM effectif, PLAY seul → pas de reprise automatique.

## 6. Changement manuel du MODE en cours de rampe — choix A confirmé en V05

**Décision explicite utilisateur : A — la rampe en cours ne change pas ; le nouveau MODE ne s'applique qu'à la prochaine réception d'un PC.**

- Si une rampe a été déclenchée en MODE 1 (8 mesures), déplacer le sélecteur en MODE 2 (2 beats) **ne raccourcit pas** et **ne redémarre pas** cette rampe ; elle conserve sa cible, sa durée programmée, sa progression et son point d'arrivée.
- Même principe pour les autres changements manuels de MODE, y compris passage en MODE 0 : **ne pas annuler** une rampe déjà lancée par ce seul geste.
- Le sélecteur MODE est une **préparation pour les prochains rappels**, pas une commande rétroactive sur l'action déjà en cours.
- Sans appui sur SAVE, le geste ne change pas le MODE enregistré pour le PC courant. Avec SAVE, il enregistre seulement le MODE du PC (pas le BPM) et **ne change pas la rampe en cours** ; lors du prochain PC reçu, le MODE effectif est recalculé selon les priorités prévues.
- Le prochain PC peut, lui, interrompre la rampe conformément au §4 et utiliser son MODE sauvegardé ou le MODE courant.

**Test de recette :** AUM 128, PC cible 135, MODE 1 → rampe 8 mesures engagée ; au bout de 3 mesures déplacer MODE sur 2 → **la rampe initiale se termine toujours en 8 mesures**, sans accélération, saut ou nouvelle commande de rattrapage. Lorsqu'un PC suivant arrive, utiliser alors son MODE effectif. Répéter avec MODE 0, et avec SAVE durant la rampe.

## 7. PAUSE venant d’AUM pendant une rampe — choix A confirmé en V06

**Décision explicite utilisateur : A — même effet que STOP sur la rampe en cours.**

- Si AUM passe réellement en **PAUSE pendant une rampe**, annuler **définitivement** la rampe à cet instant, sans la terminer, sans la mettre en attente ni la mettre en reprise automatique.
- **Conserver le dernier BPM effectivement atteint et observé dans AUM** au moment de PAUSE. Ne pas forcer le BPM cible ni revenir au BPM de départ.
- À la reprise **PLAY**, aucune poursuite, recalcul ou relance de cette rampe. Comme pour STOP, seul un **nouveau PC reçu** peut éventuellement demander un changement de tempo suivant son contexte et son MODE.
- Conserver le BPM et le MODE sauvegardés du PC, sans écrasement ; la couleur orange indique toujours un écart entre BPM mémoire et BPM réellement lu.
- PAUSE reste possible depuis **AUM / une commande externe**, même si BEAT//4 n'affiche plus de bouton PAUSE.
- **Distinction :** cette règle traite une transition PLAY → PAUSE *pendant une rampe*. Si AUM est déjà en PAUSE lors de l’arrivée d’un nouveau PC, appliquer au contraire la règle de réception PAUSE du §9 (même effet immédiat que STOP).

**Test de recette :** AUM à 128, PC cible 135, MODE 1, rattrapage en cours ; AUM passe en PAUSE lorsque le BPM effectivement lu est ~131 → arrêter définitivement la rampe et conserver ce BPM ; au prochain PLAY sans nouveau PC, rester au BPM atteint ; les mémoires PC restent inchangées.

## 8. Affichage du MODE sauvegardé d’un PC — choix B confirmé en V07

**Décision explicite de l’utilisateur : B.** Le sélecteur à trois positions **affiche et édite toujours le MODE courant/global**, même si le PC rappelé possède un MODE propre mémorisé via SAVE. Il **ne se déplace pas** automatiquement sur le MODE sauvegardé du PC.

- Lorsque le PC rappelé possède un MODE sauvegardé, un **petit témoin distinct** identifie clairement cette valeur, par exemple `PC MODE 2`.
- Exemple : MODE global **0**, PC 007 avec MODE **2 sauvegardé** → le sélecteur reste visuellement sur **0** ; un témoin affiche **`PC MODE 2`** ; à réception pendant PLAY, le MODE **effectif** est **2** (rattrapage sur 2 beats) selon le contrat.
- Le MODE global reste **0**. La réception du PC n’écrase ni ne modifie le MODE global ; le témoin du PC ne transforme pas le sélecteur en commande de son MODE sauvegardé.
- Si l’utilisateur manipule le sélecteur sans SAVE, seule la sélection **globale** change. Si le PC a un MODE sauvegardé, ce dernier reste inchangé et conserve sa priorité au prochain rappel, tant qu’aucune nouvelle sauvegarde ne le remplace.
- Appuyer sur **SAVE** enregistre la position courante du sélecteur global comme **nouveau MODE propre au PC affiché**, sans enregistrer son BPM, sans modifier immédiatement le BPM actif et sans influer sur une rampe déjà engagée ; le témoin du PC est alors actualisé.
- Pour un PC sans MODE sauvegardé, aucun MODE propre ne doit être inventé ; le MODE global est appliqué au rappel. Le graphisme précis du témoin doit rester discret et respectueux de l’image de référence V02 ; **ne pas redessiner le reste de l’interface**.
- Distinction essentielle : la position du sélecteur = **MODE global éditable** ; le témoin = **MODE sauvegardé du PC** ; le MODE effectif à réception = **celui du PC s’il existe, sinon global**.

**Tests de recette :**
1. Global 0, PC 007 sauvegardé 2, réception en PLAY → sélecteur 0, témoin `PC MODE 2`, rampe 2 beats.
2. Global 1, même PC sauvegardé 2 → sélecteur 1, témoin 2, rappel toujours en 2 beats.
3. Sans SAVE, sélectionner global 0 → le témoin 2 est conservé ; nouvelle réception du même PC reste en MODE 2.
4. Avec SAVE lorsque le global est à 0 → le PC mémorise MODE 0, témoin actualisé, rampe éventuelle en cours intacte ; prochain rappel utilise MODE 0.
5. PC sans MODE mémorisé → le témoin ne doit pas présenter un MODE PC faussement sauvegardé ; rappel selon global.

## 9. PC reçu alors qu’AUM est déjà en PAUSE — choix A confirmé en V08

**Décision explicite utilisateur : A — se comporte comme STOP pour le rappel du BPM enregistré.**

- À l’instant précis de la **réception d’un nouveau message PC**, lire l’état réel d’AUM. Si AUM est **déjà en PAUSE**, et que ce PC possède un BPM mémorisé valide, **commander immédiatement ce BPM à AUM**. **Aucune rampe**, même si le MODE effectif serait 1 ou 2 ; le MODE global et le MODE sauvegardé propre au PC restent inchangés.
- Si le PC reçu en PAUSE **ne possède pas de BPM mémorisé**, ne commander aucun changement de BPM ; garder le BPM effectif du host.
- Cette action n’est déclenchée **ni par le passage en PAUSE lui-même**, ni par un simple retour à PLAY. Il faut une **nouvelle réception de PC alors que PAUSE est déjà actif**.
- Aucun BPM ni MODE mémorisé n’est réécrit par le rappel. Le BPM mémorisé du PC reste la valeur affichée ; l’orange subsiste uniquement tant que le BPM effectif AUM en diffère.
- Ne pas confondre les deux situations : **PAUSE survenant en pleine rampe** → annulation au BPM atteint (§7) ; **PC reçu alors que le host est en PAUSE** → application immédiate du BPM enregistré de ce PC. Si les deux événements sont proches, les traiter selon leur ordre réel.
- Si AUM ne fournit pas de signal PAUSE distinct de STOP, vérifier l’état réellement accessible lors de l’audit technique ; ne pas inventer une détection ou prétendre le comportement testé avant recette iPad/AUM.

**Tests de recette :** AUM en PAUSE à 128, PC 007 mémorisé à 135, MODE 0 → AUM demande immédiatement 135 ; répéter avec MODE 1 et 2 → même application immédiate, **sans rampe** ; PC sans BPM → conservation de 128 ; passage en PAUSE seul → aucun rappel ; reprise PLAY seule → aucun rappel ; les mémoires du PC restent identiques.

## 10. Autres FIX déjà acceptés sur le principe

- Préserver intégralement l'interface V02 comme référence ; ne pas modifier arbitrairement les barres, leur espacement/animation, KICK, SUB ni LEVEL.
- Un seul bouton **PLAY/STOP toggle** en bas à droite, sans PAUSE dans l'UI, sans cadre ; pictogramme reflétant l'état réel d'AUM.
- Retirer le protocole et les textes **MMC** de l'application ; préserver les commandes MIDI **APP → HOST** pertinentes, après audit du protocole réellement pris en charge par AUM.
- Nom de PC / SONG légèrement plus gros, afficher PC au lieu de PG.
- SAVE = MODE exclusivement ; BPM mémoire = glissement et enregistrement automatique.

## 11. Questions ouvertes, à ne pas trancher arbitrairement

1. **Faisabilité MIDI/AUM** : vérifier protocole et cadence de consignes de tempo, source musicale/position, retours BPM effectifs, synchronisation et gestion des erreurs ; ne pas affirmer une rampe réalisée sans test AUM.

## 12. Tests obligatoires (à compléter avec les choix à venir)

- Réception PC à STOP vs STOP isolé ; PC connu vs sans BPM ; PLAY modes 0/1/2 ; contrôle des durées 8 mesures et 2 beats sur hôte réel.
- Persistance de chaque BPM et MODE par PC, indépendance SAVE/BPM par glissement, couleur grise/orange/normale.
- PC suivant pendant rampe : interruption et redémarrage du BPM réellement atteint.
- STOP pendant rampe : annulation au BPM réellement atteint, pas de reprise automatique au PLAY suivant.
- **PAUSE provenant d’AUM pendant une rampe : même annulation définitive au BPM effectivement observé, sans continuation au PLAY suivant ; aucune écriture de mémoire PC.**
- **PC reçu alors qu’AUM est déjà en PAUSE : BPM mémorisé appliqué immédiatement quel que soit le MODE, sans rampe ; PC sans BPM reste neutre, PAUSE/PLAY seuls ne rappellent rien.**
- **MODE manipulé pendant rampe : aucun changement sur la rampe en cours ; nouveau MODE applicable à un prochain PC, sans réécriture de MODE PC hors SAVE.**
- **MODE enregistré distinct du sélecteur global :** sélecteur conserve le global, témoin indique le MODE propre au PC si enregistré ; priorité effective du MODE PC lors du rappel ; SAVE met uniquement à jour le témoin et la mémoire de MODE.
- Non-régression : quatre barres, sous-note/kick audio, LEVEL, commandes MIDI, transport, persistance, AUv3/AUM et iPad.

**Ce document constitue un contrat de travail, pas la preuve d'une implémentation ni d'une recette iPad.**
