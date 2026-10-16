# Design spec — Generic test runner detection

**Date:** 2026-10-14
**Feature:** generic-test-runner-detection (cross-skill: bootstrap + validate)

---

## Markdown config file over JSON/YAML

Test command configuration is stored in `.buildit/config.md` using a markdown heading convention rather than JSON or YAML.

**Why:** The buildit framework is markdown-native — guidelines, tracking files, shared-context, and skill definitions are all markdown. Introducing a JSON or YAML config file would add a format dependency that is inconsistent with the rest of the framework. Markdown parsing is also simpler for agent consumption: the convention is "first non-empty, non-comment line after the `## Test command` heading is the command." This is unambiguous and grep-friendly (`grep -A` on the heading, filter blanks and comments).

**Trade-off:** Markdown config is less structured than JSON/YAML and cannot represent nested or typed values. This is acceptable because the current config surface is a single value (one shell command). If `.buildit/config.md` grows to need structured data, migration to a more formal format can be evaluated then (YAGNI).

**Convention:**

```markdown
# Project Configuration

## Test command
<!-- Auto-detected by bootstrap, confirmed by user -->
bash tests/run-all.sh
```

The raw shell command sits on a single line. Comments (`<!-- ... -->`) are skipped. An empty or missing section means "not configured."

---

## Two-tier detection pattern

Validate uses a two-tier strategy to find the test command:

1. **Tier 1 — Configured command:** Read `.buildit/config.md` and extract the command under `## Test command`. This is the primary source because it represents a user-confirmed value set during bootstrap.

2. **Tier 2 — Ecosystem fallback heuristic:** If no config is found (file absent, heading missing, or no command under it), detect the test runner from ecosystem markers. This tier exists so that validate works out-of-the-box on projects that have not yet run bootstrap.

3. **Tier 3 — No detection:** If neither tier produces a command, warn and proceed to the review phase without running tests. This avoids blocking validation on projects with non-standard or manual test workflows.

**Why not just the heuristic?** The heuristic guesses based on file presence. A project might have both `package.json` and `pyproject.toml` but only use one for testing. The configured command removes ambiguity because the user confirmed it during bootstrap.

**Why not just the config?** Projects that skip bootstrap (or where config.md is absent) would have no test runner at all. The fallback ensures a reasonable default without requiring bootstrap as a hard prerequisite.

---

## Cross-skill ecosystem consistency

Both `buildit-project-bootstrap` (step 4e) and `buildit-feature-validate` (step 2b, tier 2) use the same ordered list of ecosystem markers:

| Priority | Marker | Command |
|----------|--------|---------|
| 1 | `tests/run-all.sh` | `bash tests/run-all.sh` |
| 2 | `package.json` | `npm test` |
| 3 | `pom.xml` | `mvn test` |
| 4 | `build.gradle` / `build.gradle.kts` | `gradle test` |
| 5 | `pyproject.toml` | `pytest` |
| 6 | `Makefile` (with `^test:` target) | `make test` |

**Why this order?** `tests/run-all.sh` is the project's own custom runner and always takes precedence over generic ecosystem commands. The remaining entries follow ecosystem prevalence in typical projects this framework targets.

**Why both Groovy and Kotlin DSL?** Gradle projects use either `build.gradle` (Groovy DSL) or `build.gradle.kts` (Kotlin DSL). Checking only one would miss half of Gradle projects.

**Why grep for `^test:` in Makefile?** A Makefile's existence does not imply a test target. Running `make test` on a Makefile without that target produces a confusing error. The grep check (`grep -q '^test:' Makefile`) confirms the target exists before proposing the command.

**Consistency enforcement:** A cross-skill test (`tests/test-skills-invariants.sh`) verifies that both skill files list the same ecosystem markers, preventing silent drift if one skill is updated without the other.
