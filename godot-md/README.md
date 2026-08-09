# godot-md — GODOT's repo docs

The doc folder for the GODOT side of the collaboration, paired with
`horizon-md/` (0.6.5). The two exist so each collaborator has a place to put
working documents that the other can actually see — before this, notes lived
either at the repo root (mixed together) or outside the repo entirely, where
only their author could reach them.

**What belongs here:** audits, plans, findings, design notes, working docs —
anything GODOT writes that is worth sharing but is not the app's own
documentation.

**What does not:** `README.md` and `KNOWN-ISSUES.md` stay at the repo root
(the first is the GitHub landing page, the second is referenced by path from
tooling), and nothing in the build or the pipeline reads from either doc
folder, so files here never affect a build.

See `horizon-md/README.md` for the other side's index.

## Contents

- [AUDIT.md](AUDIT.md) — the standing work order: numbered, permanent item
  IDs (`H3`, `M12`, `L27`) referenced from commit messages and CI comments.
  Moved here from the repo root in 0.6.5; PR #10's re-verification pass is
  merged in.
- [auditS.md](auditS.md) — the targeted compliance/security/test audit
  (PR #10). Its **H2** (flag provenance) and **M5** (trademarked logos under
  `shared/pixelflags/Other/`) are open and unaddressed.
- [arch.md](arch.md) — the architecture, repository and platform audit (PR #10).

Each of the three audits carries a dated **path note** at the top: they were
written before `pixelflags/` and the art masters moved, so the note maps the
old paths to the new ones. Their findings and verdicts are untouched.
