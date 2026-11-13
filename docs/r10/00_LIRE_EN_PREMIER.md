# BEAT//4 — Paquet de reprise Codex R10 (13 novembre 2026)

**STATUT : VALIDÉ POUR CODEX — 14 FIX approuvés sans réserve le 13 novembre 2026.** Les travaux AUv3 restent à implémenter et à tester.

## Sources de vérité

1. **Graphisme figé : R02**, https://beat4-interface-lab.vercel.app/ et Drive `BEAT4/02_INTERFACE_LAB_VECTORIEL_V02/R02_ALIGNEMENTS_VALIDES/`. Barres, animation, typographie, dimensions, KICK/SUB/F/LEVEL et leur alignement. Ne rien changer hors petits éléments explicitement listés.
2. **Dernière maquette publiée avant consolidation : R05**, https://beat4-interface-lab-r05.vercel.app/. R05 sert de base technique aux pages PC mais **n'est plus conforme sur les couleurs, les titres et la logique QUEUE**.
3. **Nouvelle maquette de contrôle : R10**, issue de R05, destinée à visualiser les nouveaux titres, PC blanc/gris/éteint, champ QUEUE discret. Simulation navigateur, pas un AUv3 ni une mesure de timing. Ne pas la considérer comme code iOS.
4. **Contrat principal :** `01_CONTRAT_CONSOLIDE_R10.md`. Il prévaut sur les anciennes propositions incompatibles R04–R09. Les invariants BPM/MODE viennent de `01_CONTRAT_PC_TEMPO_FIX_V08.md` : ils restent valables, sauf leur moment d'application qui doit correspondre à l'activation effective lorsque le PC est en attente.
5. **Prompt de codage :** `03_PROMPT_CODEX_R10.md` ; **recette :** `04_RECETTE_R10.md`.

## Ce paquet ne prétend pas

- que l'application AUv3 existante a été modifiée ;
- qu'AUM fournit automatiquement une variable `bar` prédécoupée : Codex doit vérifier la position musicale réellement exposée ;
- qu'un PC externe queued indique la phase Drum 1 de Circuit ;
- que la simulation web prouve un MIDI/transport réel.

## Livrables requis de Codex

Code + tests unitaires et d'intégration + CI iOS + source de vérité des règles, branche/commit, démonstration AUM/Circuit, IPA seulement après vérification. Interdiction d'afficher PASS si un test physique reste non fait.
