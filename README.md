# Viya — 모바일 서바이버 게임

기존 BREAKERS와 독립된 신규 프로젝트. **비야는 승인 시안 확정 단계에서 보류하고 게임 기능을 먼저 제작한다.**

## 시작 문서

- **[통합 작업 예정 문서](docs/PLANNED_WORK.md)** — 게임 우선·보류 아트 계획의 단일 기준.
- [현재 작업](docs/CURRENT_WORK.md) · [다음 게임 작업](docs/NEXT_TASK.md)
- [작업원칙](AGENTS.md) · [제작 스킬](.agents/skills/viya-game-production/SKILL.md)
- [게임 기획](docs/GAME_DESIGN_BASELINE.md) · [승인 아트](docs/ART_APPROVAL.md)

## GAME-003 전투·성장·고유 마법 코드

Godot 4.x에서 `project.godot`를 열고 F5 → 출격. 기존 개발 기준 4.7.2의 호환 실행과 실제 렌더는 미검증이다. 모바일 가로 / Compatibility / 기준 1280×720.

전장 왼쪽 드래그로 이동, PC는 WASD/방향키·마우스 드래그. 자동사격→처치 XP 드롭→접근 수집→무작위 3선택→공격/패시브 강화. **레벨업 필요 XP는 기존의 3배(30,48,66,84…), 드롭 XP5는 그대로다.** 모든 스킬명에 `[임시]`를 표시한다.

오른쪽 고유 마법 버튼 또는 PC F: MP/쿨다운 조건을 통과하면 플레이어 중심 광역 피해. 임시 마법 `[임시] 진홍 파동`은 MP40·쿨다운12초, 최대MP100·전투 중 초당5 회복, 기본피해50·반경230이며 전용 필살기 강화 1단계마다 피해15·반경18 증가. 수치·이름·효과는 최종 확정이 아니다. 자동 룬탄과 다른 능력이며 18종 후보에 새 항목을 추가하지 않는다.

레벨업/환경설정/사망/앱 포커스 상실 중 사용과 마력·쿨다운 진행은 차단한다. 빈 곳에서도 발동/소비하는 임시 정책이다. 이동 손가락과 마법 손가락 ID를 분리했지만 **모바일 실기는 미검증**이다. 재시작은 성장·MP·쿨다운을 초기화한다.

공통 공격8 + 캐릭터 공격1 + 공통 패시브8(저항 제외) + 캐릭터 필살기 강화1을 유지한다. 임시 장착 공격4/패시브4는 후보 수와 별개이며 서포터2+2는 빈 자리다. 임시 도형과 범위 링은 승인 비야 디자인을 대체하지 않는다. 음량 설정 저장은 있으나 전투 음원은 없다.

## 검증

**코드/시작 경로 연결 및 파일·데이터 검사 PASS. Godot 구문/타입·엔진 동작·렌더·Windows/모바일 실기 NOT_VERIFIED.** 작성한 엔진 테스트를 실행한 것으로 취급하지 않는다.

```sh
python tools/check_project.py --godot /path/to/Godot
# 직접 실행 시 사용자 설정 폴더를 사용할 수 있다.
Godot --headless --path . --editor --import --quit
Godot --headless --path . --script res://tests/test_combat_foundation.gd
Godot --headless --path . --script res://tests/test_growth.gd
Godot --headless --path . --script res://tests/test_magic.gd
```

검사기는 데이터 폴더를 격리하며 엔진 부재 시 종료 코드2/NOT_VERIFIED를 반환한다. [GAME-003 검사 보고서](docs/validation/GAME003_STATIC_REPORT.json). GitHub Actions/유료 CI는 사용하지 않는다. Android 내보내기에서는 `data/*.json` 포함, 안전영역, 가독성, 동시 터치, 성능을 별도로 검증해야 한다.
