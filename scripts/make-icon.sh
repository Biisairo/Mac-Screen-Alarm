#!/bin/zsh
# scripts/make-icon.swift 로 그린 아이콘을 Resources/AppIcon.icns 로 만든다.
set -euo pipefail

cd "$(dirname "$0")/.."
WORK="$(mktemp -d)"
ICONSET="$WORK/AppIcon.iconset"
mkdir -p "$ICONSET" Resources

swift scripts/make-icon.swift "$WORK/icon_1024.png"
for size in 16 32 128 256 512; do
    sips -z $size $size "$WORK/icon_1024.png" --out "$ICONSET/icon_${size}x${size}.png" >/dev/null
    double=$((size * 2))
    sips -z $double $double "$WORK/icon_1024.png" --out "$ICONSET/icon_${size}x${size}@2x.png" >/dev/null
done
iconutil -c icns "$ICONSET" -o Resources/AppIcon.icns
rm -rf "$WORK"
echo "icns: Resources/AppIcon.icns"
