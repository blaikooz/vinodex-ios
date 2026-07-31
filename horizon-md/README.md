# horizon-md — HORIZON's repo docs

The doc folder for the HORIZON side of the collaboration (0.6.5, batch 3),
paired with `godot-md/` for GODOT's. New HORIZON-authored .md docs land here.

## Contents

- [AUDIT.md](AUDIT.md) — the standing work order: numbered, permanent item
  IDs (`H3`, `M12`, `L27`) referenced from commit messages and CI comments.
  Moved here from the repo root in 0.6.5; PR #10's re-verification pass is
  merged in.
- [auditS.md](auditS.md) — the security audit (PR #10).
- [arch.md](arch.md) — the architecture audit (PR #10).

## Rooted on purpose (indexed here, not moved)

Two docs stay at the repo root because things outside this folder point at
them by path:

- [`../README.md`](../README.md) — the GitHub front page; moving it blanks
  the repo landing.
- [`../KNOWN-ISSUES.md`](../KNOWN-ISSUES.md) — the environment/tooling
  handbook, referenced by path from agent configuration and session notes
  that do not live in this repo.
