# BEAT4 V0.5.6 — enveloppe choisie sur iPhone, relative au BPM

Base : 6952046b9b23b6d5af907e6bff79a970d7d3c6ef (V0.5.5).
Choix utilisateur dans le prototype HTTPS : montée 10 ms, extinction 290 ms à 120 BPM. Adaptation proportionnelle au BPM acceptée, puis « on peut coder préparer l’iPad et tout ». Ajout : STOP et PAUSE, barres devant s'éteindre vite, « genre 10% ».

## Contrats
- ENV-01 : pic sur chaque beat entier AUM. Montée sur les 2 % du temps qui précèdent le beat ; release sur les 58 % qui le suivent. Smoothstep cubique identique au prototype testé sur iPhone.
- ENV-02 : à 60 BPM : montée 20 ms, release 580 ms. À 120 : 10/290 ms. À 180 : 6,667/193,333 ms. À 240 : 5/145 ms. Les durées en secondes ne sont pas fixes.
- ENV-03 : la prochaine barre reste noire jusqu'à 98 % du temps courant. L'active est noire à partir de 58 %. Pas de chevauchement en lecture normale. START depuis zéro : barre 1 directement au pic, barre 4 noire.
- ENV-04 : STOP et autres barres lors de PAUSE : extinction progressive en 10 % de la durée d'un temps, soit 50 ms à 120 BPM. PAUSE fige l'énergie du pas actif. La durée du fondu est capturée à sa transition depuis le dernier BPM valide ; une perte temporaire de callback ne crée pas de division par zéro.
- ENV-05 : aucune modification du transport CC/MMC, des SONG/PG, du moteur audio ni du comptage AUM. Les 4 barres restent les 4 temps d'une mesure 4/4.
- TRACE-01 : publier sources, IPA non signée et preuves de compilation dans un sous-dossier V0.5.6 de BEAT4 ; conserver les versions antérieures. Les tests de calcul et la compilation ne prouvent pas la synchronisation physique iPad/AUM.

## Plan
- [x] Tests : courbe identique au prototype et limites 2/58/98/100 %, adaptation aux BPM ; observation de l'échec sur V0.5.5.
- [x] Modifier Beat4Display.hpp, Beat4Lights.hpp et branchement BPM dans Beat4Canvas ; vérifier toutes les régressions.
- [x] Versions app/extension 0.5.6 build 6, workflow de compilation dédié, checks/plists et sanitizers.
- [ ] Publication, compilation native, contrôle des binaires/version/SHA256 et livraison dans Drive.
- [ ] Validation physique AUM/iPad avec le métronome : reste à l'utilisateur après installation.

## Recette iPad
Signer/installer l'IPA comme les précédentes. Vérifier 60/120/180/240 BPM, quatre mesures d'affilée et retour 4->1. Comparer à l'essai retenu sur iPhone à 120 BPM. START à zéro, STOP pendant la release puis START, PAUSE pendant le pas actif puis pendant les 2 % de montée suivante : seul le pas actif reste figé, le reste s'éteint sur 10 % d'un temps. Vérifier CC110/111 canal16, PAUSE MMC et mode mémorisé, sans refaire les mappings.
