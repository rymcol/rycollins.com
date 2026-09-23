#!/bin/bash
# Rebuilds the app icons and screenshots in public/assets/img from the app repos.
# xcv and Percolate are rendered from their own code, working on throwaway copies in a temp
# dir; Astrolical reuses the screenshots its own site ships. The app repos are only read.
#
#   tools/make-screenshots.sh
#
# XCV_DIR, PERCOLATE_DIR and ASTROLICAL_DIR override where the app repos live.
set -euo pipefail
cd "$(dirname "$0")/.."
ROOT="$PWD"
XCV="${XCV_DIR:-$ROOT/../xcv}"
PERCOLATE="${PERCOLATE_DIR:-$ROOT/../../cedarinventive/percolate}"
ASTROLICAL="${ASTROLICAL_DIR:-$ROOT/../../cedarinventive/Astrolical}"
OUT="$ROOT/public/assets/img"
WORK="$(mktemp -d)"
SNAP_ID=com.rymcol.xcv.sitesnap
trap 'rm -rf "$WORK"; defaults delete "$SNAP_ID" >/dev/null 2>&1 || true' EXIT

# SwiftUI's macros ship with Xcode, not the Command Line Tools.
if [ -d /Applications/Xcode.app ] && [ -z "${DEVELOPER_DIR:-}" ]; then
  export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
fi

echo "› icons"
for app in xcv percolate; do
  src="$XCV/Resources/AppIcon.icns"; [ "$app" = percolate ] && src="$PERCOLATE/Resources/AppIcon.icns"
  iconutil -c iconset -o "$WORK/$app.iconset" "$src"
  for n in 256 512; do
    sips -s format png -Z "$n" "$WORK/$app.iconset/icon_512x512@2x.png" --out "$OUT/$app-icon-$n.png" >/dev/null
  done
done

echo "› xcv (patched copy with demo data under its own bundle id)"
rsync -a --exclude .build --exclude build --exclude .git "$XCV/" "$WORK/xcv/"
python3 tools/patch_sources.py xcv "$WORK/xcv"
(cd "$WORK/xcv" && { swift build -c release >/dev/null 2>&1 || swift build -c release; })
APP="$WORK/xcv-sitesnap.app"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$(cd "$WORK/xcv" && swift build -c release --show-bin-path)/xcv" "$APP/Contents/MacOS/xcv"
sed -e 's/$(MARKETING_VERSION)/0.0.0/' -e 's/$(CURRENT_PROJECT_VERSION)/1/' \
    -e "s/<string>com.rymcol.xcv<\/string>/<string>$SNAP_ID<\/string>/" \
    "$WORK/xcv/Resources/Info.plist" > "$APP/Contents/Info.plist"
cp "$WORK/xcv/Resources/AppIcon.icns" "$APP/Contents/Resources/"
codesign --force --sign - --identifier "$SNAP_ID" "$APP" 2>/dev/null
python3 tools/xcv_demo.py "$WORK/xcv-store" "$WORK/percolate.iconset/icon_512x512@2x.png"
XCV_STORE_DIR="$WORK/xcv-store" XCV_SNAPSHOT="$WORK/xcv.png" "$APP/Contents/MacOS/xcv" 2>&1 | grep "snapshot: wrote" >/dev/null
cp "$WORK/xcv.png" "$OUT/xcv-island.png"
sips -Z 920 "$WORK/xcv.png" --out "$OUT/xcv-island-920.png" >/dev/null

echo "› percolate (the app's CupScene/CupLayer, frame by frame)"
mkdir -p "$WORK/percolate"
cp "$PERCOLATE/Sources/Percolate/CupScene.swift" "$PERCOLATE/Sources/Percolate/CupLayer.swift" "$WORK/percolate/"
cp tools/percolate_island.swift "$WORK/percolate/main.swift"
python3 tools/patch_sources.py percolate "$WORK/percolate"
(cd "$WORK/percolate" && swiftc -O -swift-version 5 CupScene.swift CupLayer.swift main.swift -o render)
"$WORK/percolate/render" "$OUT"

echo "› astrolical"
icon="$ASTROLICAL/Astrolical-ios/Astrolical/Assets.xcassets/AppIcon.appiconset/app_icon.png"
for n in 256 512; do
  sips -s format png -Z "$n" "$icon" --out "$OUT/astrolical-icon-$n.png" >/dev/null
done
sips -s format jpeg -s formatOptions 78 -Z 1024 "$icon" --out "$OUT/astrolical-wheel.jpg" >/dev/null
for shot in home transits calendar; do
  sips -s format jpeg -s formatOptions 84 "$ASTROLICAL/Astrolical-web/public/screenshots/$shot.png" \
    --out "$OUT/astrolical-$shot.jpg" >/dev/null
done

echo "done: $OUT"
