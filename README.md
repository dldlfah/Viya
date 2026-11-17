# Viya — 모바일 서바이버 게임

기존 BREAKERS와 독립된 신규 프로젝트. **비야는 승인 시안 확정 단계에서 보류하고 게임 기능을 먼저 제작한다.**

## 시작 문서

- **[통합 작업 예정 문서](docs/PLANNED_WORK.md)** — 현재 우선순위와 보류된 Higgsfield 부분 편집/모델링 계획의 단일 기준.
- [현재 작업](docs/CURRENT_WORK.md) · [다음 게임 작업](docs/NEXT_TASK.md)
- [작업원칙](AGENTS.md) · [제작 스킬](.agents/skills/viya-game-production/SKILL.md)
- [게임 기획](docs/GAME_DESIGN_BASELINE.md) · [승인 아트](docs/ART_APPROVAL.md)

## GAME-001 코드

Godot 4.x에서 이 저장소의 `project.godot`를 열고 F5 → **출격**. 기존 개발 기준 4.7.2와의 실제 호환 실행은 아직 미검증이다. 모바일 가로 / Compatibility 렌더러 / 기준 1280×720.

이동: 전장 왼쪽 드래그(터치 조이스틱), PC는 WASD·방향키 또는 마우스 드래그. 사격은 사거리 내 가까운 적을 향해 자동 발사. 접촉 피격 → HP 소진 → 결과 → 다시 출격. 환경설정 버튼 또는 Esc는 일시정지/재개. 포커스 상실 시 정지.

캐릭터와 전장은 **임시 도형**이다. 승인 시안·미승인 R1/R2·실패한 3D를 변경/재활용한 모델이 아니다. 공격·패시브 각 4칸과 서포터 2+2, 마법 버튼은 자리만 마련했으며 레벨업·서포터 효과·마법은 후속 작업이다. 음량은 저장되지만 전투 음원은 아직 없다.

## 검증 상태

**코드 작성 및 리소스 경로 연결, 기본 정적 검사만 통과. 실제 Godot 구문/타입 검사·게임 실행·모바일 실기 미검증.** 등록된 GDScript 테스트를 통과 실적으로 취급하지 않는다.

```sh
python tools/check_project.py --godot /path/to/Godot
# 엔진 직접 검사:
Godot --headless --path . --editor --import --quit
Godot --headless --path . --script res://tests/test_combat_foundation.gd
```

검사기는 엔진이 없으면 종료 코드 2와 NOT_VERIFIED를 반환한다. GitHub Actions/유료 CI는 사용하지 않는다. 엔진 직접 실행은 사용자의 설정 폴더를 사용할 수 있으며 Python 검사기는 검사용 데이터 위치를 격리한다.
