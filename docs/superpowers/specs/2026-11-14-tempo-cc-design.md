# Tempo AUM par MIDI CC

Demande : corriger les envois tempo pitch bend jugés incohérents lors du test matériel, livrer une nouvelle IPA sur Drive. Plage utilisateur confirmée : 50–170 BPM. Base retenue : branche 0.5.8 `fix/r10-regression-repair`, afin de conserver la dernière livraison.

Choix d'implémentation annoncé : CC119 canal 15 absolu, plage AUM 50–177, valeur égale au BPM entier moins 50 ; pas exact de 1 BPM. Le mapping 50–170 sur les 128 valeurs CC donnerait des fractions, et MIDI Clock déplacerait le rôle de maître d'AUM. Le pitch bend reste écarté conformément à la demande.

Conserver l'UI, les mémoires, les modes, le transport et les deux câbles. Quantifier les rampes au BPM entier et supprimer les répétitions de CC identiques ; réaffirmer la consigne à chaque activation. Ne jamais tronquer silencieusement une ancienne mémoire hors de la plage technique 50–177. Version 0.5.9/build 9, tests portables et natifs, PR et compilation GitHub puis IPA seule sur Drive. Réglage AUM et recette matérielle documentés séparément.
