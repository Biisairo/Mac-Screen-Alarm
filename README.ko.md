# ScreenAlarm

[English](README.md) | 한국어

소리 대신 화면으로 알리는 macOS 메뉴바 알람 앱입니다.

알람 시각이 되면 연결된 모든 화면을 고른 색으로 반투명하게 덮습니다. 화면 가운데의 **알람 끄기** 버튼을 마우스로 눌러야만 알람이 꺼집니다. 키보드로는 끌 수 없습니다. 소리, 진동, 알림 센터 알림은 쓰지 않습니다.

## 주요 기능

- 메뉴바에 상주하며 Dock에는 나타나지 않습니다.
- 알람마다 시각, 내용, 반복 요일, 덮개 색상, 농도를 정할 수 있습니다.
- 반복 요일을 고르지 않으면 한 번만 울리고 자동으로 꺼집니다.
- 편집 화면에서 현재 바탕화면 위에 덮개가 어떻게 보일지 미리 볼 수 있습니다.
- 여러 알람이 한꺼번에 울리면 하나를 끈 뒤에 다음 알람을 차례로 보여 줍니다.
- 처음 실행할 때 로그인 시 자동 실행을 등록합니다. 메뉴에서 끌 수 있습니다.
- 네트워크를 쓰지 않으며, 손쉬운 사용·화면 기록 같은 추가 권한도 요구하지 않습니다.

## 요구 사항

- macOS 14 (Sonoma) 이상
- Swift 6 툴체인 (Xcode 또는 Command Line Tools)

Xcode 프로젝트 없이 SwiftPM과 셸 스크립트만으로 `.app` 번들을 만듭니다.

## 빌드와 설치

```sh
git clone https://github.com/Biisairo/Mac-Screen-Alarm.git
cd Mac-Screen-Alarm

make install   # 빌드한 뒤 /Applications/ScreenAlarm.app 에 설치하고 실행
```

| 명령 | 동작 |
|------|------|
| `make app` | `build/ScreenAlarm.app` 을 만듭니다. |
| `make install` | 빌드한 뒤 실행 중인 앱을 종료하고 `/Applications` 의 번들을 교체한 다음 다시 실행합니다. |
| `make test` | `AlarmCore` 테스트를 실행합니다. 실패하면 0이 아닌 코드로 끝납니다. |
| `make icon` | `scripts/make-icon.swift` 로 `Resources/AppIcon.icns` 를 다시 만듭니다. |
| `make clean` | 빌드 산출물(`.build/`, `build/`)을 지웁니다. |

앱은 애드혹 서명(`codesign --sign -`)만 합니다. 직접 빌드한 앱은 그대로 실행되지만, 빌드한 번들을 다른 Mac으로 옮기면 Gatekeeper가 실행을 막을 수 있습니다.

## 사용법

1. 메뉴바의 알람 아이콘을 누르고 **알람 관리…** 를 엽니다.
2. 툴바의 `+` 버튼(⌘N)으로 알람을 추가합니다.
3. 시각은 숫자를 직접 치거나, ↑/↓ 키 또는 스크롤로 조정합니다.
4. 색 견본을 고르고 농도 슬라이더로 덮개의 진하기를 맞춘 뒤 **저장** 을 누릅니다.

목록에서 행을 두 번 누르면 편집하고, 행을 선택한 뒤 Delete 키를 누르면 삭제합니다.

## 알아 둘 점

- 앱이 실행 중이고 Mac이 깨어 있을 때만 알람이 울립니다.
- 잠자기 중에 지난 알람은 깨어난 뒤에 울리지 않고 건너뜁니다.
- macOS 정책상 잠금 화면 위에는 덮개를 띄울 수 없습니다. 잠금을 풀면 덮개가 보입니다.
- 앱 UI는 한국어만 지원합니다.

## 데이터와 제거

알람은 `~/Library/Application Support/ScreenAlarm/alarms.json` 에 저장합니다. 파일을 읽을 수 없으면 원본을 `alarms.json.bak` 으로 옮기고 빈 목록으로 시작합니다.

앱을 완전히 지우려면 다음 순서를 따릅니다.

1. 메뉴에서 **로그인 시 실행** 을 끄고 **종료** 를 누릅니다.
2. 아래 명령을 실행합니다.

```sh
rm -rf /Applications/ScreenAlarm.app
rm -rf ~/Library/Application\ Support/ScreenAlarm
defaults delete local.screenalarm.ScreenAlarm
```

## 프로젝트 구조

```
Sources/
  AlarmCore/       발화 판정, 반복 계산, 저장 등 UI와 분리한 로직
  ScreenAlarm/     메뉴바 앱, 관리 창, 편집 화면, 오버레이 (SwiftUI + AppKit)
  CoreTestRunner/  AlarmCore 테스트 실행기 (make test)
scripts/           앱 번들 빌드와 아이콘 생성 스크립트
docs/SRS.md        요구사항 명세 (ISO/IEC/IEEE 29148)
```

`CoreTestRunner` 는 XCTest 없이 Command Line Tools만으로 테스트를 돌리려고 만든 실행 파일입니다. 코드 주석의 `FR-n` 은 [docs/SRS.md](docs/SRS.md) 의 요구사항 번호입니다.

## 라이선스

[MIT](LICENSE)
