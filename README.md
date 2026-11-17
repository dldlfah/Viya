# Viya — 모바일 서바이버 게임

기존 BREAKERS와 독립된 신규 프로젝트. **비야는 승인 시안 확정 단계에서 보류하고 게임 기능을 먼저 제작한다.**

## 시작 문서

- **[통합 작업 예정 문서](docs/PLANNED_WORK.md)** — 현재 우선순위와 보류된 Higgsfield 부분 편집/모델링 계획의 단일 기준.
- [현재 작업](docs/CURRENT_WORK.md) · [다음 게임 작업](docs/NEXT_TASK.md)
- [작업원칙](AGENTS.md) · [제작 스킬](.agents/skills/viya-game-production/SKILL.md)
- [게임 기획](docs/GAME_DESIGN_BASELINE.md) · [승인 아트](docs/ART_APPROVAL.md)

## GAME-002 전투·성장 코드

Godot 4.x에서 `project.godot`를 열고 F5 → **출격**. 기존 개발 기준 4.7.2와 실제 호환 실행은 아직 미검증이다. 모바일 가로 / Compatibility / 기준 1280×720.

전장 왼쪽 드래그로 이동, PC에서는 WASD/방향키·마우스 드래그도 지원한다. 사거리 내 자동사격 → 처치 경험치 드롭 → 접근 수집 → 레벨업 3선택 → 공격/패시브 강화 → 전투 복귀로 코드를 연결했다. 선택 중 전투는 정지하며 Esc/환경설정은 선택 상태를 보존한다. HP 소진 시 결과 → 다시 출격한다.

후보는 공통 공격8 + 캐릭터 공격1 + 공통 패시브8(저항 제외) + 캐릭터 필살기 강화1. 공격/패시브 각 4칸은 기존 임시 장착 한도이며 18종 후보 수와 별개다. 신규 획득/보유 강화 및 레벨이 두 줄 HUD에 표시된다. 필살기 강화는 저장/표시만 연결했고 **마법 발동은 GAME-003 예정**이다. 지원2+2는 빈 자리다.

`data/prototype_skills.json`의 **이름·효과·수치·강화 상한은 모두 시제품 값**이며 최종 승인된 콘텐츠가 아니다. 원화·캐릭터·적·전장은 임시 표현을 유지한다. 미승인 R1/R2·SAM GLB를 정식 아트로 쓰지 않는다. 음량 저장은 있으나 전투 음원은 없다.

## 검증 상태

**코드 작성·시작 경로 연결 및 파일/데이터 검사 PASS. Godot 구문·타입/엔진 실행·실제 화면·모바일 실기 NOT_VERIFIED.** 작성한 엔진 테스트를 통과 실적으로 취급하지 않는다.

```sh
python tools/check_project.py --godot /path/to/Godot
# 아래 직접 실행은 사용자의 설정 폴더를 사용할 수 있다.
Godot --headless --path . --editor --import --quit
Godot --headless --path . --script res://tests/test_combat_foundation.gd
Godot --headless --path . --script res://tests/test_growth.gd
```

Python 검사기는 검사용 데이터 위치를 격리하고, 엔진이 없으면 종료 코드 2와 NOT_VERIFIED를 반환한다. [이번 정적 검사 보고서](docs/validation/GAME002_STATIC_REPORT.json). GitHub Actions/유료 CI는 사용하지 않는다. Android 내보내기 시 `data/*.json` 포함과 터치/가독성은 별도로 확인해야 한다.
