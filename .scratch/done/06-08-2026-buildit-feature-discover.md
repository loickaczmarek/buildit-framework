# buildit-feature-discover

## Status
to-ship

## Goal
Créer un nouveau skill optionnel `buildit-feature-discover` à invoquer avant `/buildit-feature-start` quand l'utilisateur a besoin d'aide pour cadrer une feature. Le skill analyse le contexte projet, pose des questions ciblées à l'utilisateur pour comprendre le besoin fonctionnel, et produit un brief structuré (nom + description + acceptance tests + risques/contraintes) directement exploitable par `/buildit-feature-start`.

## Acceptance Tests
- [ ] Le skill se déclenche explicitement (commande `/buildit-feature-discover`) et non automatiquement depuis feature-start
- [ ] Phase analyse : le skill lit shared-context.md, les guidelines (.buildit/guidelines/), et scanne la structure du projet
- [ ] Le skill demande à l'utilisateur s'il dispose de documentation externe avant de poser ses questions
- [ ] Les questions posées permettent de comprendre le besoin fonctionnel (problème, utilisateurs, comportement attendu, critères de succès)
- [ ] La synthèse traduit le besoin fonctionnel en description technique cohérente avec les conventions du projet
- [ ] Le brief produit contient : nom kebab-case, description technique, acceptance tests exhaustifs, risques/contraintes identifiés
- [ ] Le brief est présenté à l'utilisateur pour validation avant d'être considéré comme finalisé
- [ ] La sortie propose explicitement d'enchaîner avec `/buildit-feature-start [feature-name]`

## Plan

### Phase 0 — Court-circuit si brief déjà clair
Vérifier si l'utilisateur a fourni un argument suffisamment précis (nom + description + acceptance tests). Si oui, sauter directement à Phase 4.

### Phase 1 — Analyse du contexte projet
1. Lire `.scratch/shared-context.md` → extraire les contraintes actives et décisions d'architecture qui pourraient impacter la feature
2. Lire `.buildit/guidelines/team-practices.md` et `language-framework.md` → comprendre les conventions de nommage, le format des skills, les patterns attendus
3. Lister les skills existants (`ls .claude/skills/`) et lire les premières lignes de chaque skill (name, description, when-to-use) → détecter les doublons potentiels et comprendre les patterns en place
4. Demander à l'utilisateur : "Avez-vous de la documentation externe à partager (specs, user stories, design doc) ?" → intégrer si oui, continuer sans sinon

### Phase 2 — Exploration fonctionnelle
Poser des questions **adaptées à ce que Phase 1 a révélé** :
- Questions de base : quel problème ? quels utilisateurs ? comportement attendu ? critères de succès ?
- Si un skill similaire existe → ajouter : "En quoi ce skill diffère-t-il de [skill existant] ?"
- Si une contrainte du shared-context s'applique → l'intégrer dans une question de périmètre
- Si le scope semble large → signaler et proposer de découper avant de continuer

### Phase 3 — Traduction technique
À partir de l'analyse et des réponses fonctionnelles :
- Identifier les fichiers/composants impactés
- Ancrer la description dans les patterns et conventions détectés (guidelines, skills existants)
- Signaler les risques actionnables : dépendances non triviales, surface d'impact large, zones floues dans les acceptance tests, scope trop large pour une seule feature

### Phase 4 — Génération du brief
Produire un brief structuré en markdown :

```markdown
## Brief : [feature-name]

**Nom :** [feature-name] (kebab-case)
**Description :** [description technique précise, ancrée dans les conventions du projet]

**Acceptance tests :**
- [ ] [critère vérifiable 1]
- [ ] [critère vérifiable 2]
...

**Risques & contraintes :**
- [risque 1 — avec impact estimé]
- [contrainte issue du shared-context ou des guidelines]
```

### Phase 5 — Validation & handoff
- Présenter le brief à l'utilisateur pour validation
- Sur correction → itérer uniquement sur les sections contestées
- Sur validation → afficher :
  > "Lancez `/buildit-feature-start [feature-name]` — le brief ci-dessus constitue votre input pour l'étape de collecte d'information du start skill."

## Problems to fix
- Duplicate English-only rule in `.buildit/guidelines/team-practices.md` — the same rule was added twice consecutively by the configuration update subagent (fix cycle 1). **Fixed in this validate pass** (removed duplicate; deduplication guard added to language-framework.md).

## Progress

### NO-GO cycle 1 — 06-08-2026
- Review: NO-GO — French strings throughout skill content; Claude-specific path hardcoded in Phase 1 step 3
- Acceptance: PASS — all 8 structural criteria passed

### NO-GO cycle 2 — 06-08-2026
- Review: NO-GO — duplicate English-only rule in `.buildit/guidelines/team-practices.md` (Style dimension). Fixed in this validate pass.
- Acceptance: PASS — all 8 criteria passed
