#!/usr/bin/env bash
# Cross-skill contract tests: the contracts several skills must agree on — named
# shared blocks, status and heading vocabularies, and the start → build → validate
# → ship handoff. Checks contracts (who writes, who reads, in which step) rather
# than exact wording; full lines are pinned only when they are a machine contract.

set -euo pipefail

source "$(dirname "$0")/lib/assertions.sh"

S="skills"
START="$S/buildit-feature-start/SKILL.md"
BUILD="$S/buildit-feature-build/SKILL.md"
VALIDATE="$S/buildit-feature-validate/SKILL.md"
SHIP="$S/buildit-feature-ship/SKILL.md"
RUN="$S/buildit-feature-run/SKILL.md"
BOOTSTRAP="$S/buildit-project-bootstrap/SKILL.md"
TEAM=".buildit/guidelines/team-practices.md"
LANG_FW=".buildit/guidelines/language-framework.md"
PHASES=("$START" "$BUILD" "$VALIDATE" "$SHIP" "$RUN")

sorted_words() { tr ' ' '\n' | sed '/^$/d' | sort -u | tr '\n' ' ' | sed 's/ $//'; }

# --- Helper self-check: a heading inside a fence never ends a section ---------------
FIX=$(mktemp); trap 'rm -f "$FIX"' EXIT
cat > "$FIX" <<'EOF'
### 1. Step
before
~~~markdown
## Status
```
inner
```
~~~
after
### 2. Next
EOF
FIX_SEC=$(section "$FIX" '### 1. Step')
in_text "SELF: section continues past a heading inside a ~~~ fence" "$FIX_SEC" 'after'
absent_in_text "SELF: section stops at the next same-level heading" "$FIX_SEC" '^### 2\.'
same "SELF: fenced_block returns the fence content" "$(fenced_block "$FIX" '## Status' | head -1)" '## Status'
same "SELF: count_outside_fences ignores fenced lines" "$(count_outside_fences "$FIX" '## Status')" '0'
# absent_in_text must fail (not pass vacuously) on an empty or whitespace-only section.
self_absent() { # text — prints the helper output and its FAIL count, counters isolated
  ( PASS=0 FAIL=0; absent_in_text "x" "$1" 'foo'; echo "FAIL=$FAIL" )
}
OUT_EMPTY=$(self_absent "")
in_text "SELF: absent_in_text fails on empty text" "$OUT_EMPTY" 'FAIL=1'
in_text "SELF: absent_in_text names the empty-section cause" "$OUT_EMPTY" 'section empty or marker missing'
OUT_WS=$(self_absent $'  \n ')
in_text "SELF: absent_in_text fails on whitespace-only text" "$OUT_WS" 'FAIL=1'
OUT_OK=$(self_absent "bar")
in_text "SELF: absent_in_text passes on non-empty text without the pattern" "$OUT_OK" 'FAIL=0'

