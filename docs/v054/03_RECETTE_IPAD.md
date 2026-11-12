# Recette iPad / AUM V0.5.4
Statut : NON EXÉCUTÉE. Relever iPadOS, version AUM, build BEAT4, fréquence, buffer, session, routage audio.

1. Session neuve, ajouter BEAT4 instrument, sortie audio vers sortie matérielle ; router AUM Control vers MIDI Control ET un moniteur MIDI capable SysEx.
2. Mode CC par défaut, appui long START pour changer de mode : Learn Start Play sur canal 16 CC110 ; Stop/Rewind sur CC111 ; déclenchement sur valeur haute (127), pas sur relâchement 0. Ne pas mapper Toggle Play. Sauvegarder session. Aucun mapping PAUSE.
3. Vérifier un appui START -> CC110 127 puis 0, STOP -> CC111 127 puis 0, PAUSE -> aucun CC110/111. En mode CC, aucun MMC START/STOP. 100 cycles, y compris STOP/START rapides. Compter les manqués et doubles commandes.
4. Mode MMC : désactiver le secours via le sélecteur, activer Receive MMC ; START/PAUSE/STOP, après chargement, fermeture/réouverture de fenêtre et rechargement du plugin. Comparer capture et état hôte ; pas de confirmation si callback hôte invalide.
5. STOP à chacune des 4 LED et diverses phases : énergie continue puis noir en 300 ms. START : LED précédente ne renaît pas. PAUSE : pas actif stable, autres au noir en 300 ms. Reprise et seek : phase conforme AUM. Répéter commandes depuis AUM et noter l'ambiguïté STOP sans rewind / PAUSE externe.
6. KICK ON : casque à niveau modéré, enregistrer PCM AUM. START/STOP en milieu de queue, changements rapides LEVEL et automation AU. Vérifier absence de scratch, clipping, valeur non finie. Comparer à V0.5.3 sur la même session.
7. Répéter 44.1/48/96 kHz, buffers 128/256/512 si supportés ; changement fréquence, reload, deux instances. Vérifier SONG/PG et tempo inchangés.

Preuves : capture MIDI, audio WAV, version/commit/SHA256, grille PASS/FAIL datée avec observations. Pas de « validé » sans ces éléments.
