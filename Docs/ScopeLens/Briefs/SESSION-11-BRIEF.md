# ScopeLens — Session 11 kickoff (after the m15 advisor-expertise arc)

Context (read in order — do not rediscover what's written down):
1. Project memory (auto-loads; current through PR #60 / m15-E).
2. `Diagnostics/README.md` — m15-A through m15-E are the freshest
   sections; the m15-E latency budget is REQUIRED reading before any
   request-shape change.
3. `BACKLOG.md` — the dev queue (playbooks + follow-up dialogue are the
   remaining agreed items).

## What session 10 shipped (PRs #56–#60)

The pilot's steer was "heuristics all day isn't the way" — so the
advisor became a measured system instead of a prompted one:
- **MEASURE**: every ask now archives its EXACT contexts + structured
  play + lint verdict; the review window (⇧⌘A) collects 👍/👎 labels;
  `Diagnostics/eval-advisor.sh` replays cases through the real loop
  (4/4 green at the shipped defaults; --dry-run tier is free).
- **VERIFY**: PlayLint checks every commit_play against objective game
  rules (29 unit cases = verify-all stage 5/7); a violating commit
  bounces back ONCE in-loop for repair; unresolved violations render in
  orange under the play chips.
- **GROUND**: the meta is data now — Champions-native spread points
  (0–32 scale), natures, teammates for all 119 species; unconfigured
  sets use the MODAL ladder spread (attacker offense floored at 252 —
  pessimism where a miss loses games); capsules show ladder-modal
  speeds + usual partners.
- **MEASURED DEFAULTS**: turn asks run `thinking: disabled` (only arm
  that swept the eval AND never breached the 40s timer; 5.5–23.6s
  observed); preview keeps adaptive. budget_tokens is REMOVED on
  Opus 4.8 — effort is the only depth lever.

## Pilot actions (the label supply starts with you)

1. **Quit + relaunch** (stale-instance discipline; the build stamp
   shows in the archive header now). Play ranked with the tracker on.
2. After the session: ⇧⌘A → tap 👍/👎 on each decision point (add a
   note on the 👎s — they become eval cases). ~30 seconds per battle.
3. Report any "bizarre move" verbatim, as always — 11-for-11 so far.

## Task A — live-rep triage (first hour)

Run `Diagnostics/eval-advisor.sh --sweep` (free): every m15-era archived
play gets re-linted offline. Then mine the pilot's 👎 notes: each one
becomes an eval case (archive-sourced cases replay byte-for-byte now —
`{"source": {"archive": "<file>", "ask": N}}`). Fix classes, not
instances; every change re-runs the eval.

## Task B — archetype playbooks (dev queue; now unblocked)

Teammates data exists per species. Detect cores at preview (rain: 
Politoed+Ludicolo-style co-occurrence; TR: Farigiraf partners; perish:
battle 5 IS the case study) and render a SHORT archetype line in the
static context — data-derived, not hand-written lore. Eval-gate it:
add a preview-mode case or a doomed-flag-style deterministic pin first.

## Task C — follow-up dialogue (dev queue, stretch)

"Why not Protect here?" — a follow-up turn on the SAME cached prefix
(cheap tokens; new UI affordance in the Battle Log advice card). Keep
the latency budget: follow-ups are not under the move timer, but the
board may go stale — curtain rules from m13-A apply.

## Guardrails (all earned; m15 additions in bold)

- verify-all 7/7 after every shared-code change; sim-prove any gate you
  touch (m13-C lesson).
- **Request-shape changes re-run `eval-advisor.sh` and must stay inside
  the m15-E latency budget (turn p50 ≤10s, soft 18s, worst ~30s).**
- **The eval gates doctrine/prompt/data changes — a red case after your
  change is evidence about the change OR the baseline (m15-D found a
  paper-defender artifact this way). Bisect before believing either.**
- **Committed sample regen: the ScoutReport CLI writes its fixture IN
  PLACE — diff against git HEAD, not a stdout copy.**
- claude-api skill BEFORE Anthropic-API changes (it killed a planned
  A/B arm this session: budget_tokens is gone on Opus 4.8).
- Shared files Foundation-only; nonisolated on every type/extension.
- Branch + PR per milestone; findings to Diagnostics/README.md + memory
  AS YOU GO; BACKLOG.md is the deferred-work ledger.
