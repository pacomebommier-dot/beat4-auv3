# BEAT//4 V0.5 — recette AUM (non exécutée)

**Ne pas confondre avec XONE.** Installer l'IPA BEAT//4 (lorsqu'elle sera construite et signée) comme une application distincte.

## Préparation

1. AUM : créer une tranche **Audio** dont la source est l'instrument AUv3 `B4MT: BEAT//4` (et non un effet MIDI pur).
2. Dans la MIDI Matrix : `Circuit Tracks MIDI OUT -> BEAT//4 MIDI IN` pour ses messages Program Change sur canal 16.
3. MIDI Matrix : `BEAT//4 MIDI OUT / AUM Control -> MIDI Control` (destination d'AUM).
4. Dans `MIDI CTRL > Transport > Tempo`, affecter **PBEND / canal 15**, et régler la plage cohérente **20–240 BPM** ; confirmer la correspondance réelle sur la valeur AUM.
5. Dans les contrôles Transport, activer `Receive MMC` pour les boutons Play/Pause/Stop de BEAT//4.
6. Activer `MIDI Clock Send` d'AUM vers l'entrée MIDI du Circuit, avec Circuit en réception d'horloge externe et TX Clock désactivé pour éviter une double horloge.

## Scénarios obligatoires

| ID | Action | Résultat attendu |
|---|---|---|
| B01 | Charger BEAT//4 | Fenêtre, quatre barres éteintes mais visibles ; KICK OFF |
| B02 | Circuit envoie PC 6 sur canal 16 | Affiche PG 006, UNKNOWN et BPM inconnu |
| B03 | Saisir `DARK ROOM`, `128`, `F` | Les trois valeurs sont conservées ensemble |
| B04 | Circuit envoie PC 7 ; saisir `HYPNOTIC`, `124`, `G` | Nouvelle fiche distincte |
| B05 | Revenir à PC 6 puis 7 | Nom + BPM + SUB rappels exacts à chaque retour |
| B06 | Revenir à PC 6 connu | AUM passe à 128 BPM (vérifier **affichage de l'hôte**, pas seulement l'envoi MIDI) |
| B07 | Envoyer PC inconnu sans BPM | Ne doit pas modifier le tempo courant d'AUM |
| B08 | AUM PLAY 4/4 | Les quatre barres suivent exactement la position de l'hôte |
| B09 | AUM PAUSE, CONTINUE, STOP, REWIND | Barres figées ou réinitialisées, sans horloge autonome |
| B10 | KICK ON ; lecture AUM 120/128 BPM | Un kick par noire, **pas un kick par buffer audio** |
| B11 | Passer PC 6 (F) à PC 7 (G) | La fondamentale grave change ; attaque commune |
| B12 | Slider LEVEL, puis AUM MIDI Learn Kick Level | Le même niveau change dans AUM et dans l'interface |
| B13 | Boutons PLAY, PAUSE, STOP de BEAT//4 | AUM suit les commandes, après routage MMC |
| B14 | Sauvegarder/fermer/recharger AUM | Noms, BPM et notes survivent à la relance |
| B15 | Modifier 44.1, 48, 96 kHz et buffers | Pas de clic supplémentaire, pas de blocage ni de clipping |
| B16 | Afficher sur iPhone et iPad, orientations possibles | Les barres restent lisibles et les commandes accessibles |

## Notes de sécurité

- BEAT//4 n'utilise **pas** Ableton Link et n'a pas besoin de l'autorisation réseau multicast.
- Le BPM cible est transmis en PBEND, sur un canal dédié : son envoi n'est **pas** la preuve qu'AUM a changé de tempo. Il faut vérifier le BPM lu du host.
- L'IPA générée par GitHub sans signature n'est pas installable telle quelle sur iOS.
- Ne pas laisser deux maîtres MIDI Clock piloter Circuit Tracks simultanément.
- La note de SUB est propre au PG ; le volume et KICK ON/OFF sont communs aux morceaux.
