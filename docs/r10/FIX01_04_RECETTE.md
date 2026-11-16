# BEAT4 0.5.14 build14 — recette physique iPad / AUM / XONE

Statut : À EXÉCUTER. Les tests du host simulé ne valident ni l'iPad, ni AUM,
ni les octets effectivement envoyés par le K2. Noter iPadOS, modèle iPad,
versions AUM/Mozaic, signature, commit et SHA256 de l'IPA installée.
Préserver une copie de la session et de l'ancienne IPA avant essai.

## Routage XONE indispensable pour le SET

La source de référence Drive V3 commute immédiatement le transport au press.
Elle ne transmet pas la durée à BEAT4. Ne pas conserver simultanément ce toggle
et le nouveau gestionnaire BEAT4 : cela provoquerait des START/STOP parasites.

1. Charger `Integration/XONE_COMPLET_BEAT4_SET_V4.txt` dans une COPIE de la
   tranche Mozaic XONE COMPLET. Ce script conserve ses sorties LED canal15/note12
   et mute CC119/canal16, et retire seulement son ancien toggle CC110/111.
2. Ajouter XONE:K2 matériel → entrée MIDI BEAT4 pour les notes brutes.
3. Conserver XONE:K2 → Mozaic V4, les retours LED → K2 et mute → MIDI Control.
   Ne pas router la sortie LED Mozaic vers BEAT4 : ses notes périodiques sont
   des retours d'état, pas des appuis. Aucun loopback K2/LED.
4. BEAT4 AUM Control → MIDI Control : CC110/111 canal16 Start/Stop historiques ;
   CC118 canal15 tempo, plage50–177 comme en 0.5.13. BEAT4 Circuit Projects → Circuit.
   PC de contrôleurs indépendants → BEAT4 In2 (demandes quantifiées). Circuit
   → BEAT4 In1 conserve le protocole historique confirmations0–63 / queued64–127.
   Conserver AUM MIDI Clock/SPP et protections audio Circuit existantes.
5. Si la session utilise les trois scripts SAFE V1 plutôt que XONE COMPLET V3,
   désactiver seulement son ancien THRU transport immédiat ; garder LED et SAFE,
   et ajouter K2 brut → BEAT4. Ne pas router l'ancien transport en parallèle.

Le script V4 est un fichier texte candidat ; compilation/exécution Mozaic et
matrice réelle restent à vérifier sur iPad. Aucune session .aumproj existante
n'a été modifiée automatiquement.

## Sondes PRE / POST

PRE : copie du port matériel K2 vers sonde sans sortie ; relever pour PLAY
`9E 0C vv` (vv>0), puis `9E 0C 00` ou `8E 0C 00`.
POST : sondes sans sortie sur AUM Control et Circuit Projects.
Les événements du journal interne 10 contiennent status/data1/data2 entrants ;
4 = PC sorti, 6 = erreur sortie, 9 = transport émis. Ils complètent les sondes,
qui restent la preuve des routes physiques. Ne jamais connecter leurs sorties.

## Tableau de recette (PASS/FAIL + preuve à remplir)

