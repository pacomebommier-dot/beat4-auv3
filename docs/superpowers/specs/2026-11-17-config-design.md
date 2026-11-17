# BEAT4 0.5.17 — configuration portable

Demande validée : import/export des SONGS, sauvegarde dans AUM, session privée renseignée ; ajout utilisateur : SET chargeable et éditable depuis des fichiers externes sans refaire IPA, teinte des pads PC renseignés.

Approche retenue après « Go » : JSON versionné, menus natifs Fichiers/partage, état AUv3 standard. Pas de serveur ni protocole de commande distant. La session et les JSON portent les données ; le binaire reste générique.

Format BEAT4_CONFIG v1 : tableau songs avec song 1..64, name, bpm 0 ou20..240, sub (note seule C/C#/Do/Ré...), steps optionnel16/32, queue/pcMode historiques optionnels. Champs omis conservés ; entrées invalides rejetées intégralement. SET optionnel : huit slots (SONG1..64 ou null), on, cursor1..8 ou null (une position devenue vide reste autorisée pour préserver le parcours après effacement), restart. Si curseur absent, premier renseigné et prochain PLAY au premier. Un fichier peut contenir seulement songs ou seulement set.

Import silencieux : aucun START/STOP/PC ; SONG et QUEUE en cours conservés. SET transmis au render par une commande groupée ; le nouveau parcours ne réaffecte pas une occurrence queued de l’ancien SET. Restauration AUM inclut les SONGS et la configuration SET, jamais le transport ou la file active. Une banque complète exportée par AUM remplace la banque à la restauration ; une session préparée partielle fusionne les24champs fournis et conserve les autres.

Menu sur logo : importer, exporter, diagnostic MIDI. Import prévisualisé (nombre SONGS/SET et BPM hors plage de transmission50..177), confirmation puis bilan. Export via partage iOS. Pads PC renseignés : vert sombre ; actif blanc et sélectionné gris prioritaires. Aucun nom personnel, JSON ou session utilisateur dans GitHub public.
