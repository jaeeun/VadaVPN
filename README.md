# VPN for Apple TV

Apple TV 4K (tvOS 17+)용 WireGuard VPN 앱. `App/Config/appletv.conf`(wg-quick 형식)에
번들된 서버 설정으로 연결/해제하는 단일 터널 앱입니다.

## 구성

| 경로 | 설명 |
|---|---|
| `App/` | tvOS 앱 (SwiftUI). 연결/해제 UI, VPN 설정 등록 |
| `App/Config/appletv.conf` | WireGuard 서버 설정 (앱 번들에 포함됨) |
| `PacketTunnel/` | Network Extension (Packet Tunnel Provider). 실제 WireGuard 터널 동작 |
| `Packages/WireGuardKitTV/` | 로컬 Swift 패키지. 공식 wireguard-apple의 WireGuardKit Swift/C 소스를 벤더링 |
| `project.yml` | XcodeGen 프로젝트 정의 |

공식 [wireguard-apple](https://git.zx2c4.com/wireguard-apple)은 tvOS를 지원하지 않아
(Go 툴체인 + 외부 빌드 타겟 필요, tvOS 매핑 없음), Go 브리지(`libwg-go.a`)는
[partout-io/wg-go-apple](https://github.com/partout-io/wg-go-apple)의 **tvOS 슬라이스가
포함된 prebuilt XCFramework**를 SPM 바이너리 타겟으로 사용합니다. 따라서 빌드에 Go가
필요 없습니다.

### 업스트림 대비 변경점 (Packages/WireGuardKitTV)

- `WireGuardAdapter.swift`: `import WireGuardKitGo` → `import wg_go` (prebuilt 모듈명)
- `TunnelConfiguration+WgQuickConfig.swift`: 앱 공용 소스에서 가져와 API를 `public`으로 변경
- `WireGuardKitC.h`: `#include <sys/types.h>` 추가 (최신 SDK에서 `u_int32_t` 미선언 오류 수정)

## 빌드

```sh
brew install xcodegen   # 최초 1회
xcodegen generate       # project.yml 변경 시마다
open VPNforAppleTV.xcodeproj
```

1. Xcode에서 **VPNforAppleTV / PacketTunnel 두 타겟 모두** Signing & Capabilities에서
   팀을 선택하세요 (또는 `project.yml`의 `DEVELOPMENT_TEAM`에 팀 ID를 넣고 재생성).
   Network Extension 엔타이틀먼트는 유료 Apple Developer 계정이 필요합니다.
2. Apple TV를 개발 기기로 페어링: Apple TV의 설정 → 리모컨 및 기기 → 원격 앱 및 기기,
   Xcode의 Devices and Simulators 창에서 페어링.
3. Apple TV를 대상으로 선택 후 Run. 첫 연결 시 tvOS가 VPN 구성 추가 허용을 묻습니다.

> 참고: VPN(Network Extension)은 **시뮬레이터에서 동작하지 않습니다.** 빌드 확인만
> 가능하고 실제 터널 테스트는 실기기에서 해야 합니다.

## 서버 설정 변경

`App/Config/appletv.conf`를 수정하고 앱을 다시 빌드/설치하면 됩니다. 앱이 시작될 때마다
번들 설정으로 시스템 VPN 구성을 갱신합니다.

## 동작 방식

- 앱이 `appletv.conf`를 읽어 `NETunnelProviderManager`의 `providerConfiguration`
  (`WgQuickConfig` 키)에 저장하고 시스템 VPN 구성으로 등록합니다.
- 연결 시 tvOS가 `PacketTunnel` 익스텐션을 기동하고, 익스텐션이 설정을 파싱해
  `WireGuardAdapter`(wireguard-go)로 터널을 엽니다.
- `AllowedIPs = 0.0.0.0/0`이므로 Apple TV의 모든 IPv4 트래픽이 VPN을 경유합니다.
