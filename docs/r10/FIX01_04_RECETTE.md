# BEAT4 0.5.14 build 14 — recette iPad / AUM / XONE

**Statut : À EXÉCUTER.** Les tests automatiques ne valident pas le matériel.
Noter le modèle d’iPad, iPadOS, les versions AUM/Mozaic, le commit, la signature
et le SHA256 de l’IPA. Conserver une copie de la session et de l’ancienne IPA.

## Routage XONE pour le SET

Le script XONE COMPLET V3 consomme la note du bouton et commute le transport
au press. Il empêche BEAT4 de mesurer la durée. Ne pas conserver ce toggle en
parallèle du gestionnaire BEAT4.

1. Dans une copie de la session, charger `Integration/XONE_COMPLET_BEAT4_SET_V4.txt` dans le Mozaic XONE COMPLET. Le V4 conserve les LED canal 15/note 12 et le mute CC119/canal 16 ; il retire le toggle immédiat CC110/111.
2. Ajouter le port matériel XONE:K2 → entrée MIDI BEAT4, pour les notes brutes.
3. Garder K2 → Mozaic V4, le retour LED → K2 et le mute → MIDI Control. **Ne pas router la sortie LED Mozaic vers BEAT4** : ses notes périodiques sont des retours d’état.
4. BEAT4 AUM Control → MIDI Control : CC110/111 canal 16 pour Start/Stop ; CC118 canal 15 pour le tempo, plage 50–177, comme en 0.5.13. BEAT4 Circuit Projects → Circuit. Conserver les routes d’horloge/SPP et les protections audio.
5. Circuit → BEAT4 In1 conserve les confirmations PC 0–63 et les demandes queued 64–127. Les contrôleurs PC indépendants → BEAT4 In2 envoient des demandes quantifiées.
6. Si la session utilise les trois scripts SAFE V1, désactiver seulement son ancien THRU transport immédiat ; garder LED et SAFE, puis ajouter K2 brut → BEAT4.

Le V4 est un texte candidat, dont la compilation et l’exécution Mozaic restent
à tester sur iPad. Aucune session .aumproj existante n’a été modifiée ici.

## Sondes MIDI

- PRE : copier le port matériel K2 vers une sonde sans sortie. Attendu : `9E 0C vv`, vv > 0, puis `9E 0C 00` ou `8E 0C 00`.
- POST : sondes sans sortie sur AUM Control et Circuit Projects.
- Journal interne : événement 10 = status/data1/data2 entrants ; 4 = PC émis ; 6 = erreur de sortie ; 9 = transport émis. Les sondes physiques restent la preuve des routes réelles.

## Résultats à remplir : PASS / FAIL / preuve

| Essai | Manipulation et résultat attendu |
|---|---|
| FIX-01 | En 720×400 et 1024×768, symbole légèrement agrandi et centré avec UNKNOWN ; BPM et voisins lisibles. |
| FIX-02 | ACTIF 16/32 STEPS et SAVE alignés. Le draft et SAVE continuent à viser le SONG actif. |
| FIX-03 | Tap du titre : MÉTRONOME → PC 01–32 → PC 33–64 → MÉTRONOME. Swipe inactif. SONG, BPM, QUEUE et transport inchangés. |
| Mini-pads | Compter huit pads sur UNE ligne du TITRE, jamais sur TEMPO MODE. Leur hauteur visible ne dépasse pas les lettres du titre. Visibles SET ON et OFF. |
| Toucher | Chaque centre de pad vise sa position ; aucun conflit avec le titre ou le pad voisin. |
| Édition | `/`, choisir un pad, puis un SONG sur une page PC. Remplacer ; appui long pour vider ; `/` termine. Aucun SAVE supplémentaire. |
| Parcours | Configurer [vide, 08, vide, 12, vide, 08, 21, vide]. Premier PLAY = 08 ; puis 12, 08, 21. Les doublons sont distincts. Le terminal 21 est maintenu, sans boucle ni STOP. |
| États | Curseur : gris/contour ; actif : texte lumineux ; QUEUED : contour ambre. L’actif musical ne change qu’à la frontière. Effacer son pad retire le témoin sans arrêter le SONG. |
| QUEUE unique | Plusieurs PLAY avant frontière : seul le dernier demandé est exécuté. Aucun START pendant NEXT. Le cycle 16/32 du projet actif détermine la frontière. |
| Pad / PC | Un pad SET déplace immédiatement le curseur. Page PC et PC externe ne le déplacent pas. Un PC externe remplace le QUEUE ; PLAY repart du curseur mémorisé. |
| Protocole PC | In1 : distinguer confirmation Circuit 0–63 et demande queued 64–127. In2 : PC indépendant 0–63 en attente pendant RUNNING ; émission du PC à la frontière seulement. |
| ON/OFF | Bascule seule silencieuse. OFF conserve un QUEUE déjà constitué. Réactivation conserve le curseur. Vider les huit pads force OFF sans supprimer le QUEUE. |
| STOP / reprise | Long PLAY en ON annule le QUEUE ; aucun PC annulé ne doit ressortir. Curseur conservé ; PLAY après STOP poursuit. Tester STOP avant, au buffer de frontière, après, et avant confirmation d’un START par AUM. |
| RESET | Long SET ouvre la confirmation. Annuler ne change rien ; confirmer garde affectations et QUEUE. Terminal atteint : prochain PLAY = premier ; position intermédiaire : suivant. À la frontière, QUEUE avant RESET. Tester aussi RESET puis PLAY rapprochés. |
| XONE | Press seul : aucun NEXT en SET ON. Release court : NEXT ou PLAY normal selon le contexte. Hold ≥ 0,5 s puis release : un STOP, aucun NEXT préalable. Tester Note Off, Note On 0 et répétitions pendant un maintien. |
| iPad | Courts/longs équivalents ; sortir du bouton avant release annule. VoiceOver = PLAY court. SET OFF garde le toggle normal. Long déjà STOPPED ne relance pas. |
| BPM arrêté | Rappeler un PC, y compris le SONG déjà actif : son BPM enregistré est appliqué immédiatement avant START, sans délai ajouté. |
| Tempo RUNNING | Comparer les pentes montantes/descendantes avec 0.5.13. La base expose 16/32 et des rampes indépendantes des anciens modes 0/1/2 ; ce décalage préexistant est signalé dans l’audit. |
| Persistance | Réouvrir AU/AUM : affectations, ON/OFF et curseur restaurés ; aucun START ni QUEUE périmé. Tester un curseur sur un pad devenu vide. |
| Échec MIDI | Sortie indisponible/échec : aucune fausse activation locale ni START après échec BPM. Consulter le journal, rebrancher puis rappeler explicitement. |
| Frontières | Demandes à frontière − un buffer, frontière, frontière + un buffer. STOP LONG avant advance dans le même buffer ; RESET après le QUEUE échu. Aucune exécution anticipée. L’ordre sample-exact intra-buffer n’est pas garanti par le moteur historique. |

Joindre les captures, les traces PRE/POST datées, les résultats et les écarts.
Ne déclarer l’IPA « validée physiquement » qu’après ces essais réels.
