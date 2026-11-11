# BEAT//4 V0.5.3 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Rétablir les commandes MMC vers AUM, adoucir et espacer les quatre barres, afficher la version, et remplacer la saisie BPM par un glissement horizontal entier.

**Architecture:** Le thread UI renouvelle les blocs hôte et publie seulement des pointeurs stables au rendu audio. Les décisions MMC, les courbes visuelles et le calcul du BPM glissé restent dans des fonctions C++ pures testables sous Linux ; UIKit ne fait que raccorder gestes et affichage.

**Tech Stack:** Objective-C++/UIKit, AUv3/AudioToolbox, C++17, tests shell C++, GitHub Actions/Xcode.

**Spec:** `docs/superpowers/specs/2026-11-11-v053-transport-visual-bpm-design.md`

## Global Constraints

- Projet BEAT//4 exclusivement ; aucune modification des sessions AUM.
- Version 0.5.3 build 4 ; IPA non signée distincte des anciennes versions.
- Aucune allocation, journalisation, E/S disque ou prise de verrou ajoutée au rendu audio.
- BPM SONG entier, borné à 20–240 et envoyé seulement à la fin du geste.
- La courbe d'extinction est le miroir temporel de l'allumage et dure un temps complet.
- Une CI PASS ne vaut pas validation physique dans AUM.

## Review Focus

- Callback MIDI remplacé entre désallocation et réallocation : la nouvelle instance doit être publiée avant l'envoi.
- Appel MIDI refusé : arrêt immédiat avec statut d'erreur visible, sans trois répétitions inutiles.
- Appel accepté sans changement AUM : répétitions bornées et résultat `NO ACK` après trois tentatives.
- Glissement BPM annulé ou PG changé pendant le geste : aucune valeur ne doit être enregistrée dans le mauvais slot.
- Changement de temps 4→1 : la barre 4 doit s'éteindre pendant que la barre 1 s'allume, sans rupture ni mauvais modulo.

---

### Task 1: Cycle de vie du callback MIDI et résultat MMC

**Files:**
- Modify: `Beat4AU/Beat4MMC.hpp`
- Modify: `Beat4AU/Beat4AudioUnit.mm`
- Modify: `Beat4AU/Beat4ViewController.mm`
- Test: `Tests/test_transport.cpp`

**Interfaces:**
- Produces: `enum class MMCAction { None, Send, Acknowledge, FailNoAck }`, `MMCDecision mmcRenderDecision(uint64_t word,bool goalReached,bool midiAvailable,uint32_t renderedFrames) noexcept`, `uint64_t mmcAfterSend(uint64_t word,int callbackStatus,double sampleRate) noexcept` ; snapshot `mmcLastStatus` et `mmcLastAcknowledged`.
- Consumes: callbacks AUM `transportStateBlock`, `musicalContextBlock`, `MIDIOutputEventBlock`.

- [ ] **Step 1: Write failing MMC transition tests**

Ajouter les assertions couvrant : statut non nul ⇒ échec immédiat sans retry ; `noErr` sans ACK ⇒ cooldown puis retry ; troisième `noErr` sans ACK ⇒ `NO ACK` ; changement d'état hôte ⇒ ACK et fin.

- [ ] **Step 2: Run tests to verify RED**

Run: `bash Tests/run.sh`
Expected: FAIL parce que l'API de transition et l'ACK explicite n'existent pas.

- [ ] **Step 3: Implement the pure MMC transition helper**

Dans `Beat4MMC.hpp`, produire une transition sans allocation qui conserve génération, commande, nombre d'essais et cooldown, et distingue erreur callback de non-ACK.

- [ ] **Step 4: Publish current host callbacks at every lifecycle boundary**

Dans `Beat4AudioUnit.mm`, relire les trois propriétés hôte hors rendu lors de l'allocation, après ressource marquée obsolète et immédiatement avant `requestMMC:`. Garder les anciens blocs vivants, publier le bloc courant atomiquement et ne jamais appeler Objective-C depuis le rendu.

- [ ] **Step 5: Expose actual result without flicker**

Dans le snapshot et `Beat4ViewController.mm`, afficher `MMC WAIT`, `MMC SEND <status>`, `MMC NO ACK`, `MMC <command> n/3` ou `MMC ACK`, uniquement lorsque le texte change.

- [ ] **Step 6: Run transport and full tests**

Run: `bash Tests/run.sh`
Expected: PASS.

- [ ] **Step 7: Commit**

Commit: `Fix AUM MIDI callback lifecycle and MMC status`

### Task 2: Courbe miroir et géométrie des barres

**Files:**
- Modify: `Beat4AU/Beat4Display.hpp`
- Modify: `Beat4AU/Beat4Kick.hpp`
- Modify: `Beat4AU/Beat4Layout.hpp`
- Modify: `Beat4AU/Beat4ViewController.mm`
- Test: `Tests/test_beat4.cpp`
- Test: `Tests/test_layout.cpp`
- Test: `Tests/test_songs_kick.cpp`

