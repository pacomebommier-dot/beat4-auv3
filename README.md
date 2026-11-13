# BEAT//4 AUv3 — R10

Instrument AUv3 pour AUM, conservant le moteur KICK/SUB/LEVEL et les quatre barres du projet existant.

**Version de test R10 : 0.5.7 build 7. IPA non signée produite selon la procédure habituelle des livraisons V0.5.6 ; validation matérielle AUM/Circuit encore ouverte.**

Le [contrat consolidé R10](docs/r10/01_CONTRAT_CONSOLIDE_R10.md) est prioritaire. Les règles BPM/MODE du [contrat V08](docs/r10/01_CONTRAT_PC_TEMPO_FIX_V08.md) restent applicables au moment de l’activation effective du PC.

## Fonctionnement

Trois pages circulaires par swipe dans la région musicale : MÉTRONOME, PC 01–32, PC 33–64. Les 64 projets ont un état OFF sombre, SELECTED gris ou ACTIVE blanc. Un PC ne démarre jamais le transport.

La QUEUE optionnelle en beats appartient au PC sortant ; absence = prochain début de mesure AUM. Appui long sur un pad pour éditer sa QUEUE sans activer le projet. Les PC externes queued restent incertains sans observation d’activation ; l’activation locale est indiquée comme estimée, sans acquittement matériel inventé.

BPM entier mémorisé par glissement, sans effet immédiat sur AUM. SAVE ne mémorise que le MODE PC ; le sélecteur global reste indépendant. Modes : 0 sans consigne en PLAY, 1 rampe sur 8 mesures, 2 rampe sur 2 beats. Le retour de tempo et de transport AUM reste l’autorité.

## Routage à vérifier dans AUM

- Circuit canal 16 → entrée BEAT//4.
- Sortie **Circuit Projects** → Circuit uniquement : PC 0–63 émis à la frontière calculée pour éviter une seconde queue native.
- Sortie **AUM Control** → MIDI Control AUM uniquement : pitch bend canal 15, plage BPM 20–240 ; transport conservé de V0.5.6 : CC110 PLAY et CC111 STOP sur canal 16, impulsion 127 puis 0 au buffer suivant.
- AUM maître de la position, du tempo et du transport. Aucun message de commande transport émis par un rappel PC.

La réception exacte du mapping tempo/transport, la phase Drum 1 et le comportement matériel des valeurs queued doivent être vérifiés avant usage scène. Le scheduling est actuellement à résolution du buffer audio. Voir [audit, recette T01–T16 et limites](docs/r10/AUDIT_ET_RECETTE.md).

## Vérification et build

```sh
bash Tests/run.sh
BEAT4_SANITIZE=1 bash Tests/run.sh
```

Neuf exécutables C++ couvrent PC/QUEUE, tempo/MODE, octets MIDI, validation des mémoires, journal, transport, audio et géométrie. Les contrôles géométriques ne sont pas des captures UIKit.

Sur Mac : ouvrir `Beat4.xcodeproj`, schéma `Beat4App`, configurer les identifiants et la signature de l’app et de l’extension. Le workflow iOS sur runner Intel compile sans signature, exécute le test natif `Tests/test_persistence.mm` et produit douze captures UIKit avec assertions d’état/couleurs et trace MIDI sur hôte simulé (`Tests/native_snapshots.sh`). Après ces contrôles, il emballe une IPA non signée et vérifie les versions, identifiants et exécutables arm64 de l’application et de son extension. Le fichier sert à la procédure habituelle de signature/installation de test.

Les mémoires v2 sont enregistrées dans les préférences de l’extension. L’archive v1 est conservée ; les anciennes entrées brutes 64–127 ne sont pas fusionnées arbitrairement. Historique de l’ancien fonctionnement : [README V05 archivé](docs/archive/README_V05.md).
