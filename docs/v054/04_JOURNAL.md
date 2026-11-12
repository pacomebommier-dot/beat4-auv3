# Journal V0.5.4
2026-11-12 : source retrouvée dans GitHub ; base diagnostic 8fbcf30, branche locale fix/v054-transport-led-audio.
Causes visibles dans le code : canvas force énergie=0 lorsque moving=false ; barBrightness allume toujours le précédent au démarrage ; reset KickVoice et memset audio au STOP ; gain LEVEL changé par buffer ; STOP MMC attend origine et peut se répéter.
Décision : CC de secours et MMC START/STOP exclusifs, sélection visible ; PAUSE uniquement MMC. Risque évité : double STOP/rewind. Choix canal16 CC110/111, durées définies dans les contrats ; à vérifier sur iPad.
Les callbacks existent déjà dans V0.5.3 ; ne pas prétendre qu'ils sont absents. L'intermittence historique n'est pas reproduite ici.

## Implémentation locale et preuves
- CALL-01/02 : callbacks existants conservés et rafraîchis hors rendu ; fréquence relue par allocation ; intention reçue avant allocation conservée. Timestamp invalide -> message retenu, compteur de diagnostic. Une lecture invalide ne confirme plus un STOP/PAUSE.
- CALL-03 : STOP ne requiert plus l'origine ; un seul envoi accepté, pas de deuxième STOP pouvant rembobiner. PLAY/PAUSE : au plus 3 essais, intervalle 250 ms.
- MIDI-01/02 : CC110 START et CC111 STOP, canal 16, impulsion 127 puis 0 au buffer suivant ; sélecteur par appui long START. Le CC est émis même au repos pour Learn ; PAUSE reste MMC. Préférences de sélection conservées.
- LED-01/02/03 : enveloppe mémorisée, 300 ms de release, pause active figée, précédent interdit au redémarrage jusqu'à une frontière réelle. Display link maintenu pendant release seulement.
- AUD-01/02/03 : rampe transport 10 ms et volume 20 ms, pas de reset avant silence ; queue de voix amenée à zéro sur les 20 dernières ms, raccord de retrigger 5 ms.
- TRACE-01 : Tools/verify_v054.sh créé, archive source et manifest d'empreintes préparés.

Tests : 6 exécutables C++ PASS, puis les 6 sous GCC ASan/UBSan PASS ; versions/plists 0.5.4 PASS ; git diff --check PASS. clang++ absent dans cet environnement ; sanitizers exécutés avec le compilateur C++ disponible (GCC). Xcode/iOS SDK absent : compilation native NON EXÉCUTÉE. iPad/AUM NON TESTÉ.
Échecs de reproduction vus avant corrections : STOP exigeait encore origine ; répétition STOP après envoi accepté ; coupure de queue KickVoice à 750 ms. Le nouveau test v054 a d'abord échoué faute de composants, puis a exposé la coupure audio avant correction.
Relecture locale : correction de la phase projetée UI à travers une frontière de beat ; conservation d'une requête utilisateur avant allocation ; pas d'utilisation d'un snapshot partiel. Pas de revue indépendante.

## Blocage de livraison native
La tentative de création d'un arbre GitHub pour publier les modifications sur une branche dédiée a été rejetée par la revue automatique : le dépôt est public et la publication du code/documentation à cette destination n'était pas explicitement autorisée. Aucun contournement ni publication n'a été effectué. Une autorisation explicite de publication sur pacomebommier-dot/beat4-auv3 est nécessaire avant lancement du workflow macOS via la branche ; main reste intacte.

## Sources documentaires
- https://devnotes.kymatica.com/ios_midi_timestamps : sortie AUv3 via rendu et timestamp absolu en échantillons.
- https://gist.github.com/lijon/24b72cddc4964f73e1437cb31dfeb87d : ordre d'initialisation AUM.
- https://www.kymatica.com/aum/help : réception MMC et routage MIDI Control.
- https://github.com/teemow/auv3-probe/blob/main/docs/aum-control-surface.md : exemple public de pilotage AUM par CC ; ne vaut pas validation de BEAT4.

Restant : compilation Objective-C++ sous Xcode, IPA non signé, signature/installation par l'utilisateur et recette réelle iPad avec captures MIDI/audio. Aucune disparition de scratch ni fiabilité de transport sur AUM n'est encore certifiée.

Complément livraison : l'envoi de l'archive source complète dans Drive a aussi été rejeté par la revue automatique, qui demande une autorisation explicite pour ce contenu complet et cette destination. Les contrats, le plan, la recette, le journal, les logs et le manifest sont enregistrés dans le sous-dossier Drive ; l'archive complète reste locale. Aucun contournement tenté. Les deux autorisations à demander sont : dépôt de l'archive source complète dans BEAT4/V0.5.4_CORRECTIFS_ET_TRACABILITE, et publication sur une nouvelle branche du dépôt GitHub public identifié pour lancer la compilation iOS. Les IPA précédents et les branches distantes restent inchangés.
