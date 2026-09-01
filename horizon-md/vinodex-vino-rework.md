# The Professor Vino Rework — flow, text, and what he provides

Drafted 2026-09-01 from the maintainer's four rulings: **all four roles**
(sommelier / insight / guide / coach), **templates with authored overrides**,
**RPG dialogue** as the interaction register, and **chattier** ambient
presence. Spans several 0.9.4x releases; each phase lands through the usual
train, sim-verified, and carries a **checkpoint** — a small set of questions
the maintainer answers on the simulator before the next phase starts. This
spec expects finetuning; the checkpoints are where it happens.

## What already exists (build on, don't replace)

- `VinoDialogue` / `VinoLine` (Core): the voice bible as executable rules —
  <= 20 words per bubble, printable ASCII (VT323/Press Start 2P coverage),
  one `{name}` max and never sentence-initial, expression tags, a gag
  budget, `VinoChirp` for punctuation the fonts can't draw. `problems()`
  runs in `VinoDialogueTests`. **Every new line in every phase passes these
  gates**; where a rule must widen (scene text vs bubble text), the rule is
  widened deliberately in the bible, never bypassed.
- `FirstTimeTriggers` + `VinoPresenter`: the one-time ambient bubble queue
  and the silence switch. The switch keeps final authority in every phase.
- Six `VinoExpression` faces + the new robot portrait (0.9.43).
- `PalateProfile.recommendations`, `Passport`, `ExamProgress`/`QuizProgress`
  — the data his sommelier and coach roles read. The quiz tier-up with no
  celebration card is a known gap this rework closes (V2).
- House ruling: Vino copy lives in **Core**, not `shared/` — the web has no
  Vino. All new copy and templates follow it.

## V1 — THE SCENE (dialogue engine + his page becomes a place)

The foundation everything else plugs into.

- **`VinoScene` (Core)**: dialogue graph vocabulary — a node is (line,
  expression, optional payload ref), an edge is a tappable choice. Bible
  gains a scene-text rule distinct from the bubble rule (longer cap,
  same ASCII/name/gag discipline; exact cap is a checkpoint question).
  Deterministic, data-driven, testable on Linux like everything in Core.
- **`ProfVinoScreen` rebuilt as the scene player**: portrait left or top,
  typewriter text in the retro face (skippable on tap; instant when Reduce
  Motion), 2–4 choice pills, his face swapping per node. The silence row
  survives, reframed as a choice inside the scene ("Speak less").
- **Root menu as his own words**, four doors mapping to the roles:
  TODAY / MY PICKS / STUDY / THIS DEVICE. Doors light up as later phases
  fill them; V1 ships TODAY (moon day + streak + one observation composed
  from live stores) and THIS DEVICE stubbed to the existing tips replayed
  on demand (the guide's floor).
- **Checkpoint V1** (on the sim): typewriter speed, scene text cap, choice
  count ceiling, whether Back exits the scene or steps the graph.

## V2 — THE COACH AND THE SOMMELIER (two doors fill)

- **MY PICKS**: `PalateProfile.recommendations` voiced — each pick arrives
  with a template-composed reason from the tried shelf ("three Loire
  whites this month; try..."). The SUGGESTIONS screen itself stays; his
  scene links into it rather than duplicating it.
- **STUDY**: reads `ExamProgress` — weakest category named, one entry to
  read before the next paper, streak framing. **The quiz tier-up card
  lands here**: tier unlocks get a celebration presented by Vino (the
  RankUnlockedPrompt sibling that never existed).
- **Checkpoint V2**: three sample reason-templates and three study lines
  rendered on-device for a voice pass before mass templating.

## V3 — THE INSIGHT (his take on entries)

- **`VinoTake` (Core)**: a composed line per entry — template floor over
  fields the catalog already carries (body, tannin, origin, climate,
  pairings, lineage), plus an **authored-override table** for flagship
  entries (sommbot audits candidates; maintainer approves). Register:
  one take per entry, <= the scene cap, gag budget shared with the bible.
- **Surface**: a VINO row on `EntryDetailScreen` — his small face, his
  line, tap to open his scene anchored on that entry (deeper: pairing +
  one lore node).
- **Checkpoint V3 (the big one)**: 10 template-composed takes across entry
  kinds reviewed on-device BEFORE wiring the row catalog-wide. If the
  floor reads robotic, the phase stops and the templates get rewritten —
  this is the highest-risk phase for voice.

## V4 — CHATTIER (ambience beyond first-times)

- **Milestone reactions**: rank-ups, streak marks, a country's regions all
  tried, a pack of the catalog completed — one bubble each, once per
  milestone, through the existing queue and budget rules.
- **The daily line**: first launch of the day, one line (moon day / streak
  / a pick tease), dismissible, silenced by his switch.
- **The text pass**: every pre-rework line reread against the bible in his
  now-larger role; stale tips retired, tone unified.
- **Checkpoint V4**: chattiness on the maintainer's own device for a few
  days — the thresholds (per-day caps, which milestones speak) tune here.

## Art dependencies (maintainer's magenta pipeline)

- V1 wants a **large scene portrait** (the robot at dialogue scale) and,
  ideally, 2 new expressions (listening, presenting). Same drop flow as
  0.9.43: generate on magenta, drop in art/inbox — wiring is code-side.
- Nothing else blocks on art; the six faces cover V2–V4.

## Sequencing and release mapping

V1 → one release (0.9.45-era). V2 → one. V3 → one or two (override
authoring can trail the template floor). V4 → one. Each accumulates with
whatever else is in flight, sim-verifies, and dispatches on the
maintainer's word per the standing flow. Phases are order-dependent
(V2–V4 all speak through V1's scene) but each is shippable alone.
