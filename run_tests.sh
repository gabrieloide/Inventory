#!/usr/bin/env bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BIN_PATH="$SCRIPT_DIR/.build_test_runner"

echo "Compiling Inventory unit test suite..."
swiftc \
  -I /Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/usr/lib \
  -F /Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/Library/Frameworks \
  -L /Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/usr/lib \
  -framework XCTest \
  -framework SwiftData \
  -Xlinker -rpath -Xlinker /Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/Library/Frameworks \
  -Xlinker -rpath -Xlinker /Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/usr/lib \
  "$SCRIPT_DIR/Inventory/Constants.swift" \
  "$SCRIPT_DIR/Inventory/Product.swift" \
  "$SCRIPT_DIR/Inventory/ProductAPI.swift" \
  "$SCRIPT_DIR/Inventory/PendingOperation.swift" \
  "$SCRIPT_DIR/InventoryTests/PendingOperationTests.swift" \
  "$SCRIPT_DIR/InventoryTests/ProductAPITests.swift" \
  "$SCRIPT_DIR/InventoryTests/TestRunner.swift" \
  -o "$BIN_PATH"

echo "Executing unit tests..."
"$BIN_PATH"
EXIT_CODE=$?
rm -f "$BIN_PATH"
exit $EXIT_CODE
