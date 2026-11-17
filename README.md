# Viya — 모바일 서바이버 게임

기존 BREAKERS와 독립된 신규 프로젝트. **비야는 승인 시안 확정 단계에서 보류하고 게임 기능을 먼저 제작한다.**

## 다음 세션 시작점

**[메인 작업문서](docs/CURRENT_WORK.md)와 [누적 개발현황·인수인계](docs/DEVELOPMENT_STATUS.md)를 반드시 함께 읽는다.** 후속/보류 계획은 [PLANNED_WORK](docs/PLANNED_WORK.md), 다음 게임 단위는 [NEXT_TASK](docs/NEXT_TASK.md)다. [AGENTS](AGENTS.md) · [제작 스킬](.agents/skills/viya-game-production/SKILL.md) · [게임 기획](docs/GAME_DESIGN_BASELINE.md) · [승인 아트](docs/ART_APPROVAL.md).

활성 브랜치는 `work/viya-turnaround-qa-20261117`. 게임 코드 기준은 **`189aba3574917249b5823a792660d0bb4958b9bb` / GAME-004C**이며 문서 커밋은 뒤에 올 수 있다. main에는 게임 코드가 아직 병합되지 않았다. 새 세션은 실제 원격 HEAD를 확인하고 기존 브랜치를 계속 사용한다.

## 현재 연결한 게임 흐름

`project.godot` → `scenes/main.tscn` → `scripts/ui/mobile_main.gd` (기존 main 상속) → 하나의 RunState를 사용한다. 모바일 가로 / Compatibility / 기준1280×720. **아래는 작성된 코드의 사용 경로이며 실제 Godot·4.7.2 호환·모바일 실행 합격은 아니다.**

출격 → 이동/자동사격 → 처치 XP 수집 → 무작위3선택/강화 → 마법 → 패배 또는 확인 후 포기 → 결과 → 재출격/출격 대기. 전장 왼쪽 드래그 또는 PC WASD/방향키로 이동, 마법은 오른쪽 버튼/PC F다. 보유 스킬칸은 읽기 전용 전체 이름·레벨·효과 상세를 연다.

**GAME-004C 변경:** 설정창의 새 전투/포기에 확인창을 추가했다. 확인 전에는 현재 성장·HP·MP를 보존하고 취소/Esc는 동일 전투 또는 같은 레벨업 후보로 복귀한다. 포기는 실제 HP0 패배와 구분하며 결과에서 출격 대기로 돌아갈 수 있다. 화면/전투 요청 식별번호로 낡은 버튼·중복 확인을 차단하고, 확인창에서 앱이 중단되면 정지 상태를 유지한다.

이전 GAME-004B의 공유 HUD 배치·compact 모드·안전영역·카드 스크롤·스킬 상세는 유지한다. 스킬18종, `[임시]` 명칭, 요구XP3배(30,48,66,84…), 드롭5XP, 임시 공격4/패시브4, 빈 서포터2+2와 마법 수치는 변경하지 않았다. 반응은 문구·테두리 대역이며 원화·3D를 새로 제작하지 않았다.

## 검증

**이번 변경 소스5개 검사 및 잘못된 소스8종 대조 검사 PASS. Godot 구문/타입·엔진·렌더·실제 입력·Windows/모바일 NOT_VERIFIED. 전체 회귀 NOT_RUN.** 작성한 엔진 시험을 통과 실적으로 취급하지 않는다.

```sh
python tools/check_run_navigation.py
# 엔진이 있는 환경에서 기존 검사를 포함해 실행 (저장 경로 격리):
python tools/check_project.py --godot /path/to/Godot
# 개별 실제 엔진 시험. 직접 호출은 사용자 설정 경로를 사용할 수 있다.
Godot --headless --path . --script res://tests/test_run_navigation.gd
```

[GAME-004C 검사 보고서](docs/validation/GAME004C_STATIC_REPORT.json). 기존 기반·성장·마법·반응·HUD 시험 뒤에 내비게이션 시험을 등록했다. 배포 JSON 포함, 실제 화면 안전영역·다중 터치·성능은 별도 검증 대상이다. 유료 CI/Actions와 외부 아트 생성은 사용하지 않는다.
