# Réparation des régressions BEAT//4 — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Réparer les régressions non demandées de 0.5.7 et aligner son interface sur les références approuvées, sans annuler les fonctions R10.

**Architecture:** Partir du commit livré 688afe3. Réintroduire sélectivement les protections de 3f18d004, sans fusion aveugle de l’ancienne branche. Géométrie et style dérivés de V2/R02 ; comportement musical dérivé des contrats et des correctifs validés.

**Tech Stack:** Objective-C++, UIKit, AudioUnit, C++17, tests portables et harness natif existant.

**Spec:** Demandes utilisateur de cette session ; audit Drive 1ReYvwDNMyInAcl3WEPMAZxqcUvTpPOGN ; contrat R10 1VEXDcxrXhFo19fS5_imbsvTNY-fRHTpf ; référence V2 1-P-inFAT7mTogIXdy2bWBZKdKTJ0WX-C ; NOTES_FIX_ALIGNEMENT_R02 1xU9VTZxni6L_RmRRc2Il8jB1yWT4rb7F.

## Global Constraints

- AUM reste maître ; aucun PLAY implicite lors d’un PC ; anti-écho et sorties séparées conservés.
- 64 projets visibles 01–64 ; valeurs MIDI 0–63 ; QUEUE et MODE/SAVE selon contrats R10/V08.
- L’interface actuellement codée et la précédente IPA ne constituent pas des références graphiques faisant foi.
- Image V2 utilisateur prioritaire visuellement, ajustements R02 validés et ajouts ultérieurs explicitement approuvés. Le contrat V1 antérieur est dépassé sur les points modifiés par V2/R02.
- Le fichier image retrouvé est un PNG V2 ; ne pas affirmer avoir retrouvé un JPEG distinct.
- Pas de restauration de MMC/PAUSE graphique. Pas de surcharge de diagnostics dans la présentation approuvée : restaurer l’observabilité via snapshot/journal si nécessaire.
- Aucun écrasement des IPA existantes. Nouvelle construction iOS uniquement dans le cadre de la livraison corrigée, après vérification source.

## Review Focus

- Callbacks installés après allocation : récupération sans recharge manuelle.
- Réallocation avec sample rate différent : voix/gate/hôte remis à zéro, fréquence correcte.
- STOP/PAUSE/perte de synchronisation : enveloppes LED et audio conservées.
- Petits écrans/portrait : géométrie R02, lisibilité et cibles tactiles sans modifier les cadres visuels approuvés.
- PC pendant glissement BPM : aucune écriture dans le mauvais PC, aucune action tempo implicite.

### Task 1 — Référence graphique et matrice des écarts

**Files:** docs/r10/REGRESSION_REPAIR.md ; références téléchargées hors sources.
**Interfaces:** produit une matrice exigence → source approuvée → code → contrôle.
- [ ] Lire V2, notes R02, app.js R02 et ajouts contractuels R10 ; consigner les coordonnées et la hiérarchie des textes.
- [ ] Reclasser l’item 3 de l’audit : changement autorisé seulement s’il correspond aux références ; comparer largeur des barres, gradient, halos, lettrages et nouvelles indications.
- [ ] Documenter explicitement les contradictions ; aucune décision graphique par simple ancienneté ou date de fichier.

### Task 2 — Audio et lumières

**Files:** Beat4AU/Beat4Kick.hpp, Beat4AudioGain.hpp, Beat4Lights.hpp, Beat4Display.hpp, Beat4AudioUnit.mm, Beat4ViewController.mm ; Tests/test_v054.cpp, test_v056.cpp, Tests/run.sh.
**Interfaces:** Lights::update/energy, AudioGain::next/reset/silent, KickVoice::trigger/process ; garder API R10.
- [ ] Restaurer les tests comportementaux perdus et les lancer sur 0.5.7 pour constater les échecs avant correction ; garder les tests R10.
- [ ] Rétablir attaque LED 0,02 beat, release 0,58 beat, fondu STOP/PAUSE 0,10 beat et maintien PAUSE ; conserver le dessin fixé par Task 1.
- [ ] Rétablir lissages audio transport 10 ms et LEVEL 20 ms, raccord de voix 5 ms et fin de voix 20 ms.
- [ ] Vérifier les transitions PLAY/STOP/KICK OFF, perte callback, retrigger et 60/120/180 BPM, sans modification des modes PC/QUEUE.

### Task 3 — Cycle de vie AUM et validité des données

**Files:** Beat4AU/Beat4AudioUnit.mm, Beat4Transport.hpp ; Tests/test_transport.cpp, Tests/ui_snapshot_host.mm.
**Interfaces:** callbacks retained et slots atomiques ; render block existant, transportSnapshot et requestTransportToggle.
- [ ] Ajouter cas callbacks tardifs, reallocation 48→44,1 kHz, NaN/Inf et silence flag au harness ; constater la panne avant correction lorsque le runtime macOS est disponible.
- [ ] Rétablir refresh hors thread audio, durée de vie sûre des blocs, resets et fréquence acquise à allocation.
- [ ] Valider timestamp et données avant conversion/projection ; ne pas annuler la prise en charge des métriques du moteur QUEUE.
- [ ] Rétablir signalisation audio non silencieuse quand des échantillons sont produits ; tester callbacks refusés sans état confirmé inventé.

### Task 4 — Interactions, affichage et performance

**Files:** Beat4AU/Beat4BPMGesture.hpp, Beat4ViewController.mm, Beat4Layout.hpp ; Tests/test_layout.cpp, tests gestes et harness UIKit.
**Interfaces:** geste BPM existant, présentation R02 et états R10.
- [ ] Tester sensibilité précédente 4 points/BPM, repli 120 et changement PC pendant geste ; cibles transport >=44 points indépendantes du cadre visuel.
- [ ] Réparer numérotation ACTIVE 01–64 cohérente avec pads/SELECTED et rétablir optimisation au repos sans figer états ou fondus.
- [ ] Porter positions/tailles de Task 1 ; conserver version et indications prévues, diagnostics techniques dans API/journal si hors référence graphique.
- [ ] Contrôler 720×400, 667×375, 1024×768, 390×844 et comparer visuellement aux références, sans traiter les captures de démonstration comme validation musicale.

### Task 5 — Vérification et livraison reviewable

**Files:** Tests/run.sh, .github/workflows/ios.yml si nécessaire ; docs/r10/REGRESSION_REPAIR.md.
- [ ] Exécuter suite portable complète, ASan/UBSan et test packaging ; consigner résultats exacts.
- [ ] Exécuter persistance Foundation, harness AUv3/UIKit et build iOS si accès macOS/CI disponible ; ne pas déclarer ces étapes PASS à partir des tests Linux.
- [ ] Relire le diff complet : chaque modification reliée à un écart autorisé ; aucun retour graphique automatique à 0.5.6.
- [ ] Préparer correctifs et bilan pour revue ; distinguer correction source, vérification native et recette AUM/Circuit non disponible. Ne pas fusionner/publier silencieusement.

## Auto-revue du plan

Couverture : audit items 1–16 rattachés aux tâches 1–4 ; item 3 reclassé suivant précision utilisateur. Tests des cinq conditions de Review Focus rattachés aux tâches 2–4. Pas de changement de protocole ou de design inventé.
