# ffmpegkit-next-ios

GitHub Actions(macOS 러너)로 [FFmpegKitNext](https://github.com/arthenica/ffmpeg-kit-next)를
iOS/iPadOS **실기기 arm64 전용**으로 빌드해 `xcframework` + Swift Package 를 산출한다.

- FFmpeg 기본 **n9.0.1** (수동 실행 시 태그 변경 가능)
- x264 · x265 (GPL) · dav1d · libaom · VideoToolbox · AudioToolbox · zlib
- 시뮬레이터/Mac Catalyst/arm64e 제외 (빌드 시간 절약)
- 최소 iOS 17.0

## 실행
Actions 탭 → **Build FFmpegKitNext for iOS** → *Run workflow* (태그 입력 가능) → 끝나면 *Artifacts* 에서 zip 다운로드.

## 앱에 넣기
zip 안의 `*.xcframework` 들을 앱의 `Frameworks/` 에 있는 동명 xcframework 와 교체하거나,
`Package.swift` 로 Swift Package 로 추가한다.

## 2단계 (예정)
libsmb2 기반 `smb://` 프로토콜 패치 — 별도 FFmpeg 포크를 가리키도록 `scripts/source.sh` 를 sed 로 바꿔 빌드.
