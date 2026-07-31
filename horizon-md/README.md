# horizon-md — HORIZON's repo docs

The doc folder for the HORIZON side of the collaboration (0.6.5, batch 3),
paired with `godot-md/` for GODOT's. New HORIZON-authored .md docs land here.

## Contents

- [AUDIT.md](AUDIT.md) — the standing work order: numbered, permanent item
  IDs (`H3`, `M12`, `L27`) referenced from commit messages and CI comments.
  Moved here from the repo root in 0.6.5; PR #10's re-verification pass is
  merged in.
- [auditS.md](auditS.md) — the targeted compliance/security/test audit
  (PR #10). Its **H2** (flag provenance) and **M5** (trademarked logos under
  `shared/pixelflags/Other/`) are open and unaddressed.
- [arch.md](arch.md) — the architecture, repository and platform audit (PR #10).
- [PLAN.md](PLAN.md) — the standing work plan: what the next batches are and
  why. Lived at `HGapps\PLAN.md` (above the repo, so only one collaborator
  could see it) until 0.6.5 batch 4.

Each of the three audits carries a dated **path note** at the top: they were
written before `pixelflags/` and the art masters moved, so the note maps the
old paths to the new ones. Their findings and verdicts are untouched.

## Rooted on purpose (indexed here, not moved)

Two docs stay at the repo root because things outside this folder point at
them by path:

- [`../README.md`](../README.md) — the GitHub front page; moving it blanks
  the repo landing.
- [`../KNOWN-ISSUES.md`](../KNOWN-ISSUES.md) — the environment/tooling
  handbook, referenced by path from agent configuration and session notes
  that do not live in this repo.