**Interfaces:**
- Produces: `beatRise(double)`, `barBrightness(int,int,double)`, `beatBarGap(double)`.
- Consumes: cellule active et fraction musicale déjà projetées depuis AUM.

- [ ] **Step 1: Write failing visual curve tests**

Tester montée monotone 0→1, `barBrightness(previous)==beatRise(1-fraction)`, extinction complète seulement en fin de temps, et modulo correct pour la barre précédente au passage 4→1.

- [ ] **Step 2: Write failing spacing tests**

Tester un écart supérieur d'environ 15 % à la formule V0.5.2, quatre barres positives et aucune sortie de la zone sur les huit tailles existantes.

- [ ] **Step 3: Run tests to verify RED**

Run: `bash Tests/run.sh`
Expected: FAIL car la barre précédente et `beatBarGap` n'existent pas.

- [ ] **Step 4: Implement mirror brightness and spacing**

Déplacer la responsabilité de luminosité dans `Beat4Display.hpp`, calculer simultanément la barre active et la précédente, puis utiliser `beatBarGap` dans le dessin UIKit.

- [ ] **Step 5: Run full tests and commit**

Run: `bash Tests/run.sh`
Expected: PASS.

Commit: `Smooth and space BEAT4 beat bars`

### Task 3: Réglage BPM entier par glissement

**Files:**
- Create: `Beat4AU/Beat4BPM.hpp`
- Modify: `Beat4AU/Beat4ViewController.mm`
- Modify: `Beat4AU/Beat4AudioUnit.mm`
- Test: `Tests/test_songs_kick.cpp`

**Interfaces:**
- Produces: `initialDraggedBPM(double saved,double host) -> int`, `draggedBPM(int start,double translationX,double pointsPerBPM=4) -> int`.
- Consumes: SONG du PG courant, BPM musical AUM, `saveSongBPM:` existant.

- [ ] **Step 1: Write failing BPM gesture math tests**

Tester BPM sauvegardé prioritaire, BPM AUM arrondi lorsque le slot est vide, déplacement inférieur au seuil, ±1 BPM à 4 points, grands déplacements et bornes 20/240.

- [ ] **Step 2: Run tests to verify RED**

Run: `bash Tests/run.sh`
Expected: FAIL car `Beat4BPM.hpp` n'existe pas.

- [ ] **Step 3: Implement pure integer BPM math**

Créer les deux fonctions pures, sans état ni allocation.

- [ ] **Step 4: Replace the alert with one pan gesture**

Au début : figer PG, BPM de départ et position. Pendant : mettre à jour le titre entier. À la fin : enregistrer une seule fois si le PG est inchangé. À l'annulation : restaurer le titre sans sauvegarde. Retirer l'alerte et le clavier numériques.

- [ ] **Step 5: Run full tests and commit**

Run: `bash Tests/run.sh`
Expected: PASS.

Commit: `Add integer BPM scrub control`

### Task 4: Version visible, paquet et vérification

**Files:**
- Modify: `Beat4AU/Beat4Layout.hpp`
- Modify: `Beat4AU/Beat4ViewController.mm`
- Modify: `Beat4AU/Info.plist`
- Modify: `Beat4App/Info.plist`
- Modify: `.github/workflows/ios.yml`
- Test: `Tests/test_layout.cpp`

**Interfaces:**
- Produces: label version lu depuis le bundle de l'extension ; artefact `BEAT4_V0_5_3_TRANSPORT_BPM_UNSIGNED.ipa`.

- [ ] **Step 1: Write failing version layout test**

Ajouter `version` au layout et vérifier qu'il reste visible, discret et sans chevauchement du logo sur toutes les tailles.

- [ ] **Step 2: Run tests to verify RED**

Run: `bash Tests/run.sh`
Expected: FAIL car le rectangle version n'existe pas.

- [ ] **Step 3: Add bundle-driven version label and bump package**

Afficher `v0.5.3` depuis le bundle de `Beat4ViewController`, passer application et extension en 0.5.3 build 4, et renommer l'artefact CI.

- [ ] **Step 4: Run fresh verification**

Run: `bash Tests/run.sh`

Run: `ASAN_OPTIONS=detect_leaks=0 BEAT4_SANITIZE=1 bash Tests/run.sh`

Run: `git diff --check`

Expected: toutes les commandes terminent avec le code 0.

- [ ] **Step 5: Publish and verify CI**

Publier sur la PR BEAT//4 existante, attendre les jobs `core-tests` et `ios-source-build`, puis vérifier l'artefact sans assimiler ce PASS à une recette iPad.

- [ ] **Step 6: Preserve prior artifacts and deliver**

Déposer l'IPA 0.5.3 dans le dossier Drive BEAT4 sans remplacer les IPA ni les sessions AUM existantes.

- [ ] **Step 7: Commit**

Commit: `Release BEAT4 0.5.3 transport and BPM controls`
