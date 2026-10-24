# ScopeLens — Backlog

Deferred pilot-reported bugs/ideas and the agreed development queue. Working
notes for whoever picks these up next; each open item carries a root-cause
hypothesis so it can be actioned without re-investigating from scratch.
Shipped work lives in `Diagnostics/README.md` (per-milestone findings) and the
git history. Add new pilot ideas here when they're not being worked on now.

## Open — pilot-reported

_None right now — add new pilot reports here (P1/P2 shipped 2026-07-10,
nickname-bind 2026-07-11; see Diagnostics/README.md m13-A/B/D)._

## Also on deck

- **"Better UX overall"** (pilot, 2026-07-09) — deferred by his call.
- **Notepad follow-ups** (from the pilot's 2026-07-12 "battle status"
  ask; the board itself shipped as m14-A): bench speed BRACKETS on the
  board (priors — decide whether mixing them into the observed-only
  board is worth it, or keep them dossier-only), an overlay-HUD compact
  variant, and PP tracking (m14-A's move-use counts are the first step;
  true PP needs max-PP data per move).
- **Automatic nickname resolution beyond signature moves** (m13-D
  postscript). The bind card ships the guaranteed unblock; the automatic
  lever is a learnset REVERSE index (move → candidate species set,
  vocab-scoped, baked like dex-info.json) intersected with the unclaimed
  preview rows — every move a nicknamed mon uses shrinks its candidate
  set; auto-bind when it reaches one. Effectiveness-message type
  constraints could stack on top. Elimination alone can NEVER conclude
  (the two unbrought preview rows stay unclaimed all battle — verified
  reasoning in m13-D notes). Wants the eval set first (dev queue item 2)
  so binding precision is measurable before it's trusted.
- **Agreed expertise dev queue** (2026-07-09, in priority order):
  ~~battle archive + post-battle review~~ (m13-C) →
  ~~eval set from recorded decision points~~ (m15-A/B, 2026-07-13) →
  ~~effort A/B~~ (m15-E — turn asks now thinking:disabled, latency
  budget written) → archetype playbooks (UNBLOCKED: m15-D teammates
  data is in every profile) → follow-up dialogue ("why not Protect
  here?" — conversation continuity on the cached prefix).
- **require-recommit repair nudge** (m15-E observation): after a lint
  rejection the model occasionally answers in prose without calling
  commit_play again (136s adaptive run). Candidate: when a rejection
  round returns prose-only, one targeted "call commit_play now with
  your corrected line" continuation. Eval-gated like everything else.
- **sonnet-5 tier decision** (m15-E data, pilot's call): 3.5–43.8s,
  3/4 (its miss = a hallucinated move the lint caught). Numbers in
  Diagnostics/README m15-E; switching is a cost/latency-vs-polish
  tradeoff the pilot owns.

- **Mega-forme speed ceilings** (m15-B): DoomedSlot's speedRisk tier uses
  capsule bracket ceilings computed from the BASE forme — a mega-stone
  holder's post-mega speed can be higher (Gengar-Mega base 130 vs 110),
  so ceilings under-warn on mega threats. Needs a stone→forme mapping in
  the engine (speedBrackets already handles named mega formes); natural
  companion to the m15-D spreads work.

## Known gaps (carried from prior sessions)

See `Diagnostics/README.md` and project memory for detail: opponent
summary-panel deep-parse mappings (need in-battle frames), species-bank eval
misses awaiting live taps, PP tracking absent, a few heavy-wobble unrecognized
banners. teraType is intentionally inert (Champions has no Terastallization).
