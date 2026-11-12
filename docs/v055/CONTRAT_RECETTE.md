# BEAT4 V0.5.5 — pic lumineux sur le beat

Base source : 1cfce29792d5cfc3cae5e10500aa489970b4c6e4 (V0.5.4).
Demande validée dans la conversation : le beat doit être au pic, pas au début de la montée. Au premier START sans précompte, première barre immédiatement au pic. Autorisation : « fais le FIX ».

## Contrat
- PEAK-01 : à beat entier n, énergie de la barre n modulo 4 = 1. La valeur baisse immédiatement après ce beat.
- PEAK-02 : pendant la fraction f du beat n, barre n = (1-f)^1.5 ; barre n+1 = f^1.5. Toutes les autres sont à zéro. La barre suivante atteint 1 exactement à sa frontière, sans saut entre montée et décroissance.
- PEAK-03 : START à zéro : barre 1 au pic ; barre 4 noire, sans ancien flash. Seek/reprise en milieu de beat : phase hôte respectée ; aucun pic synthétique ajouté entre deux beats.
- PEAK-04 : STOP : extinction depuis l'énergie affichée en 300 ms. PAUSE : énergie du pas actif figée ; autres barres en extinction douce. Aucun changement au MIDI, audio, BPM ou stockage SONG.
- PEAK-05 : tests aux frontières 4->1, beats négatifs de pré-roll et reprise. L'animation dépend de la phase AUM ; aucune horloge musicale autonome.

La valeur mathématique du pic est exactement sur le beat. Le rafraîchissement écran reste discret (display link 60 Hz) : la simultanéité physique écran/audio doit être vérifiée sur iPad, elle n'est pas prouvée par les tests C++.

## Plan et preuves
- [x] Ajouter les attentes de pic à phase zéro et voir le test échouer sur la V0.5.4.
- [x] Corriger uniquement Beat4Display.hpp et Beat4Lights.hpp ; adapter les régressions LED.
- [x] Tests C++ et ASan/UBSan : 6 exécutables PASS, dont les tests de pics sur 16 frontières consécutives.
- [ ] Compilation native Xcode, version app/extension 0.5.5 build 5, archive et SHA256.
- [ ] Essais physiques iPad/AUM : non exécutés dans cet environnement.

## Recette iPad
1. Activer le métronome AUM ; START depuis zéro : barre 1 immédiatement lumineuse sur le premier beat.
2. À tempo lent, vérifier barre 2 qui monte avant beat 2, pic sur beat 2, puis décroît. Répéter les 4 pas et le passage 4->1, puis 60/120/180 BPM.
3. STOP pendant une montée puis START : pas de barre 4 fantôme ; premier pic sur beat 1. Vérifier fondu STOP 300 ms.
4. PAUSE en milieu de beat : pas actif figé, future barre qui décroît ; reprise conforme à la phase hôte. Aucun flash d'un pas précédent.
5. Vérifier CC START/STOP canal 16, mode CC/MMC mémorisé, PAUSE MMC, volume et audio tels qu'en V0.5.4.
6. Noter version AUM/iPadOS, buffer, fréquence, enregistrement vidéo/audio pour la perception physique de synchronisation.
