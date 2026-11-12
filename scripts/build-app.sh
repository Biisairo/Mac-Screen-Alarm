#!/bin/zsh
# ScreenAlarm.app 번들을 build/ 에 만든다.
# --install: 실행 중인 앱을 종료하고 /Applications 의 번들을 교체한 뒤 다시 실행한다.
set -euo pipefail

cd "$(dirname "$0")/.."
APP=build/ScreenAlarm.app
INSTALLED=/Applications/ScreenAlarm.app
ICON=Resources/AppIcon.icns

if [[ ! -f "$ICON" ]]; then
    ./scripts/make-icon.sh
fi

swift build -c release --product ScreenAlarm
BIN="$(swift build -c release --show-bin-path)/ScreenAlarm"

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/ScreenAlarm"
cp "$ICON" "$APP/Contents/Resources/AppIcon.icns"

cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleIdentifier</key><string>local.screenalarm.ScreenAlarm</string>
    <key>CFBundleName</key><string>ScreenAlarm</string>
    <key>CFBundleDisplayName</key><string>ScreenAlarm</string>
    <key>CFBundleExecutable</key><string>ScreenAlarm</string>
    <key>CFBundleIconFile</key><string>AppIcon</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleShortVersionString</key><string>1.0</string>
    <key>CFBundleVersion</key><string>1</string>
    <key>LSMinimumSystemVersion</key><string>14.0</string>
    <key>LSUIElement</key><true/>
    <key>NSHighResolutionCapable</key><true/>
</dict>
</plist>
PLIST

codesign --force --sign - "$APP"
echo "built: $APP"

if [[ "${1:-}" == "--install" ]]; then
    osascript -e 'quit app id "local.screenalarm.ScreenAlarm"' 2>/dev/null || true
    for _ in {1..20}; do
        pgrep -x ScreenAlarm >/dev/null || break
        sleep 0.25
    done
    pkill -x ScreenAlarm 2>/dev/null || true
    rm -rf "$INSTALLED"
    cp -R "$APP" "$INSTALLED"
    touch "$INSTALLED"
    open "$INSTALLED"
    echo "installed: $INSTALLED"
fi
