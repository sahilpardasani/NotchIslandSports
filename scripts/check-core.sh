#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p build
sdk="${NOTCH_MACOS_SDK:-$(xcrun --sdk macosx --show-sdk-path)}"
xcrun swiftc -sdk "$sdk" -parse-as-library Core/*.swift scripts/check-core.swift -o build/core-checks
build/core-checks
mkdir -p build/check-modules
xcrun swiftc -sdk "$sdk" -whole-module-optimization -emit-module -emit-object -module-name IslandCore Core/*.swift -emit-module-path build/check-modules/IslandCore.swiftmodule -o build/check-modules/IslandCore.o
xcrun swiftc -sdk "$sdk" -parse-as-library -I build/check-modules Sources/Panel/IslandPresentation.swift scripts/check-presentation.swift build/check-modules/IslandCore.o -o build/presentation-checks
build/presentation-checks
xcrun swiftc -sdk "$sdk" -parse-as-library -I build/check-modules scripts/check-calendar.swift build/check-modules/IslandCore.o -o build/calendar-checks
build/calendar-checks
xcrun swiftc -sdk "$sdk" -parse-as-library -I build/check-modules scripts/check-notch.swift build/check-modules/IslandCore.o -o build/notch-checks
build/notch-checks
