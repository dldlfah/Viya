# Viya — 모바일 서바이버 게임

기존 BREAKERS와 독립된 신규 프로젝트. **비야는 ART-001 승인 시안 확정 상태로 보류하고 게임 기능을 먼저 제작한다.**

## 다음 세션 필수 문서

**[메인 작업문서 CURRENT_WORK](docs/CURRENT_WORK.md)와 [누적 개발현황 DEVELOPMENT_STATUS](docs/DEVELOPMENT_STATUS.md)를 함께 읽는다.** [통합 예정 PLANNED_WORK](docs/PLANNED_WORK.md) · [다음 실행 NEXT_TASK](docs/NEXT_TASK.md) · [AGENTS](AGENTS.md) · [제작 스킬](.agents/skills/viya-game-production/SKILL.md).

활성 브랜치 `work/viya-turnaround-qa-20261117`. 최신 GAME-005 코드 기준 **`58d1230a7d5387e5ca826a6db2ccc9fdbec418d9`**. 문서 커밋은 뒤에 올 수 있으므로 원격 HEAD 재확인. main에는 게임 코드가 아직 미병합이며 자동 병합하지 않는다.

## 사용자 검수와 이번 추가

사용자는 GAME-005 직전까지 **“오류는 없어 현재까지 모두 ok”**라고 확인했다. USER_REPORTED_OK로 기록하고 게임 제작을 계속한다. 확인한 정확한 SHA/기기/엔진 버전은 제공되지 않았으며 자동 시험 통과로 바꾸지 않는다.

**GAME-005 성장 현황:** 설정창과 레벨업창에서 보유 공격·패시브의 레벨/설명, 장착 수, 고유 마법 강화·프로파일, 실제 적용 능력치를 한 화면에서 조회한다. 선택창에서 닫으면 기존 후보로 돌아간다. 결과/출격 대기에서는 직전 판의 최종 구성을 보며 새 출격 시 초기화한다. 영구 저장·장착 변경·추가 강화 기능이 아니다.

기존 시작 경로 `project.godot → scenes/main.tscn → mobile_main.gd → main.gd/RunState` 유지. 출격→이동/자동사격→처치/XP→무작위3선택→수동마법→이탈/패배→결과→대기/재출격. PC WASD/방향키·F, 모바일 이동 드래그/마법 터치를 사용하도록 작성된 구조다.

18종/기본3선택/임시 명칭/요구XP3배/드롭5/임시 공격4·패시브4/서포터2+2 빈칸 유지. 이번에는 게임 수치·아트·엔진 설정을 변경하지 않았다.

## 개발자 검증 경로

```sh
python tools/check_project.py --godot /actual/path/to/Godot
# 이번 회귀는 기존 HUD 시험 안에서 함께 실행된다.
Godot --headless --path . --script res://tests/test_mobile_hud.gd
```

이번4개 변경 소스의 기본 구조 검사 PASS. 기존 HUD assertions는 보존하고 성장 현황26개 assertion 호출을 추가했다. **이번 신규 코드의 Godot 자동 시험·신규 화면·모바일 및 전체 회귀는 미실행**이다. [이번 검사 범위/해시](docs/validation/GAME005_SOURCE_REPORT.json). 사용자 이전 정상 확인을 무시하지 않되 신규 기능까지 합격으로 소급하지 않는다.

고정 Linux 엔진 준비 도구 `tools/bootstrap_godot.py`와 이전 DNS 차단 기록은 유지한다. 도구 존재가 설치 완료나 Codex 환경 생성 완료를 뜻하지 않으며 같은 설치 시도를 매번 반복할 필요는 없다. 사용자 수동 패치·매회 Pull/로그를 작업 조건으로 요구하지 않는다.
