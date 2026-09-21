# Craft Principles

These three principles are the canonical definitions used by the build and validate phases of the buildit framework. Skills reference this file — they do not reproduce the definitions.

## DRY — Don't Repeat Yourself

Every piece of knowledge or logic has a single, authoritative representation. When the same concept appears in more than one place, a change requires multiple edits and the copies drift apart.

**Violation signs:** duplicated logic, copy-pasted blocks, parallel structures that encode the same rule in different files, constants defined in multiple places.

## KISS — Keep It Simple, Stupid

Prefer the simplest solution that correctly solves the problem. Complexity is a liability — add it only when simplicity genuinely cannot satisfy the requirement.

**Violation signs:** unnecessary abstractions, premature generalisation, convoluted control flow that could be a straight-line sequence, indirection with no caller benefit.

## YAGNI — You Aren't Gonna Need It

Do not implement functionality until it is actually required. Speculative additions increase maintenance cost without delivering value.

**Violation signs:** parameters that no caller passes, code paths with no test or trigger, config options with no consumer, "future-proofing" that solves a problem that does not yet exist.
