#!/bin/bash
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$PROJECT_DIR"

SCHEME="${SCHEME:-PDF_One}"
DESTINATION="${DESTINATION:-platform=iOS Simulator,name=iPhone 15}"

WORKSPACE=$(find . -maxdepth 1 -name "*.xcworkspace" | head -n 1)
PROJECT=$(find . -maxdepth 1 -name "*.xcodeproj" | head -n 1)

if [ -n "$WORKSPACE" ]; then
    XCODEBUILD_TARGET=(-workspace "$WORKSPACE")
elif [ -n "$PROJECT" ]; then
    XCODEBUILD_TARGET=(-project "$PROJECT")
else
    echo "error: .xcodeproj / .xcworkspace が見つかりません。Xcodeでプロジェクトを作成してから再実行してください。" >&2
    exit 1
fi

echo "==> Building (scheme: $SCHEME)"
xcodebuild "${XCODEBUILD_TARGET[@]}" -scheme "$SCHEME" -destination "$DESTINATION" build

echo "==> Testing (scheme: $SCHEME)"
xcodebuild "${XCODEBUILD_TARGET[@]}" -scheme "$SCHEME" -destination "$DESTINATION" test
