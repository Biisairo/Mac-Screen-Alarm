# ScreenAlarm

English | [한국어](README.ko.md)

A macOS menu bar alarm that alerts you with your screen instead of sound.

When an alarm goes off, ScreenAlarm covers every connected display with a translucent color. The alarm stops only when you click the **알람 끄기** (Dismiss) button with the mouse. The keyboard cannot dismiss it. ScreenAlarm does not use sound, vibration, or Notification Center.

## Features

- Lives in the menu bar. No Dock icon.
- Each alarm has a time, a label, repeat days, a cover color, and an opacity.
- An alarm with no repeat days rings once and then turns itself off.
- The editor previews the cover on top of your current desktop wallpaper.
- When several alarms go off together, they appear one at a time, in order.
- Registers itself as a login item on first launch. You can turn this off from the menu.
- No network access. No Accessibility or Screen Recording permission.

## Requirements

- macOS 14 (Sonoma) or later
- Swift 6 toolchain (Xcode or Command Line Tools)

The `.app` bundle is built with SwiftPM and shell scripts only. No Xcode project is needed.

## Build and install

```sh
git clone https://github.com/Biisairo/Mac-Screen-Alarm.git
cd Mac-Screen-Alarm

make install   # build, install to /Applications/ScreenAlarm.app, and launch
```

| Command | What it does |
|---------|--------------|
| `make app` | Builds `build/ScreenAlarm.app`. |
| `make install` | Builds, quits the running app, replaces the bundle in `/Applications`, and launches it again. |
| `make test` | Runs the `AlarmCore` tests. Exits with a non-zero code on failure. |
| `make icon` | Regenerates `Resources/AppIcon.icns` from `scripts/make-icon.swift`. |
| `make clean` | Removes build output (`.build/`, `build/`). |

The app is ad-hoc signed only (`codesign --sign -`). A bundle you build yourself runs as is. If you copy the bundle to another Mac, Gatekeeper may block it.

## Usage

1. Click the alarm icon in the menu bar and choose **알람 관리…** (Manage Alarms).
2. Click `+` in the toolbar (⌘N) to add an alarm.
3. Type the time, or change it with the ↑/↓ keys or the scroll wheel.
4. Pick a color swatch, set the opacity with the slider, and click **저장** (Save).

Double-click a row to edit it. Select a row and press Delete to remove it.

## Limitations

- Alarms ring only while the app is running and the Mac is awake.
- Alarms missed during sleep are skipped. They do not ring after wake.
- macOS does not allow third-party windows above the lock screen. The cover appears after you unlock.
- The UI is in Korean only.

## Data and uninstall

Alarms are stored in `~/Library/Application Support/ScreenAlarm/alarms.json`. If the file cannot be read, ScreenAlarm moves it to `alarms.json.bak` and starts with an empty list.

To remove the app completely:

1. Turn off **로그인 시 실행** (Launch at Login) in the menu, then click **종료** (Quit).
2. Run:

```sh
rm -rf /Applications/ScreenAlarm.app
rm -rf ~/Library/Application\ Support/ScreenAlarm
defaults delete local.screenalarm.ScreenAlarm
```

## Project layout

```
Sources/
  AlarmCore/       Trigger logic, repeat rules, and storage, separate from the UI
  ScreenAlarm/     Menu bar app, manager window, editor, and overlay (SwiftUI + AppKit)
  CoreTestRunner/  Test runner for AlarmCore (make test)
scripts/           App bundle and icon build scripts
docs/SRS.md        Software requirements specification (ISO/IEC/IEEE 29148, Korean)
```

`CoreTestRunner` is a plain executable, so the tests run with Command Line Tools alone, without XCTest. `FR-n` tags in code comments refer to requirement IDs in [docs/SRS.md](docs/SRS.md).

## License

[MIT](LICENSE)
