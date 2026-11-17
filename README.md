# Viya — 모바일 서바이버 게임

기존 BREAKERS와 독립된 신규 프로젝트. **비야는 ART-001 승인 시안 확정 단계에서 보류하고 게임 기능을 먼저 제작한다.**

## 다음 세션 필수 문서

**[메인 작업문서 CURRENT_WORK](docs/CURRENT_WORK.md)와 [누적 개발현황 DEVELOPMENT_STATUS](docs/DEVELOPMENT_STATUS.md)를 함께 읽는다.** [통합 예정 PLANNED_WORK](docs/PLANNED_WORK.md) · [다음 실행 NEXT_TASK](docs/NEXT_TASK.md) · [AGENTS](AGENTS.md) · [제작 스킬](.agents/skills/viya-game-production/SKILL.md).

활성 브랜치: `work/viya-turnaround-qa-20261117`. GAME-006 코드 기준 **`cae26339b31910c228dd6098668450690ccb5153`**. 기록 커밋은 뒤에 올 수 있으므로 원격 HEAD를 재확인한다. main에는 게임 코드가 아직 미병합이며 자동 병합하지 않는다.

## 이번 추가 — 선택 전후 효과 비교

기존 무작위3개 레벨업 카드에 ‘선택 시 변화’를 연결했다. 공격의 기본 피해·간격·발사/관통/연쇄 수·반경, 패시브 능력치, 고유 마법 강화의 피해·범위·자원 조건을 전후로 확인한다. 미보유 공격은 미보유로, 변하지 않는 값은 유지로 표시한다. 피해는 공격력·치명타 적용 전 기본값이다.

실제 전투와 표시가 RunState의 순수 조회 프로파일을 공유한다. 미리보기는 보유 레벨 복사본만 사용하며 실제 선택·체력·마력·쿨다운·난수를 소비하지 않는다. 기존 성장 현황 조회, 같은 후보로 돌아오기, 중복 선택 거절과 결과 최종 구성 조회는 유지한다.

시작 경로는 `project.godot → scenes/main.tscn → mobile_main.gd → main.gd/RunState`다. 출격→이동/자동사격→처치/XP→3선택→수동마법→이탈/패배→결과→대기/재출격. PC WASD/방향키·F, 모바일 이동 드래그/마법 버튼을 사용하도록 작성됐다.

18종/기본3선택/임시 명칭/요구XP3배/드롭5/임시 공격4·패시브4/서포터2+2 빈칸 및 게임 밸런스 값은 유지한다. 원화·모델링·리깅·코스튬은 보류다.

## 검수와 개발자 시험

사용자가 GAME-005 이전까지 ‘오류는 없어 현재까지 모두 ok’라고 확인한 사실은 USER_REPORTED_OK로 보존한다. 검수 SHA·플랫폼·엔진 로그가 지정되지 않았으므로 자동시험 합격으로 확대하지 않는다.

이번에는 변경 소스6개와 산술식 대조(공격135·능력치51·체력24)가 Python 검사에서 통과했다. **GDScript를 실행한 결과가 아니며 신규 게임 화면·Godot 자동 시험·전체 회귀·모바일은 미검증이다.** [이번 검사 범위/해시](docs/validation/GAME006_SOURCE_REPORT.json).

```sh
python tools/check_project.py --godot /actual/path/to/Godot
# 기존 HUD → 성장현황 → 선택미리보기 네이티브 회귀 경로:
Godot --headless --path . --script res://tests/test_mobile_hud.gd
```

새 네이티브 시험은 89개의 유효 스킬/레벨 조합과 실제 공격·카드·선택 후 수치 일치를 다루도록 작성했다. 작성만 한 시험을 PASS로 보고하지 않는다. 기존 고정 엔진 준비 스크립트와 DNS 차단 이력은 유지하며, 같은 설치 시도를 반복하거나 사용자 수동 패치·매회 Pull/로그를 개발 조건으로 요구하지 않는다.
