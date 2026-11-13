# BEAT//4 — Liste courte VALIDÉE pour Codex (R10)

**VALIDATION UTILISATEUR : 14/14 points approuvés, aucune réserve, 13 novembre 2026.** Les 12 rubriques ci-dessous regroupent les 14 points de la checklist affichée dans le fil. Cela autorise le passage au code ; cela ne signifie pas que les FIX sont déjà codés/testés.

1. **Graphisme** : R02 figée ; dernière maquette web d'avant consolidation = R05 ; nouvel aperçu R10 pour modifications ponctuelles uniquement.
2. **Pages** : swipe circulaire MÉTRONOME / PC 01–32 / PC 33–64 ; remplacer « AUM » par le titre courant ; PC reçu ne change pas la page.
3. **Grilles** : deux grilles de 8×4 = 64 SONG/PC ; noms 01–64 ; MIDI indexé 0–63, variantes queued à contrôler.
4. **Couleurs** : PC OFF sombre ; PC SÉLECTIONNÉ gris ; PC ACTIF blanc ; mêmes états dans les trois pages, PC actif seul pilote les informations musicales.
5. **Queue** : par SONG/PC, saisie discrète en beats entiers, sauvegarde automatique, sans Q ON/OFF ; pour passer de A à B en PLAY, queue du PC A.
6. **Queue absente** : activer au début du prochain BAR AUM, après le beat 4 ; une queue renseignée prend le dessus.
7. **STOP/PLAY** : à STOP PC immédiat sans lancer PLAY ; une demande de PC n'est pas une commande de transport ; PAUSE à tester séparément.
8. **AUM maître** : AUM fournit tempo, transport et position musicale ; BEAT//4 calcule l'échéance ; Circuit reçoit/transmet PC. Pas de seconde horloge maîtresse ni écho PC entrant vers Circuit.
9. **BPM mémoire** : entier par PC glissé au doigt et autosauvé ; BPM AUM distinct et observé ; changement uniquement à activation effective, pas sur une demande encore grise.
10. **MODE / SAVE / rampes** : MODE global 0/1/2 ; SAVE enregistre seulement MODE PC ; tempo 0 = ne rien faire, 1 = 8 mesures, 2 = 2 beats ; annulations/règles STOP–PAUSE selon V08.
11. **Non-régressions** : KICK et note SUB éditable, LEVEL, animations de barres plus fines et extinction douce, bouton transport PLAY/STOP, aucune réapparition de MMC.
12. **Tests** : priorités PC successifs, STOP/PAUSE pendant attente, départ de cycle sur Circuit, mapping PC immédiat/queued, tests AUM/iPad physiques avant IPA.

**Plus de Q ON/OFF. Plus de gris/ambre/vert mélangés. Plus de double paramètre Drum 1 et queue. Plus de « quatre beats après appui » en défaut.**
