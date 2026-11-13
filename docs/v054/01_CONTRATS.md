# BEAT4 V0.5.4 — contrats de correction
Date : 12 novembre 2026. Demande : callbacks d'abord, secours MIDI START/STOP uniquement, puis LED et audio.
Base : dépôt pacomebommier-dot/beat4-auv3, branche debug/transport-diagnostics-20261111, commit 8fbcf30. La V0.5.1 n'est pas une référence fonctionnelle présumée.

| ID | Correctif | Contrat / preuve attendue |
|---|---|---|
| CALL-01 | Vie des callbacks | Rafraîchir hors thread audio à l'allocation, sur demande et quand un callback manque. Garder les blocs publiés vivants ; ne pas allouer/verrouiller dans le rendu. Réinitialiser les états DSP lors d'une réallocation. Compilation iOS et recharge AUM obligatoires. |
| CALL-02 | Envoi et observation | Émettre uniquement avec un timestamp échantillon valide ; une lecture hôte invalide n'acquitte aucune commande. Retour callback = acceptation technique, pas preuve d'action hôte. Attendre 250 ms entre tentatives, 3 maximum pour PLAY/PAUSE ; un seul envoi STOP accepté pour éviter un rewind accidentel ; nouvelle demande remplace l'ancienne. |
| CALL-03 | STOP non répété | STOP vise l'état immobile, pas obligatoirement l'origine. Pas de deuxième STOP automatique après observation de l'arrêt. Le rembobinage dépend du réglage AUM ; ne pas le simuler par répétition. |
| MIDI-01 | Secours START / STOP | Une impulsion CC canal 16 CC110=127 pour START, CC111=127 pour STOP, puis 0 au buffer suivant. Émission à chaque appui explicite, même si AUM est déjà dans l'état cible, pour permettre Learn. Aucun CC de secours pour PAUSE. |
| MIDI-02 | Pas de double commande | En mode secours CC, pas de MMC START/STOP en parallèle. Un commutateur accessible permet de revenir au MMC seul. PAUSE reste MMC dans les deux modes. Mode CC choisi par défaut pour rendre le secours directement apprenable. Routage MIDI identique : AUM Control -> MIDI Control. |
| LED-01 | STOP doux | Depuis l'énergie réellement affichée, extinction douce en 300 ms ; dessin continue jusqu'au noir. Aucun pas nouveau au repos. |
| LED-02 | START propre | Après arrêt/repositionnement, la LED précédente ne renaît pas. Elle redevient éligible après une vraie frontière de pas. Le pas actif repart selon la phase hôte. |
| LED-03 | PAUSE | Figer l'énergie affichée du pas actif ; les autres décroissent en 300 ms. Une pause externe sans rewind est indiscernable d'un stop externe sans rewind : conserver cette limite explicite. Les commandes locales STOP et PAUSE sont distinguées. |
| AUD-01 | Départs/arrêts | Gain de transport progressif sur 10 ms ; pas de reset de voix avant fin du fondu. Redémarrage sans déclenchement artificiel au milieu d'un pas. |
| AUD-02 | Volume | Rampe de gain par échantillon de 20 ms, y compris lors de changements rapides et via paramètre AU. Sortie finie, bornée, sans saut de gain instantané. |
| AUD-03 | Fin/retrigger voix | Éviter la coupure de la queue à 750 ms et lisser le passage d'une voix encore active à un nouveau déclenchement. Tests à 44.1/48/96 kHz. |
| TRACE-01 | Traçabilité | Chaque livraison porte version, base, commit, SHA256, tests et statut iPad. Les IPA antérieurs restent inchangés. Un test C++ ne vaut ni compilation iOS ni validation AUM. |

Décisions techniques prises pour exécuter la demande : durées LED 300 ms, gain transport 10 ms, volume 20 ms ; CC110/111 canal 16. Vérifier les conflits dans la session utilisateur. Pas de remapping du tempo PB canal 15 ni de modification SONG/PG.

Approches : MMC seul conserve la configuration historique mais ne fournit pas de Learn ; MMC+CC simultanés peut doubler STOP ; deux modes exclusifs offrent le secours demandé sans doublon. Choix d'implémentation : modes exclusifs, sélection visible et conservée dans les préférences.

État : correctifs implémentés dans les sources locales et composants portables testés ; compilation iOS et validation iPad non réalisées. Les causes d'émission intermittente restent à confirmer par capture MIDI sur iPad.
