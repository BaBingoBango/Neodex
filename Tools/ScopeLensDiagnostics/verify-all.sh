#!/bin/zsh
# ScopeLens — run every verification harness + the app build in one command.
# Run from the repo root: Tools/ScopeLensDiagnostics/verify-all.sh
# Exit code 0 iff everything is green. Keep this green after every change
# (the guardrail that caught three drift bugs on 2026-07-02).
#
# m13-C hardening: pipefail is LOAD-BEARING — every stage pipes through
# `tail`, whose exit 0 would otherwise mask a failing harness. And never
# write `cmd && echo OK`: under `set -e` a failure inside an AND-list
# (anywhere but its last command) does NOT abort the script (POSIX errexit
# exemption) — that exact shape let a BUILD FAILED run print "ALL GREEN".
set -e
set -o pipefail
cd "$(dirname "$0")/../.."

# The fixtures (real Champions screenshots, which carry other trainers' names) stay in the private
# Scope Lens checkout; SCOPELENS_FIXTURES points at its Fixtures folder.
export SCOPELENS_FIXTURES="${SCOPELENS_FIXTURES:-$(dirname "$PWD")/Scope Lens/Fixtures}"
if [[ ! -d "$SCOPELENS_FIXTURES" ]]; then
  echo "SCOPELENS_FIXTURES not found: $SCOPELENS_FIXTURES"; exit 1
fi

echo "══ 1/7 ScreenStateClassifier vs still fixtures (expect 23/23 ×2 scales)"
swiftc -O Tools/ScopeLensDiagnostics/ClassifierHarness.swift Packages/ScopeLens/Sources/ScopeLens/ResourceBundle.swift "Packages/ScopeLens/Sources/ScopeLens/ScreenStateClassifier.swift" \
  -o /tmp/sl-verify-classifier
/tmp/sl-verify-classifier | tail -2

echo "══ 2/7 PreviewPipeline port faithfulness (type holdout 12/12; species LOFO ≥22/29, ≥24/29)"
swiftc -O Tools/ScopeLensDiagnostics/PreviewPipelineHarness.swift Packages/ScopeLens/Sources/ScopeLens/ResourceBundle.swift "Packages/ScopeLens/Sources/ScopeLens/PreviewPipeline.swift" \
  -o /tmp/sl-verify-pipeline
/tmp/sl-verify-pipeline verify | tail -8

echo "══ 3/7 ScoutEngine bridge parity + meta injection + liveMatchup + team paste (m9)"
swiftc -O Tools/ScopeLensDiagnostics/ScoutEngineHarness.swift Packages/ScopeLens/Sources/ScopeLens/ResourceBundle.swift "Packages/ScopeLens/Sources/ScopeLens/ScoutEngine.swift" \
  "Packages/ScopeLens/Sources/ScopeLens/BattleState.swift" "Packages/ScopeLens/Sources/ScopeLens/TeamStore.swift" \
  -o /tmp/sl-verify-engine
/tmp/sl-verify-engine | tail -3

echo "══ 4/7 Battle-event parser + reconciler fixtures (expect 57/57)"
swiftc -O Tools/ScopeLensDiagnostics/BattleReplayHarness.swift Packages/ScopeLens/Sources/ScopeLens/ResourceBundle.swift \
  "Packages/ScopeLens/Sources/ScopeLens/ScreenStateClassifier.swift" "Packages/ScopeLens/Sources/ScopeLens/BattleVocabulary.swift" \
  "Packages/ScopeLens/Sources/ScopeLens/BattleState.swift" "Packages/ScopeLens/Sources/ScopeLens/BattleEventParser.swift" \
  "Packages/ScopeLens/Sources/ScopeLens/BattleReconciler.swift" "Packages/ScopeLens/Sources/ScopeLens/PreviewPipeline.swift" \
  "Packages/ScopeLens/Sources/ScopeLens/TeamStore.swift" \
  -o /tmp/sl-verify-battle
/tmp/sl-verify-battle fixtures | tail -2

echo "══ 5/7 PlayLint unit cases (m15-B — commit_play verifier)"
swiftc -O Tools/ScopeLensDiagnostics/PlayLintHarness.swift Packages/ScopeLens/Sources/ScopeLens/ResourceBundle.swift \
  "Packages/ScopeLens/Sources/ScopeLens/ScreenStateClassifier.swift" "Packages/ScopeLens/Sources/ScopeLens/BattleVocabulary.swift" \
  "Packages/ScopeLens/Sources/ScopeLens/BattleState.swift" "Packages/ScopeLens/Sources/ScopeLens/BattleEventParser.swift" \
  "Packages/ScopeLens/Sources/ScopeLens/BattleReconciler.swift" "Packages/ScopeLens/Sources/ScopeLens/PreviewPipeline.swift" \
  "Packages/ScopeLens/Sources/ScopeLens/ScoutEngine.swift" "Packages/ScopeLens/Sources/ScopeLens/TeamStore.swift" \
  "Packages/ScopeLens/Sources/ScopeLens/AdvisorContext.swift" "Packages/ScopeLens/Sources/ScopeLens/AdvisorClient.swift" \
  "Packages/ScopeLens/Sources/ScopeLens/AdvisorTools.swift" "Packages/ScopeLens/Sources/ScopeLens/PlayLint.swift" \
  -o /tmp/sl-verify-playlint
/tmp/sl-verify-playlint | tail -2

echo "══ 6/7 Mac app build (Neodex links the ScopeLens package)"
xcodebuild -project Neodex.xcodeproj -scheme NeodexMac -configuration Debug \
  -destination "platform=macOS" -derivedDataPath /tmp/sl-verify-dd -quiet build
echo "BUILD SUCCEEDED"

echo "══ 7/7 MCP server protocol + engine parity (m10)"
node Tools/ScopeLensEngine/mcp-server-test.js | tail -2

echo "\n✅ ALL VERIFICATIONS GREEN"
