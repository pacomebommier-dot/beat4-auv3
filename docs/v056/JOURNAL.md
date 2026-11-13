# Journal V0.5.6
- Source de référence : 6952046b9b23b6d5af907e6bff79a970d7d3c6ef (V0.5.5).
- Choix explicite : prototype mon réglage à 120 BPM, montée 10 ms / extinction 290 ms ; conversion relative au BPM approuvée, puis demande de coder et préparer l'iPad.
- Demande additionnelle : extinction rapide sur STOP et autres barres lors de PAUSE, interprétée en cohérence avec la conversation comme 10 % d'un temps (50 ms à 120 BPM).
- Échec observé avant correction : test attendant énergie 0.5 à fraction 0.29 rejeté par la courbe V0.5.5.
- Code local : smoothstep cubique identique au prototype ; montée 0.02 beat, release 0.58 beat ; capture du dernier BPM valide pour le fondu STOP/PAUSE 0.10 beat. La durée en secondes est capturée à la transition de transport.
- Régressions : 7 exécutables C++ PASS puis les 7 sous GCC ASan/UBSan PASS. Plists 0.5.6 et git diff --check PASS. Essais de courbe sur 1001 phases par tempo, absence de chevauchement, STOP/PAUSE, perte de callback et pics aux frontières.
- Les callbacks AUM, l'audio, le mapping CC110/111 canal16 et la mémoire du mode MIDI ne sont pas modifiés. Le comportement réel iPad/AUM reste à vérifier ; le rapport de perte de temps/mesure n'est pas attribué à une cause non démontrée.
- Compilation native et livraison : en préparation, pas encore validées.
