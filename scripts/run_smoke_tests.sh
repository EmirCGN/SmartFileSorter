#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
BUILD_DIR="${TMPDIR:-/tmp}/smartfilesorter-smoke"
BINARY="$BUILD_DIR/smartfilesorter_smoke"

mkdir -p "$BUILD_DIR"

swiftc \
  "$ROOT_DIR/SmartFileSorter/Models/Category.swift" \
  "$ROOT_DIR/SmartFileSorter/Models/FileItem.swift" \
  "$ROOT_DIR/SmartFileSorter/Models/AppSettings.swift" \
  "$ROOT_DIR/SmartFileSorter/Models/SortAction.swift" \
  "$ROOT_DIR/SmartFileSorter/Models/SortSummary.swift" \
  "$ROOT_DIR/SmartFileSorter/Core/FileSystem.swift" \
  "$ROOT_DIR/SmartFileSorter/Core/ConflictResolver.swift" \
  "$ROOT_DIR/SmartFileSorter/Core/FileMover.swift" \
  "$ROOT_DIR/SmartFileSorter/Services/ServiceProtocols.swift" \
  "$ROOT_DIR/SmartFileSorter/Services/UndoHistoryStore.swift" \
  "$ROOT_DIR/Tests/SmokeTests/main.swift" \
  -o "$BINARY"

"$BINARY"