# --- AT-6: named shared blocks are identical in every carrier -------------------------
# Carriers are discovered by the exact heading line; MIN lists the carriers that must
# exist, so a block silently dropped from a file fails.
check_named_block() { # heading, reference file, min carriers...
  local heading="$1" ref="$2"; shift 2
  local ref_text carriers f
  ref_text=$(named_block "$ref" "$heading" | normalize)
  [[ -n "$ref_text" ]] && ok "AT-6: $heading defined in $ref" || fail "AT-6: $heading missing in $ref"
  carriers=$(grep -lxF -- "$heading" "$S"/*/SKILL.md .buildit/guidelines/*.md || true)
  for f in "$@"; do
    grep -qxF -- "$f" <<<"$carriers" && ok "AT-6: $heading carried by $f" || fail "AT-6: $heading missing from $f"
  done
  for f in $carriers; do
    same "AT-6: $heading appears once in $f" "$(count_outside_fences "$f" "$heading")" 1
    if [[ "$(named_block "$f" "$heading" | normalize)" == "$ref_text" ]]; then
      ok "AT-6: $heading identical to $ref in $f"
    else
      fail "AT-6: $heading in $f differs from $ref"
    fi
  done
}
check_named_block '**Operating mode rule**' "$TEAM" "$TEAM" \
  "$S/buildit-feature-discover/SKILL.md" "$RUN" "$S/buildit-plan/SKILL.md" "$VALIDATE" "$SHIP" \
  "$S/buildit-project-audit/SKILL.md" "$BOOTSTRAP"
check_named_block '**Tracking file discovery rule**' "$BUILD" "$BUILD" "$VALIDATE" "$SHIP" "$RUN"
check_named_block '**Plan task lookup rule**' "$RUN" "$RUN" "$S/buildit-feature-discover/SKILL.md"
check_named_block '**Plan line match rule**' "$RUN" "$RUN" "$S/buildit-feature-discover/SKILL.md"
in_text "AT-6: Plan line match rule anchors the task name with a trailing space" "$(named_block "$RUN" '**Plan line match rule**')" '`task-auth` must not match `task-auth-oauth`'

# Config value rule: an inline rule, restated (whitespace-normalised) by every consumer.
CVR='read only within that heading (stop at the next heading); a line starting with `#` is never a value'
CVR_FILES=("$LANG_FW" README.md "$VALIDATE" "$SHIP" "$RUN" "$S/buildit-feature-discover/SKILL.md" "$BOOTSTRAP" "$S/buildit-plan/SKILL.md")
for f in "${CVR_FILES[@]}"; do
  in_text "AT-6: Config value rule restated in $f" "$(normalize < "$f")" "$CVR"
done
# Old wording: every sentence naming the read must carry the boundary, wrapped lines included.
for f in "$S"/*/SKILL.md .buildit/guidelines/*.md README.md; do
  unbounded=$(normalize < "$f" | sed 's/\. /.\n/g' | grep -F 'first non-empty, non-comment line' | grep -vF 'read only within that heading' || true)
  [[ -z "$unbounded" ]] && ok "AT-6: no unbounded config read in $f" || fail "AT-6: unbounded config read in $f — $unbounded"
done
# Self-check: the normalised check catches a sentence wrapped across lines.
printf 'take the first non-empty,\nnon-comment line after it.\n' > "$FIX"
WRAPPED=$(normalize < "$FIX" | sed 's/\. /.\n/g' | grep -F 'first non-empty, non-comment line' | grep -vF 'read only within that heading' || true)
[[ -n "$WRAPPED" ]] && ok "SELF: unbounded check sees a line-wrapped sentence" || fail "SELF: unbounded check misses a line-wrapped sentence"

# Run's Subagent autonomy block: defined once, referenced by every phase launch.
same "AT-6: ## Subagent autonomy block heading appears once in run" "$(count_outside_fences "$RUN" '## Subagent autonomy block')" 1
AB_BODY='Autonomy: you are operating within the project directory'
same "AT-6: autonomy block body defined once across skills" "$(grep -c -- "$AB_BODY" "$S"/*/SKILL.md | awk -F: '{n+=$2} END{print n+0}')" 1
in_text "AT-6: autonomy block body lives in its section" "$(section "$RUN" '## Subagent autonomy block')" "$AB_BODY"
AB_REF='[Autonomy block — see "Subagent autonomy block"]'
same "AT-6: start launch references the autonomy block" "$(grep -cF -- "$AB_REF" <<<"$(section "$RUN" '### 3. Subagent: buildit-feature-start')" || true)" 1
same "AT-6: build and validate launches reference the autonomy block" "$(grep -cF -- "$AB_REF" <<<"$(section "$RUN" '### 5. ')" || true)" 2
same "AT-6: ship launch references the autonomy block" "$(grep -cF -- "$AB_REF" <<<"$(section "$RUN" '### 6. ')" || true)" 1

# Shared prerequisite stop: audit still needs shared-context.md and stops the same way.
PRE_MSG='> "Shared context file not found — run `/buildit-project-bootstrap` to initialize the project."'
for f in "$S/buildit-project-audit/SKILL.md"; do
  PRE=$(section "$f" "$(grep -m1 -E '^### [0-9]+[a-z]?\. Prerequisite check' "$f" || echo '@@missing@@')")
  in_text "AT-6: $f prerequisite check tests shared-context.md" "$PRE" 'If `.scratch/shared-context.md` does not exist, stop with:'
  in_text "AT-6: $f prerequisite check uses the shared stop message" "$PRE" "$PRE_MSG"
done
# Feature phases never stop on a missing shared-context.md: start creates it, the others treat it as empty.
ABSENT_EMPTY='If `.scratch/shared-context.md` does not exist, treat it as empty'
for f in "$START" "$BUILD" "$VALIDATE" "$SHIP"; do
  require_absent "AT-SCL-3: $f has no missing-shared-context stop" "$f" 'Shared context file not found'
done
for f in "$BUILD" "$VALIDATE" "$SHIP"; do
  require_text "AT-SCL-3: $f treats an absent shared-context.md as empty" "$f" "$ABSENT_EMPTY"
done
# Start and bootstrap create shared-context.md from the same template (four headings in order, table header).
START_SC=$(fenced_block "$START" '# Shared Context'); BOOT_SC=$(fenced_block "$BOOTSTRAP" '# Shared Context')
same "AT-SCL-2: start and bootstrap shared-context templates have the same section headings" "$(grep '^## ' <<<"$START_SC")" "$(grep '^## ' <<<"$BOOT_SC")"
same "AT-SCL-2: shared-context template has exactly the four sections" "$(grep '^## ' <<<"$BOOT_SC" | tr '\n' '|')" '## API & Contracts modified|## Constraints discovered|## Decisions & Conventions|## Merge readiness|'
same "AT-SCL-2: start and bootstrap shared-context templates are identical" "$START_SC" "$BOOT_SC"
in_text "AT-SCL-2: template has the Merge readiness table header" "$BOOT_SC" '| Branch | Status | Main files touched |'
# This repository: shared-context.md is gitignored and not tracked.
require_regex "AT-SCL-1: this repo's .gitignore lists .scratch/shared-context.md" ".gitignore" '^\.scratch/shared-context\.md$'
if git rev-parse --git-dir >/dev/null 2>&1; then
  if git ls-files --error-unmatch .scratch/shared-context.md >/dev/null 2>&1; then fail "AT-SCL-1: .scratch/shared-context.md must not be tracked"; else ok "AT-SCL-1: .scratch/shared-context.md is not tracked"; fi
else
  ok "AT-SCL-1: not a git repository — tracking check skipped"
fi
# Rules files: shared-context.md is local, untracked; no closing-commit cleanup rule.
for f in .claude/CLAUDE.md; do
  require_absent "AT-SCL-5: $f drops the closing-commit cleanup rule" "$f" 'mandatory in the closing commit'
  require_regex "AT-SCL-5: $f says shared-context.md is local, untracked state" "$f" 'shared-context\.md`? is local, untracked state'
  require_text "AT-SCL-5: $f migrates durable entries at ship time" "$f" 'migrate into the appropriate guideline at ship time'
done

# --- AT-4: status, tracking-file heading and config heading vocabularies --------------
RULE=$(named_block "$BUILD" '**Tracking file discovery rule**')
STATUSES=$(grep -oE 'feature status: [^.]*' <<<"$RULE" | grep -oE '`[a-z-]+`' | tr -d '`' | tr '\n' ' ' | sorted_words)
same "AT-4: the discovery rule lists the six feature statuses" "$STATUSES" "$(echo building to-build to-fix to-ship to-validate validating | sorted_words)"
for f in "$S"/*/SKILL.md README.md .buildit/guidelines/*.md .claude/CLAUDE.md; do
  for t in $(grep -oE '`to-[a-z-]+`' "$f" | tr -d '`' | sort -u); do
    grep -qw -- "$t" <<<"$STATUSES" && ok "AT-4: status $t in $f is a feature status" || fail "AT-4: unknown status $t in $f"
  done
done
for f in "$BOOTSTRAP" "$TEAM" .claude/CLAUDE.md; do
  FLOW=$(grep -E '^(- )?Status (flow|in each tracking file):' "$f" || true)
  [[ -n "$FLOW" ]] || { fail "AT-4: no status flow line in $f"; continue; }
  same "AT-4: status flow in $f names exactly the feature statuses" \
    "$(grep -oE 'to-[a-z]+|building|validating' <<<"$FLOW" | tr '\n' ' ' | sorted_words)" "$STATUSES"
done

TPL=$(fenced_block "$START" '# [feature-name]')
TEMPLATE_HEADINGS=$(grep -E '^## ' <<<"$TPL" | sed 's/^## //')
TRACKING_HEADINGS=$(printf '%s\nProblems to fix\nLast error\n' "$TEMPLATE_HEADINGS")
same "AT-4: start template headings" "$(tr '\n' '|' <<<"$TEMPLATE_HEADINGS")" 'Status|Branch|Worktree path|Goal|Acceptance Tests|Plan|Progress|'
for f in "$BOOTSTRAP" "$TEAM"; do
  LIST=$(grep -m1 '^Tracking file sections:' "$f" | sed 's/^Tracking file sections: //; s/ · /\n/g')
  same "AT-4: tracking file section list in $f matches start's template + Problems to fix + Last error" "$LIST" "$TRACKING_HEADINGS"
done
in_text "AT-4: validate writes the Problems to fix section" "$(section "$VALIDATE" '### 5b.')" '## Problems to fix'

CONFIG_HEADINGS=$(fenced_block "$BOOTSTRAP" '# Project Configuration' | grep -E '^## ' | sed 's/^## //')
[[ -n "$CONFIG_HEADINGS" ]] && ok "AT-4: config.md template headings found" || fail "AT-4: config.md template headings missing"
PLAN_TASK_HEADINGS=$'Description\nAcceptance tests\nReadiness\nSynchronization'
KNOWN=$(printf '%s\n%s\n%s\n' "$TRACKING_HEADINGS" "$CONFIG_HEADINGS" "$PLAN_TASK_HEADINGS")
while IFS= read -r h; do
  grep -qxF -- "$h" <<<"$TRACKING_HEADINGS" && fail "AT-4: config heading '$h' collides with a tracking-file heading" || ok "AT-4: config heading '$h' is not a tracking-file heading"
  require_text "AT-4: config heading '$h' documented in $LANG_FW" "$LANG_FW" "\`## $h\`"
  consumers=$(grep -lF -- "\`## $h\`" "${PHASES[@]}" "$S/buildit-plan/SKILL.md" "$S/buildit-feature-discover/SKILL.md" || true)
  [[ -n "$consumers" ]] && ok "AT-4: config heading '$h' has a consumer skill" || fail "AT-4: config heading '$h' has no consumer skill"
done <<<"$CONFIG_HEADINGS"
for f in "${PHASES[@]}"; do
  for h in $(grep -oE '`## [^`]+`' "$f" | sed 's/^`## //; s/`$//' | tr ' ' '_' | sort -u); do
    h=${h//_/ }
    grep -qxF -- "$h" <<<"$KNOWN" && ok "AT-4: '## $h' in $f is a known heading" || fail "AT-4: '## $h' in $f is neither a tracking-file, config nor plan-task heading"
  done
done
for f in "$START" "$BUILD" "$VALIDATE" "$SHIP"; do
  while IFS= read -r h; do
    require_absent "AT-4: plan-task heading '## $h' not read by $f" "$f" "\`## $h\`"
  done <<<"$PLAN_TASK_HEADINGS"
done

# --- AT-7: phase handoff start → build → validate → ship --------------------------------
in_text "AT-7: start hands off to build" "$(section "$START" '## End of skill')" '/buildit-feature-build'
in_text "AT-7: build hands off to validate" "$(section "$BUILD" '## End of skill')" '/buildit-feature-validate'
V_GO=$(section "$VALIDATE" '## If GO + PASS overall')
in_text "AT-7: validate GO hands off to ship" "$V_GO" '/buildit-feature-ship'
in_text "AT-7: validate NO-GO hands off to build" "$(section "$VALIDATE" '## End of skill (NO-GO / FAIL)')" '/buildit-feature-build'
L_START=$(line_of "$RUN" '### 3. Subagent: buildit-feature-start')
L_BUILD=$(line_of "$RUN" '**Subagent: buildit-feature-build**')
L_VAL=$(line_of "$RUN" '**Subagent: buildit-feature-validate**')
L_SHIP=$(line_of "$RUN" '**Subagent: buildit-feature-ship**')
if [[ -n "$L_START" && -n "$L_BUILD" && -n "$L_VAL" && -n "$L_SHIP" ]] && (( L_START < L_BUILD && L_BUILD < L_VAL && L_VAL < L_SHIP )); then
  ok "AT-7: run launches start → build → validate → ship in that order"
else
  fail "AT-7: run must launch start ($L_START) → build ($L_BUILD) → validate ($L_VAL) → ship ($L_SHIP)"
fi

# Status each phase sets and the next one expects (values extracted, then compared).
status_set() { grep -oE '[Ss]et the status to `[a-z-]+`' <<<"$1" | tail -1 | grep -oE '`[a-z-]+`' | tr -d '`'; }
B1=$(section "$BUILD" '### 1. '); B5=$(section "$BUILD" '### 5. ')
V1=$(section "$VALIDATE" '### 1. '); SH0=$(section "$SHIP" '### 0. ')
R5=$(section "$RUN" '### 5. ')
TPL_STATUS=$(grep -A1 -x '## Status' <<<"$TPL" | tail -n +2)
same "AT-7: start writes to-build" "$TPL_STATUS" 'to-build'
in_text "AT-7: build expects start's status" "$B1" "expects \`$TPL_STATUS\` or \`to-fix\`"
same "AT-7: build marks itself building" "$(status_set "$B1")" 'building'
BUILD_OUT=$(status_set "$B5")
same "AT-7: build hands over to-validate" "$BUILD_OUT" 'to-validate'
in_text "AT-7: validate expects build's output status" "$V1" "buildit-feature-validate expects \`$BUILD_OUT\`"
same "AT-7: validate marks itself validating" "$(status_set "$V1")" 'validating'
in_text "AT-7: run checks build's output status" "$R5" "If status ≠ \`$BUILD_OUT\`"
V_GO_OUT=$(status_set "$V_GO"); V_NOGO_OUT=$(status_set "$(section "$VALIDATE" '### 5b.')")
same "AT-7: validate GO sets to-ship" "$V_GO_OUT" 'to-ship'
same "AT-7: validate NO-GO sets to-fix" "$V_NOGO_OUT" 'to-fix'
in_text "AT-7: ship expects validate's GO status" "$SH0" "does not have status \`$V_GO_OUT\`"
in_text "AT-7: build accepts validate's NO-GO status" "$B1" "\`$V_NOGO_OUT\`"
in_text "AT-7: run breaks the loop on validate's GO status" "$R5" "\`$V_GO_OUT\` → break the loop (GO)"
in_text "AT-7: run loops on validate's NO-GO status" "$R5" "\`$V_NOGO_OUT\` → continue loop"

# ## Branch: start writes it once (step 3); ship step 0 and run step 6 read it.
START3=$(section "$START" '### 3. ')
in_text "AT-7: start step 3 template has ## Branch" "$TPL" '## Branch'
in_text "AT-7: start step 3 documents the ## Branch contract" "$START3" '**`## Branch` contract**'
in_text "AT-7: ship step 0 reads ## Branch" "$SH0" 'read the `## Branch` value from the tracking file'
in_text "AT-7: run step 6 reads ## Branch for SHIP_REF" "$(section "$RUN" '**Record the pre-ship state**' '**Subagent: buildit-feature-ship**')" 'the `## Branch` value of the tracking file'
for f in "$BUILD" "$VALIDATE" "$SHIP" "$RUN"; do
  require_absent "AT-7: $f never writes ## Branch" "$f" '([Ww]rite|[Uu]pdate|[Rr]ewrite|[Aa]dd)s? (the |a )?`## Branch`'
done

# ## Last error: each writer skill (build, validate, ship) defines its Deliberate stop
# procedure once — the only place that states the write instruction — and every stop
# references it with its reason. No phase clears a stale line: feature-run is the only clearer.
PROC_HEAD='**Deliberate stop procedure**'
WRITE_INSTR='`## Last error` section to the tracking file with the single line'
REPLACE='replacing any existing `## Last error` section'
for f in "$BUILD" "$VALIDATE" "$SHIP"; do
  sk=$(basename "$(dirname "$f")")
  same "AT-7: $sk defines the Deliberate stop procedure once" "$(count_outside_fences "$f" "$PROC_HEAD")" 1
  PROC=$(named_block "$f" "$PROC_HEAD" | normalize)
  in_text "AT-7: $sk procedure writes its Last error line" "$PROC" "$WRITE_INSTR \`$sk: <reason>\`"
  in_text "AT-7: $sk procedure replaces any existing section" "$PROC" "$REPLACE"
  in_text_re "AT-7: $sk procedure states the status rule" "$PROC" '[Ss]tatus'
  same "AT-7: $sk states the Last error write instruction only in its procedure" \
    "$(lines_outside_fences "$f" '.' | normalize | grep -oF -- "$WRITE_INSTR" | wc -l | tr -d ' ')" 1
  require_absent "AT-7: $sk no longer clears a stale ## Last error" "$f" 'If the tracking file has a `## Last error` section, remove it|describes a previous run'
done
for f in "$S"/buildit-feature-*/SKILL.md; do
  case "$f" in "$BUILD"|"$VALIDATE"|"$SHIP") continue ;; esac
  require_absent "AT-7: $f is not a Last error writer" "$f" "$PROC_HEAD"