| Essai | Manipulation et résultat attendu |
|---|---|
| FIX-01 | Aux formats720×400 et1024×768, symbole légèrement plus grand, centré sur UNKNOWN ; BPM et voisins lisibles. |
| FIX-02 | ACTIF16/32 STEPS et SAVE alignés ; changer le draft puis SAVE n'affecte que le SONG actif comme avant. |
| FIX-03 | Tap titre : MÉTRONOME → PC01–32 → PC33–64 → MÉTRONOME. Swipe ne navigue plus. Comparer active/BPM/QUEUE/transport avant/après. |
| Géométrie SET | Compter8 pads sur UNE ligne du TITRE ; hauteur visible <= texte du titre ; aucun pad sur TEMPO MODE ; visibilité ON/OFF. |
| Toucher | Chaque centre pad rappelle sa propre position ; titre n'est pas déclenché ; espaces voisins ne rappellent pas un autre pad. |
| Édition | `/`, choisir pad, puis SONG sur pagesPC. Remplacer, long pad pour vider. `/` termine. Pas de SAVE ajouté. Fermer/réouvrir pour vérifier auto-save. |
| Jeu SET | Configurer [vide,08,vide,12,vide,08,21,vide]. Premier PLAY=08 ; puis12,08,21. Doublons distincts ; vides ignorés ; terminal21 maintenu sans boucle ni STOP. |
| États | Curseur contour/ton gris, actif texte lumineux, QUEUED contour ambre ; seul l'actif musical change à la frontière. Effacer un pad actif supprime sa lumière sans arrêter le SONG. |
| Queue | Plusieurs PLAY avant frontière : seul dernier demandé exécuté. NEXT n'envoie aucun START. STEP16/32 du projet actif détermine la frontière. |
| Pad vs PC | Pad SET déplace immédiatement curseur ; pagePC et PC externe ne le déplacent pas. PC externe queued remplace le QUEUE SET ; PLAY repart du curseur mémorisé. |
| Circuit PC | Distinguer0–63 confirmation matérielle et64–127 demande queued ; une confirmation correspond à un changement déjà réalisé sur Circuit. Vérifier les deux par sondes. In2 : unPC0–63 de contrôleur indépendant doit rester queued pendantRUNNING et émettre sonPC uniquement à frontière. |
| ON/OFF | Bascule seule silencieuse. OFF pendantQUEUE le conserve. Réactiver conserve curseur. Vider les8 positions forceOFF sans supprimer le QUEUE existant. |
| STOP/reprise | Long PLAY en ON annuleQUEUE ; aucun PC annulé au START suivant. Curseur conservé ; PLAY aprèsSTOP poursuit. Tester STOP avant, au buffer de frontière, après. |
| RESET | LongSET ouvre confirmation. Annuler ne change rien ; confirmer garde8affectations/QUEUE. Au terminal atteint, prochainPLAY= premier ; intermédiaire= suivant. QUEUE exactement à frontière exécuté avantRESET. |
| XONE | Press seul : aucun NEXT. Release court : NEXT ou PLAY normal selon ON/OFF. Hold>=0,5s puis release : unSTOP, aucunNEXT préalable. NoteOff et NoteOn0. Répétition NoteOn maintenu ignorée. |
| iPad | Mêmes courts/longs ; glisser horsPLAY annule ; activation VoiceOver= court. SET OFF conserve toggle ordinaire. Long déjàSTOPPED ne relance pas. |
| BPM | STOPPED rappelPC, y compris SONG déjàactif : BPM enregistré immédiat avantSTART, aucun délai ajouté. PendantRUNNING comparer pentes montantes/descendantes avec0.5.13. |
| Modes historiques | La base0.5.13 expose16/32 et des rampes indépendantes des anciens modes0/1/2. Ce décalage préexistant est signalé dans l'audit ; aucune réinterprétation ajoutée ici. |
| Persistance | Réouvrir AU/AUM :8affectations, ON/OFF et curseur restaurés ; aucunSTART niQUEUE périmé rejoué. Tester curseur sur pad devenuvide. |
| Erreur MIDI | Sortie indisponible/échec : pas de fausse activation locale niSTART après échecBPM ; diagnostic visible dans journal. Rebrancher puis rappel explicite. |
| Frontières | Demandes à frontière−unbuffer, frontière, frontière+unbuffer ; STOP traité avantadvance dans mêmebuffer ; RESET aprèsadvance. Pas d'exécution anticipée. Ordre sample-exact intrabuffer non garanti par le moteur historique. |

À la fin, joindre captures de chaque vue, trace PRE/POST datée, résultats et
écarts. Ne marquer l'IPA « validée physiquement » qu'après cette recette réelle.
