# Viya — 모바일 서바이버 게임

기존 BREAKERS와 독립된 신규 프로젝트. **비야는 승인 시안 확정 단계에서 보류하고 게임 기능을 먼저 제작한다.**

## 시작 문서

- **[통합 작업 예정 문서](docs/PLANNED_WORK.md)** — 게임 우선·보류 아트 계획의 단일 기준.
- [현재 작업](docs/CURRENT_WORK.md) · [다음 게임 작업](docs/NEXT_TASK.md)
- [작업원칙](AGENTS.md) · [제작 스킬](.agents/skills/viya-game-production/SKILL.md)
- [게임 기획](docs/GAME_DESIGN_BASELINE.md) · [승인 아트](docs/ART_APPROVAL.md)

## GAME-004B: 모바일 HUD·스킬 상세 코드 연결

Godot 4.x에서 `project.godot`를 열어 F5 → 출격하는 시작 경로다. 실제 Godot 구문/타입·실행·4.7.2 호환과 모바일 렌더는 아직 미검증이다. Compatibility 렌더러와 모바일 가로 기준을 유지한다.

시작 장면은 `scripts/ui/mobile_main.gd`를 사용하고 기존 `scripts/main.gd`를 상속한다. 전투·성장·마법·반응 상태는 기존 소유자를 그대로 사용한다. HUD·전장·터치 범위는 `hud_layout.gd`의 동일 좌표를 사용하도록 작성했다. 좁은 가로 화면에서는 하단 상태/마법 영역과 스킬 두 줄을 나눠 배치하며, 긴 레벨업 카드는 세로 스크롤로 확인한다.

전장 왼쪽 드래그 또는 PC WASD/방향키로 이동하고 가까운 적에게 자동사격한다. 처치 → 경험치 수집 → 무작위 3선택 → 강화. 오른쪽 고유 마법 버튼 또는 PC F로 마법을 사용한다. **보유 스킬 칸을 누르면 전체 임시 명칭·레벨·설명을 보는 읽기 전용 상세창**을 연다. 상세창은 전투를 정지하며 스킬 획득/강화/마법 사용은 하지 않는다. 닫거나 Esc로 이전 상태에 복귀한다.

18종 구성, `[임시]` 명칭, 요구 XP3배(30,48,66,84…), 드롭 XP5, 임시 장착 공격4/패시브4, 빈 서포터2+2를 유지한다. 비야 마법의 MP40·쿨다운12초 등 수치는 기존 시제품 값이며 이번에는 변경하지 않았다. 반응은 전투 종료>피격>마법>레벨업>저체력>기본 순서의 문구/테두리 대역이다. 원화·3D·새 얼굴을 제작한 것이 아니다.

## 검증

**GAME-004B 변경 소스 검사 PASS. 실제 Godot 실행·레이아웃·입력 전달·렌더·모바일 실기 NOT_VERIFIED.** 시험 코드를 작성한 것과 실행 통과는 다르다. 이번에는 전체 회귀 검사기를 실행하지 않았다.

```sh
# 변경 소스에 대한 정적 검사만:
python tools/check_mobile_hud.py
# 엔진이 있는 환경에서 전체 검사 (검사 데이터 경로 격리):
python tools/check_project.py --godot /path/to/Godot
# 개별 엔진 시험. 직접 실행은 사용자 설정 경로를 사용할 수 있다.
Godot --headless --path . --script res://tests/test_mobile_hud.gd
```

기존 기반·성장·마법·반응 테스트 뒤에 새 HUD 테스트를 등록했다. [GAME-004B 검사 보고서](docs/validation/GAME004B_STATIC_REPORT.json). Android 내보내기의 JSON 포함, 실제 안전영역·터치·가독성·성능은 별도 검증 대상이다. 유료 CI/Actions·외부 아트 생성은 사용하지 않는다.