done
# stop_ref LABEL TEXT REASON — the stop applies the procedure with its reason.
stop_ref() {
  in_text "$1 references the procedure" "$2" 'apply the Deliberate stop procedure'
  in_text "$1 gives its reason" "$2" "reason \`$3\`"
}
V1N=$(normalize <<<"$V1")
stop_ref "AT-7: validate status guard" "$V1N" 'status is <status>, expected to-validate'
before_in "AT-7: validate's status guard runs before setting validating" "$V1" '**Status guard:**' 'Set the status to `validating`'
V2C=$(section "$VALIDATE" '### 2c.' | normalize)
stop_ref "AT-7: validate base-branch stop" "$V2C" 'base branch <base-branch> not found locally'
in_text "AT-7: validate base-branch stop restores to-validate" "$V2C" 'restore the status to `to-validate`'
# Build: the unrelated-files stop restores the entry status recorded in step 1.
in_text "AT-7: build step 1 records the entry status" "$B1" '**entry status**'
B52=$(normalize <<<"$B5")
in_text "AT-7: build step 5 restores the entry status" "$B52" 'restore the entry status recorded in step 1'
stop_ref "AT-7: build unrelated-files stop" "$B52" 'unrelated files block validation — <paths>'
absent_in_text "AT-7: build step 5 no longer leaves the status at building" "$B52" 'leave the status at `building`'
# Ship: every stop after selection uses the procedure; no SHIP BLOCKED signal anywhere.
SH0N=$(normalize <<<"$SH0")
SH1=$(section "$SHIP" '### 1. ' | normalize)
SH_SUB=$(section "$SHIP" '## Running as a subagent' | normalize)
stop_ref "AT-7: ship base-branch stop" "$SH1" 'base branch <base-branch> not found locally'
stop_ref "AT-7: ship subagent block" "$SH_SUB" 'blocked — <precise reason>'
stop_ref "AT-7: ship missing ## Branch stop" "$SH0N" 'no ## Branch in the tracking file'
for f in "$S"/*/SKILL.md README.md "$TEAM" "$BOOTSTRAP"; do
  require_absent "AT-7: no SHIP BLOCKED signal in $f" "$f" 'SHIP BLOCKED'
done
require_absent "AT-7: ship has no guidelines migration note" "$SHIP" 'Migration note|migration required'
# Run: reports build's and validate's Last error; recovery points at the phase, never at run.
R53=$(section "$RUN" '3. **Check status after build**' '4. **Subagent: buildit-feature-validate**')
in_text "AT-7: run step 5.3 reports build's ## Last error" "$R53" 'If the tracking file has a `## Last error` section, build stopped deliberately — stop and report its content'
in_text "AT-7: run step 5.3 recovery runs build" "$R53" 'Fix it, then run `/buildit-feature-build [feature-name]`.'
before_in "AT-7: run 5.3 checks Last error before the subagent-failure message" "$R53" '`## Last error` section, build stopped deliberately' 'possible subagent failure'
R55=$(section "$RUN" '5. **Check status after validate**' '### 6.')
in_text "AT-7: run step 5.5 reports validate's ## Last error" "$R55" 'If the tracking file has a `## Last error` section, validate stopped deliberately — stop and report its content'
in_text "AT-7: run step 5.5 recovery runs validate" "$R55" 'Fix it, then run `/buildit-feature-validate [feature-name]`.'
absent_in_text "AT-7: run step 5.5 never recommends re-running run" "$R55" '/buildit-feature-run'
# Run clears a stale Last error before each phase launch (build, validate, ship).
RUN_CLEAR='[Clear a stale Last error — see "Subagent selection and workflow isolation"]'
in_text "AT-7: run defines the stale Last error clear once" "$(section "$RUN" '## Subagent selection and workflow isolation')" '**Clear a stale Last error:** before launching the subagent, if the tracking file has a `## Last error` section, remove it'
same "AT-7: run applies the stale Last error clear at build, validate and ship" "$(grep -cF -- "$RUN_CLEAR" "$RUN")" 4
for pair in '2. **Subagent: buildit-feature-build**|3. **Check status after build**' \
            '4. **Subagent: buildit-feature-validate**|5. **Check status after validate**' \
            '**Subagent: buildit-feature-ship**|**Verify ship before closing the task**'; do
  sec=$(section "$RUN" "${pair%%|*}" "${pair##*|}")
  before_in "AT-7: run clears Last error before launching ${pair%%|*}" "$sec" "$RUN_CLEAR" 'Launch a fresh'
done
# Docs: the contract text lists every writer, the replace rule and feature-run as the only clearer.
TP_TPL_LE=$(grep -F -- 'Last error: ' "$BOOTSTRAP" || true); TEAM_LE=$(grep -F -- 'Last error: ' "$TEAM" || true)
for doc in TP_TPL_LE TEAM_LE; do
  for w in build validate ship feature-run replaces 'Clearer: feature-run only'; do in_text "AT-7: $doc Last error text mentions $w" "${!doc}" "$w"; done
  for gone in 'when they start' 'ship step 0' 'migration note' 'prerequisite'; do absent_in_text "AT-7: $doc Last error text drops '$gone'" "${!doc}" "$gone"; done
done
same "AT-7: bootstrap template Last error line matches team-practices" "$TP_TPL_LE" "$TEAM_LE"
README_TBL=$(section README.md '**Status lifecycle:**' '---')
in_text_re "AT-7: README lifecycle has build's deliberate stop" "$README_TBL" 'buildit-feature-build` deliberate stop.*`## Last error`'
in_text_re "AT-7: README lifecycle has validate's status guard" "$README_TBL" 'buildit-feature-validate` status guard.*`## Last error`'
SHIP_ROW=$(grep -F -- 'buildit-feature-ship` deliberate stop' <<<"$README_TBL" || true)
in_text "AT-7: README lifecycle ship row records ## Last error" "$SHIP_ROW" '`## Last error`'
in_text "AT-7: README lifecycle ship row lists the missing ## Branch stop" "$SHIP_ROW" 'no `## Branch`'
absent_in_text "AT-7: README lifecycle ship row has no migration note" "$SHIP_ROW" 'migration note|prerequisite'
R6=$(section "$RUN" '### 6. ')
VERIFY=$(section "$RUN" '**Verify ship before closing the task**' '**Update plan task on completion**')
in_text "AT-7: run step 6 failure reports ship's ## Last error" "$VERIFY" '`## Last error` line of the tracking file'

# Ship's discovery stop as a subagent: no file selected, so nothing is written; run's failed checks report it.
SH_RULE_END=$(( $(line_of <(echo "$SH0") '**Tracking file discovery rule**') + $(named_block "$SHIP" '**Tracking file discovery rule**' | wc -l) ))
SH_NOWRITE=$(line_of <(echo "$SH0") 'there is no `## Last error` to write')
if [[ -n "$SH_NOWRITE" && "$SH_NOWRITE" -gt "$SH_RULE_END" ]]; then ok "AT-7: ship step 0 states a discovery stop writes no ## Last error, after the rule"; else fail "AT-7: ship step 0 must state a discovery stop writes no ## Last error, after the rule block"; fi
in_text "AT-7: ship discovery stop defers to run's failed checks" "$SH0N" 'buildit-feature-run reports its failed checks'

# ## Branch legacy fallback removed: ship stops, run reads SHIP_REF from ## Branch only.
absent_in_text "AT-7: ship step 0 has no legacy ## Branch fallback" "$SH0" '[Ll]egacy|branch --show-current'
PRESHIP=$(section "$RUN" '**Record the pre-ship state**' '**Subagent: buildit-feature-ship**')
absent_in_text "AT-7: run SHIP_REF has no legacy fallback" "$PRESHIP" '[Ll]egacy|branch --show-current|use `HEAD`'
in_text "AT-7: run stops before ship when ## Branch is missing" "$(normalize <<<"$PRESHIP")" 'Tracking file has no `## Branch`'
# Worktree ship copy: team-practices matches ship step 4 — only the archived tracking file
# is copied; shared-context.md is gitignored local state, never staged.
TEAM_WT=$(section "$TEAM" '### Worktree management' | normalize)
in_text "AT-7: team-practices — only the archived tracking file is copied" "$TEAM_WT" 'only the archived tracking file is copied from the project root into the worktree'
in_text "AT-7: team-practices — shared-context.md is gitignored local state, never committed" "$TEAM_WT" '`shared-context.md` is gitignored local state, edited only in the project root and never committed'
absent_in_text "AT-7: team-practices no longer applies removals to the worktree copy" "$TEAM_WT" "worktree's own"
absent_in_text "AT-7: team-practices no longer says shared-context is copied or made" "$TEAM_WT" 'copied or made'
SH4=$(section "$SHIP" '### 4. ' | normalize)
in_text "AT-7: ship step 4 copies only the archived tracking file" "$SH4" 'copy only `.scratch/done/'
absent_in_text "AT-7: ship step 4 no longer touches the worktree shared-context" "$SH4" 'never replace it with the root file'
in_text "AT-7: language-framework says shared-context.md is local, untracked, single machine" "$(section "$LANG_FW" '## Parallel coordination' | normalize)" 'local, untracked (gitignored) state coordinating worktrees on a single machine'

# Run step 6 ship verification: exactly three checks, then the stop.
same "AT-7: run step 6 verification has exactly 3 checks" "$(grep -cE '^[0-9]+\. ' <<<"$VERIFY" || true)" 3
in_text_re "AT-7: check 1 — new commit on SHIP_REF" "$VERIFY" '^1\. `git rev-parse <SHIP_REF>` differs from `PRE_SHIP_HEAD`'
in_text_re "AT-7: check 2 — tracking file archived in the commit" "$VERIFY" '^2\. `git cat-file -e <SHIP_REF>:\.scratch/done/<TRACKING_FILE>` succeeds'
in_text_re "AT-7: check 3 — no copy left outside done/" "$VERIFY" '^3\. `\.scratch/<TRACKING_FILE>` no longer exists outside `done/`'
in_text "AT-7: any failed check stops" "$VERIFY" 'If any check fails, stop with:'
in_text "AT-7: stop message" "$VERIFY" '> "Unexpected state after ship:'
before_in "AT-7: checks precede the stop" "$VERIFY" '3. `.scratch/<TRACKING_FILE>`' 'If any check fails, stop with:'
before_in "AT-7: ship launch precedes verification" "$R6" '**Subagent: buildit-feature-ship**' '**Verify ship before closing the task**'
before_in "AT-7: verification precedes plan task update" "$R6" 'If any check fails, stop with:' '**Update plan task on completion**'
before_in "AT-7: verification precedes the success message" "$R6" 'If any check fails, stop with:' 'shipped successfully'

# Run step 4: which "not found" message applies after start.
R4=$(section "$RUN" '### 4. ')
R4_RULE=$(named_block "$RUN" '**Tracking file discovery rule**')
GENERAL='No tracking file found —'
same "AT-7: run step 4 has the rule's general message only inside the rule block" \
  "$(grep -cF -- "$GENERAL" <<<"$R4" || true)" "$(grep -cF -- "$GENERAL" <<<"$R4_RULE" || true)"
in_text "AT-7: run step 4 has its own after-start message" "$R4" 'Tracking file not found after buildit-feature-start — possible subagent failure'
in_text "AT-7: run step 4 states its message replaces the rule's general one" "$R4" "instead of the rule's general \"No tracking file found\" message"

# Merge readiness row: 3 columns, written by start, header from bootstrap; no
# READY status nor Waiting for column (never written by any skill — audit #24).
same "AT-8: bootstrap Merge readiness header has 3 columns" \
  "$(grep -cxF '| Branch | Status | Main files touched |' "$BOOTSTRAP" || true)" 1
in_text "AT-8: start writes a 3-column row" "$(section "$START" '### 5. ')" '| [## Branch value] | IN_PROGRESS | — |'
for f in "$START" "$SHIP" "$BOOTSTRAP" "$RUN"; do
  require_absent "AT-8: no Waiting for in $f" "$f" '[Ww]aiting for'
  require_absent "AT-8: no READY status in $f" "$f" '\bREADY\b'
done

echo ""
echo "Results: $PASS passed, $FAIL failed"
[[ $FAIL -eq 0 ]]
