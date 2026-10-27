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
xcrun swiftc -sdk "$sdk" -parse-as-library -I build/check-modules scripts/check-clock-detail.swift build/check-modules/IslandCore.o -o build/clock-detail-checks
build/clock-detail-checks
xcrun swiftc -sdk "$sdk" -parse-as-library -I build/check-modules scripts/check-media.swift build/check-modules/IslandCore.o -o build/media-checks
build/media-checks
xcrun swiftc -sdk "$sdk" -parse-as-library -I build/check-modules Sources/Services/ApprovalServer.swift scripts/check-approvals.swift build/check-modules/IslandCore.o -o build/approval-checks
build/approval-checks
xcrun swiftc -DDEBUG -sdk "$sdk" -parse-as-library -I build/check-modules Sources/Services/SwiggyClient.swift Sources/Services/SwiggySignIn.swift Sources/Services/DeliveryManager.swift scripts/check-delivery.swift build/check-modules/IslandCore.o -o build/delivery-checks
build/delivery-checks
python3 scripts/check-no-hover.py

# Exercise the real media manager's publication path with providers stopped.
app_sources=()
while IFS= read -r source; do app_sources+=("$source"); done < <(find Sources -name '*.swift' ! -name main.swift ! -name AppDelegate.swift | sort)
xcrun swiftc -DDEBUG -sdk "$sdk" -parse-as-library -I build/check-modules "${app_sources[@]}" scripts/check-energy.swift build/check-modules/IslandCore.o -o build/energy-checks
build/energy-checks

xcrun swiftc -DDEBUG -sdk "$sdk" -parse-as-library -I build/check-modules "${app_sources[@]}" scripts/check-sports.swift build/check-modules/IslandCore.o -o build/sports-checks
build/sports-checks
