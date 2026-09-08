# buildit-feature-run

## Status
to-ship

## Goal
Orchestrateur du cycle complet start → build → validate → ship.
Collecte les informations (worktree, nom, description, acceptance tests) en
début de session, puis délègue chaque phase à un subagent frais pour respecter
la contrainte d'isolation de contexte. Lit le statut du fichier tracking
entre chaque phase pour piloter la boucle GO/NO-GO. Accepte un paramètre
optionnel --max-cycles N (défaut 3). Compatible avec le dual-deployment
skills/ / .claude/skills/.

## Acceptance Tests
- [ ] Quand invoqué, l'orchestrateur collecte worktree (oui/non), nom,
  description et acceptance tests avant de lancer le moindre subagent
- [ ] Chaque phase (start, build, validate, ship) s'exécute dans un subagent
- [ ] Entre chaque phase, l'orchestrateur lit le statut du fichier tracking
  pour décider de la suite (to-ship → ship, to-fix → build)
- [ ] Si le fichier tracking est introuvable après start, l'orchestrateur
  s'arrête et avertit l'utilisateur
- [ ] Le chemin du worktree (s'il y en a un) est détecté après start via
  `git worktree list` et transmis aux subagents suivants
- [ ] Quand --max-cycles N est atteint sans GO, l'orchestrateur s'arrête et
  affiche le nombre de cycles écoulés
- [ ] Sur GO + PASS overall, l'orchestrateur lance ship et rappelle que push
  et PR restent manuels
- [ ] Le skill accepte un nom de feature optionnel en argument (passé aux
  subagents)
- [ ] Le README.md est mis à jour : le diagramme d'overview intègre
  buildit-feature-run comme alternative automatisée au flux manuel, et une
  section ### buildit-feature-run est ajoutée dans la liste des skills
- [ ] Un design spec
  docs/buildit/specs/YYYY-MM-DD-buildit-feature-run-design.md documente les
  choix non-évidents : isolation via subagents, signal-passing via statut du
  fichier tracking, détection du worktree post-start

## Plan

### Phase 1 — Discovery & context reading
1. Read existing skill files to understand format and conventions:
   - `.claude/skills/buildit-feature-start/SKILL.md`
   - `.claude/skills/buildit-feature-build/SKILL.md`
   - `.claude/skills/buildit-feature-validate/SKILL.md`
   - `.claude/skills/buildit-feature-ship/SKILL.md`
   - `skills/` directory for dual-deployment format
2. Read `README.md` to understand the current overview diagram and skills list format.
3. Read `docs/buildit/specs/` to understand the design spec format.
4. Check the test harness structure (`tests/`) to understand how skills are tested.

### Phase 2 — Write failing tests first (TDD)
Write tests in `tests/buildit-feature-run/` covering:
- `test_collects_inputs_before_subagents.sh` — verify skill prompts for worktree/name/desc/ATs before any subagent invocation
- `test_tracking_file_not_found_stops.sh` — verify halt when tracking file missing after start
- `test_status_routing.sh` — verify to-ship routes to ship, to-fix routes back to build
- `test_max_cycles.sh` — verify stop after N cycles without GO
- `test_worktree_detection.sh` — verify worktree path extracted from `git worktree list`
- `test_ship_reminder.sh` — verify push/PR reminder on GO+PASS

### Phase 3 — Implement the skill file
Create `skills/buildit-feature-run/SKILL.md` with:

**Structure:**
```
# Feature Run (Orchestrator)

## When to use
...

## Arguments
`/buildit-feature-run [feature-name] [--max-cycles N]`

## Steps

### 0. Parse arguments
### 1. Collect inputs (worktree, name, desc, ATs) if not provided via args
### 2. Subagent: buildit-feature-start
### 3. Detect tracking file path & worktree path
### 4. Loop (max N cycles):
   a. Subagent: buildit-feature-build
   b. Read tracking status
   c. If to-validate: subagent buildit-feature-validate
   d. Read tracking status
   e. If to-ship: break (GO)
   f. If to-fix: increment cycle counter, loop
   g. If max-cycles reached: stop + warn
### 5. On GO: subagent buildit-feature-ship + remind push/PR is manual
```

### Phase 4 — Deploy dual
Mirror the skill to `.claude/skills/buildit-feature-run/SKILL.md`.

### Phase 5 — Update README.md
- Add `buildit-feature-run` to the overview Mermaid/ASCII diagram as an automated alternative path.
- Add `### buildit-feature-run` section in the skills list.

### Phase 6 — Write design spec
Create `docs/buildit/specs/2026-09-08-buildit-feature-run-design.md` documenting:
- Isolation via fresh subagents (context boundary reasoning)
- Signal-passing via tracking file status (why not direct return values)
- Worktree detection post-start via `git worktree list` (and its known limitation with non-standard names)
- No-rollback behaviour on mid-phase failure

### Phase 7 — Run tests & iterate
Run `tests/run_tests.sh` (or equivalent harness). Fix until green.

## Self-critic corrections

### C1 — Verify actual file structure before writing
Do NOT assume skill paths or test harness format. During Phase 1 discovery,
read the actual directory structure of `skills/`, `.claude/skills/`, and
`tests/` before writing anything.

### C2 — Tests test skill content, not executable code
Skills are Markdown instructions. Tests likely check behavioural properties
(content patterns, scenario simulations). Study 2–3 existing test files before
writing new ones. Do not copy a test format that doesn't fit.

### C3 — --max-cycles parsing is a prompt-engineering problem
The skill instruction must explicitly state: "Look for `--max-cycles N` in the
invocation string. If absent, use N=3. N must be a positive integer." Add
validation: if N < 1, warn and use default.

### C4 — Stale tracking file on mid-phase crash
If a subagent crashes before updating status, the orchestrator re-reads the
same (pre-crash) status. Add rule: if the status has not changed after a
subagent completes, treat it as an error and stop with message:
"Tracking file status unchanged after [phase] — possible subagent failure."

### C5 — Unexpected status after validate must be handled
After validate, only `to-ship` and `to-fix` are expected. If status is
anything else (e.g. still `to-validate`, or `to-build`), stop with error:
"Unexpected status '[status]' after validate — manual inspection required."

### C6 — Read README before editing
The diagram format (Mermaid, ASCII, or plain) is unknown. Must read README.md
during Phase 1 and match the existing style exactly.

## Progress
<!-- updated during build phase -->
