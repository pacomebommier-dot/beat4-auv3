# BEAT//4 0.5.9 / build 9 — tempo MIDI CC

Correctif demandé après test AUM : remplacer le pitch bend de tempo. Le répertoire utilise des BPM entiers entre 50 et 170.

## Réglage AUM nécessaire une fois

1. Installer la nouvelle version et conserver le routage **AUM Control → MIDI Control AUM**. La sortie **Circuit Projects** reste réservée au Circuit.
2. Ouvrir **MIDI CTRL → Transport → Tempo**, retirer l'ancienne affectation PBEND.
3. Choisir **CC**, numéro **118**, canal **15**, en contrôle absolu.
4. Régler les bornes de sortie de la plage AUM sur **50 BPM → 177 BPM** (CC 0 → CC 127), sans inversion. **Ne pas régler 50 → 170** : cela introduirait de nouveau un facteur d'échelle et des BPM fractionnaires.
5. Garder CC110/CC111 canal 16 pour PLAY/STOP. Retirer toute ancienne affectation de transport CC119 canal 15 si elle provient des consignes R10 initiales. Enregistrer la session AUM.

Le [manuel AUM](https://www.kymatica.com/aum/help) décrit le type CC et les bornes de mapping. Les noms exacts de contrôles peuvent varier selon la version AUM. Ce réglage est indispensable : un message CC ne contient pas une unité « BPM » et ne configure pas AUM à distance.

| BPM demandé | CC118 canal 15 | Octets hexadécimaux |
|---|---|---|
| 50 | 0 | BE 76 00 |
| 120 | 70 | BE 76 46 |
| 128 | 78 | BE 76 4E |
| 170 | 120 | BE 76 78 |
| 177 (borne technique) | 127 | BE 76 7F |

CC118 est réservé au tempo pour éviter le CC119 proposé pour le transport dans un ancien audit R10.

## Comportement

- Valeur transmise = BPM arrondi − 50. Les 121 BPM entiers du répertoire sont tous représentables exactement. Les bornes techniques 50–177 correspondent aux 128 valeurs MIDI ; 171–177 sont également représentables.
- Les modes et durées de rampe restent ceux de R10 : 8 mesures ou 2 beats. La sortie est quantifiée au BPM entier (écart maximal 0,5 BPM à la consigne intermédiaire), avec suppression des répétitions de la même valeur CC. Une nouvelle activation PC réaffirme sa consigne, même identique au dernier envoi.
- Les mémoires et l'éditeur existants 20–240 sont conservés. Un ancien BPM hors de 50–177 n'est **pas transmis**, plutôt que d'être tronqué vers un mauvais tempo. Régler ces éventuelles mémoires dans le répertoire 50–170 avant utilisation. Un départ de rampe hôte hors plage ne peut être commandé qu'à son entrée dans la plage représentable.
- Un PC sans BPM, l'édition du BPM seule, STOP/PAUSE ou la reprise seuls n'envoient pas de consigne de tempo supplémentaire. Les commandes de transport et les deux câbles MIDI sont conservés.
- Le retour BPM lu sur l'hôte reste l'autorité. La réception du CC ne constitue pas un acquittement du changement AUM.

## Recette sur iPad

1. AUM arrêté : rappeler successivement des PC mémorisés à 50, 120, 128 et 170 ; vérifier ces valeurs sur **l'affichage AUM**, sans démarrage du transport.
2. Répéter à PAUSE ; rappeler un PC sans BPM et vérifier l'absence de changement.
3. En PLAY : MODE 0 ne change pas le tempo ; MODE 1/2 monte puis descend entre 50 et 170 en 8 mesures / 2 beats. Vérifier l'arrivée exacte et l'absence de retour à l'ancien BPM. Les paliers de 1 BPM sont attendus.
4. Interrompre par un autre PC, puis par STOP/PAUSE ; vérifier les règles R10 existantes et l'absence de reprise automatique.
5. Vérifier PLAY/STOP, KICK/SUB/LEVEL, rappel PC et sauvegarde/rechargement de la session.

## Validation automatisée

Tests portables : tous les BPM 50–177, arrondis, valeurs invalides, montée/descente complète dans les deux modes (121 CC distincts), répétition à nouvelle activation et non-régressions R10. Le harness natif vérifie l'envoi réel par l'AU de CC118 canal 15 sur câble 0 aux BPM 50/128/170, le PC sur câble 1, l'absence de pitch bend, de tempo sur PC inconnu et d'envoi déclenché par la seule édition.

La CI compile l'app et l'extension et vérifie l'IPA 0.5.9/build 9. L'IPA suit la procédure de test existante : **non signée**, à signer avant installation. La recette matérielle AUM ne peut être déclarée validée par ces tests simulés.
