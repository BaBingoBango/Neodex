#!/bin/zsh
# ScopeLens — the advisor eval set (m15-B, SESSION-10 Task A).
#
# Replays archived/fixture decision points through the REAL advisor loop
# and scores committed plays with PlayLint + per-case assertions. Costs
# real API tokens — deliberately NOT part of verify-all. Run from the
# repo root:
#
#   Tools/ScopeLensDiagnostics/eval-advisor.sh                 # all cases, 1 run each
#   Tools/ScopeLensDiagnostics/eval-advisor.sh --dry-run       # free: deterministic assertions only
#   Tools/ScopeLensDiagnostics/eval-advisor.sh --case NAME     # one case
#   Tools/ScopeLensDiagnostics/eval-advisor.sh --runs 3        # variance check
#   Tools/ScopeLensDiagnostics/eval-advisor.sh --model claude-sonnet-5   # A/B (m15-E)
#   Tools/ScopeLensDiagnostics/eval-advisor.sh --sweep         # offline: lint every archived play
#
# The m13-C gate lessons apply: pipefail + no AND-list echo.
set -e
set -o pipefail
cd "$(dirname "$0")/../.."

# The fixtures (real Champions screenshots, which carry other trainers' names) stay in the private
# Scope Lens checkout; SCOPELENS_FIXTURES points at its Fixtures folder.
export SCOPELENS_FIXTURES="${SCOPELENS_FIXTURES:-$(dirname "$PWD")/Scope Lens/Fixtures}"
if [[ ! -d "$SCOPELENS_FIXTURES" ]]; then
  echo "SCOPELENS_FIXTURES not found: $SCOPELENS_FIXTURES"; exit 1
fi

swiftc -O Tools/ScopeLensDiagnostics/EvalHarness.swift Packages/ScopeLens/Sources/ScopeLens/ResourceBundle.swift \
  "Packages/ScopeLens/Sources/ScopeLens/ScreenStateClassifier.swift" "Packages/ScopeLens/Sources/ScopeLens/BattleVocabulary.swift" \
  "Packages/ScopeLens/Sources/ScopeLens/BattleState.swift" "Packages/ScopeLens/Sources/ScopeLens/BattleEventParser.swift" \
  "Packages/ScopeLens/Sources/ScopeLens/BattleReconciler.swift" "Packages/ScopeLens/Sources/ScopeLens/PreviewPipeline.swift" \
  "Packages/ScopeLens/Sources/ScopeLens/ScoutEngine.swift" "Packages/ScopeLens/Sources/ScopeLens/TeamStore.swift" \
  "Packages/ScopeLens/Sources/ScopeLens/AdvisorContext.swift" "Packages/ScopeLens/Sources/ScopeLens/AdvisorClient.swift" \
  "Packages/ScopeLens/Sources/ScopeLens/AdvisorTools.swift" "Packages/ScopeLens/Sources/ScopeLens/PlayLint.swift" \
  "Packages/ScopeLens/Sources/ScopeLens/BattleArchiveStore.swift" \
  -o /tmp/sl-eval-advisor

/tmp/sl-eval-advisor "$@"
