# Viya — 모바일 서바이버 게임

기존 BREAKERS와 독립된 신규 프로젝트. **비야는 ART-001 시안 확정 단계에서 보류하고 게임 기능을 우선한다.**

## 다음 세션 시작점

**[메인 작업문서](docs/CURRENT_WORK.md)와 [누적 개발현황·인수인계](docs/DEVELOPMENT_STATUS.md)를 반드시 함께 읽는다.** [PLANNED_WORK](docs/PLANNED_WORK.md)는 확정/후속/보류 계획, [NEXT_TASK](docs/NEXT_TASK.md)는 다음 게임 단위다. [AGENTS](AGENTS.md) · [제작 스킬](.agents/skills/viya-game-production/SKILL.md) · [초기 기획](docs/GAME_DESIGN_BASELINE.md) · [승인 아트](docs/ART_APPROVAL.md).

활성 브랜치: `work/viya-turnaround-qa-20261117`. 게임 코드 기준: **`0082688a56994cfd5cf31f52b905692ef8096e0f` / GAME-004D**. 문서 커밋은 뒤에 올 수 있으므로 원격 HEAD를 다시 확인한다. main에는 게임 코드가 미병합이다.

## 연결된 게임 코드

`project.godot → scenes/main.tscn → scripts/ui/mobile_main.gd (기존 main 상속) → 단일 RunState`. 모바일 가로/Compatibility/기준1280×720이다. **사용 경로 설명은 실제 Godot 실행·4.7.2 호환·모바일 합격 증거가 아니다.**

출격→이동/자동사격→처치 XP 수집→무작위3선택/강화→마법→확인 후 포기 또는 HP0패배→결과→재출격/대기. 전장 왼쪽 드래그·PC WASD/방향키, 오른쪽 마법 버튼·PC F. 보유 스킬칸은 읽기 전용 상세를 연다. 새 전투/포기에는 확인창이 있고 취소는 같은 전투/레벨업 후보를 보존한다. 오래된 화면 요청과 중복 확인을 거절하는 코드가 있다.

**GAME-004D:** 실제 적 HP 감소에 피격 색 강조·숫자, 실제 제거에 작은 소멸 링, 실제 픽업 수집에 `+XP` 숫자를 연결했다. 치명타는 기존 판정을 재사용하며 과잉 피해를 표시 숫자에 더하지 않는다. 이벤트48/강조80 상한, 수명 제한·근접 표시 합산을 사용한다. 정지/선택/확인/결과/대기에서는 시간이 멈추고 새 출격에서 초기화한다. 기존 전장 View가 그리며 새 원화·노드별 Timer/이펙트 제작은 없다.

18종/기본3선택/저항 제외/임시명/요구XP3배(30,48,66…)/드롭5XP/임시 공격4·패시브4/서포터2+2 빈칸을 유지한다. HUD 반응은 문구·테두리 대역이고 최종 비야 얼굴 애니메이션이 아니다.

## 검증

**변경 소스6개 정적 검사 및 잘못된 소스8종 거절 PASS. 실제 Godot 구문/타입·실행·렌더·입력·Windows/모바일 NOT_VERIFIED. 전체 회귀 NOT_RUN.** 기존 코드를 보존한 소스 대조와 실제 게임 동작 검증은 구분한다.

```sh
# 이번 실행한 변경 소스 검사:
python tools/check_combat_cues.py
# 엔진이 있는 환경에서 전체 검사 (저장 경로 격리):
python tools/check_project.py --godot /path/to/Godot
# 개별 엔진 시험. 직접 실행은 사용자 설정 경로를 사용할 수 있다.
Godot --headless --path . --script res://tests/test_combat_cues.gd
```

[GAME-004D 실제 검사 보고서](docs/validation/GAME004D_STATIC_REPORT.json). 기존 기반·성장·마법·반응·HUD·내비게이션 뒤에 전장피드백 시험을 등록했다. 작성한 엔진 시험을 실행한 것으로 세지 않는다. JSON 내보내기 포함·기기 안전영역·물리 다중터치·FPS는 별도 미검증이다. 유료 CI/Actions·외부 아트 생성은 사용하지 않았다.

다음은 새 연출 확장보다 **누적 기본 플레이의 통합 오류 수정과 첫 실행 검수본 준비**다. 승인 아트나 기존 BREAKERS를 변경하지 않는다.
