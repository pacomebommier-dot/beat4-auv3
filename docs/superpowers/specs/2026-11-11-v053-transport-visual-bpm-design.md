# BEAT//4 V0.5.3 — Transport, barres et BPM

## Intention

Livrer une correction ciblée de BEAT//4 après la recette physique V0.5.2 : rétablir les commandes PLAY / PAUSE / STOP vers AUM, rendre les quatre barres plus lisibles et plus douces, et remplacer la saisie BPM au clavier par un réglage tactile précis.

## Comportement retenu

- **Transport sortant** : renouveler le callback MIDI fourni par AUM lors des changements de ressources et juste avant une demande MMC. Afficher séparément la présence du callback, le statut réel de l'appel MIDI et l'accusé de réception déduit du transport AUM. Une nouvelle demande remplace proprement l'ancienne. Une répétition n'est permise qu'après un appel accepté sans changement d'état observé ; maximum trois tentatives.
- **Version visible** : afficher discrètement `v0.5.3` en petit gris à côté du logo `BEAT//4`, sans déplacer les commandes principales.
- **Animation** : pendant son temps, la barre active monte de 0 à 100 %. Pendant tout le temps suivant, cette même barre redescend de 100 à 0 % selon la courbe temporelle exactement inversée. La nouvelle barre monte simultanément. L'extinction dure donc un temps complet, sans coupure au changement de temps.
- **Géométrie** : augmenter l'espacement entre les quatre barres d'environ 15 % par rapport à la V0.5.2. Les barres deviennent légèrement plus fines tout en gardant la même zone générale et la même hiérarchie visuelle.
- **BPM SONG** : après réception d'un Program Change, glisser horizontalement sur la valeur BPM. Le déplacement est relatif, à raison de 4 points d'écran par BPM. Les valeurs sont entières, limitées à 20–240. Si le PG n'a pas encore de BPM, le geste commence au BPM AUM arrondi. La valeur s'affiche pendant le geste, mais n'est mémorisée et envoyée à AUM qu'au relâchement. Un simple toucher ne fait plus apparaître de clavier.

## Approches considérées

- **Retenue — réglage BPM relatif sur la valeur** : précision régulière, peu d'espace, aucun saut à la prise du doigt et ajustements fins faciles autour du tempo courant.
- **Écartée — grand curseur 20–240** : accès direct à toute la plage, mais précision insuffisante sur les vues AUv3 étroites.
- **Écartée — retour au MMC V0.5.1** : plus simple, mais conserve la perte silencieuse des commandes et ne distingue pas callback, émission et exécution AUM.

## Contraintes

- Ne pas modifier les sessions AUM de référence.
- Conserver le son du kick, son niveau, les SONG, la note SUB et le fonctionnement Program Change existants.
- Aucun verrou, log, allocation dynamique ni accès disque supplémentaire dans le rendu audio.
- Les données audio/interface restent atomiques ou copiées hors du thread audio.
- Les diagnostics restent stables lorsqu'aucune valeur visible ne change.
- Une CI PASS ne vaut pas validation physique dans AUM.

## Validation attendue

- Un appui unique sur PLAY / PAUSE / STOP produit une demande, un statut d'appel MIDI visible, puis un accusé de réception du transport AUM ou une erreur explicite.
- Les callbacks remplacés tardivement ou après réallocation sont effectivement republiés.
- À chaque changement de temps, la barre précédente décroît pendant un temps complet pendant que la suivante croît ; aucune chute instantanée.
- Les BPM mémorisés sont toujours des entiers compris entre 20 et 240 et un petit glissement permet d'atteindre exactement la valeur voisine.
- Aucun redessin des barres à l'arrêt sans changement visuel réel.
