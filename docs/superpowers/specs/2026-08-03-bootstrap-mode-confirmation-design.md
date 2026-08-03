# Design: Environment Mode Confirmation in Project Bootstrap

## Context

`buildit-project-bootstrap` step 0 auto-detects the environment by checking whether `.claude/` exists:
- present → Claude mode (`.claude/CLAUDE.md`, `.claude/guidelines/`)
- absent → Generic mode (`.agents/guidelines/project-rules.md`, `.agents/guidelines/`)

**Problem:** When `.claude/` exists but the agent running the skill is not Claude (e.g. Copilot linking to Claude skills), the detection yields a false positive. The user cannot override it without restarting.

## Decision

Add an inline confirmation question at the end of step 0, before any scan or file read.

## Design

### Step 0 — updated flow

1. Check for `.claude/` → determine detected mode (Claude or Generic)
2. Ask:
   > "Detected mode: **[mode]**. Confirm? (or type `claude` / `generic` to switch)"
3. Use the confirmed mode for `<rules-file>` and `<guidelines-dir>` in all subsequent steps

### Confirmation rules

| User input | Result |
|---|---|
| `yes`, `y`, `ok`, Enter, or the detected mode name | Confirmed — use detected mode |
| The other mode name (`claude` or `generic`) | Switch to that mode |

### Scope

- Only step 0 is modified
- Detection heuristic is unchanged
- No other steps are affected

## Out of scope

- Persisting the mode choice per project
- Detecting mode from agent identity signals
