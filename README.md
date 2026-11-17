# Viya — 모바일 서바이버 게임

기존 BREAKERS와 독립된 신규 프로젝트. **비야는 ART-001 승인 시안 확정 단계에서 보류하고 게임 기능을 먼저 제작한다.**

## 다음 세션 필수 문서

**[메인 작업문서 CURRENT_WORK](docs/CURRENT_WORK.md)와 [누적 개발현황 DEVELOPMENT_STATUS](docs/DEVELOPMENT_STATUS.md)를 함께 읽는다.** [통합 예정 PLANNED_WORK](docs/PLANNED_WORK.md) · [다음 실행 NEXT_TASK](docs/NEXT_TASK.md) · [AGENTS](AGENTS.md) · [제작 스킬](.agents/skills/viya-game-production/SKILL.md).

활성 브랜치 `work/viya-turnaround-qa-20261117`, GAME-007 코드 기준 **`8e6e7c2236d9f91c4024d6dd2e42c051e462c1fc`**. 문서 커밋은 뒤에 오므로 원격 HEAD를 다시 확인한다. main은 이전 기획본이며 게임 코드를 자동 병합하지 않는다.

## 이번 추가 — 기존 공격9종의 전장 표현 구분

탄환에 기존 공격의 출처를 기록해 소총·산탄·관통탄·교차사격·정밀사격을 선/점/화살촉/마름모 형태로 구분했다. 유탄·방어사격·비야 자동 룬탄은 실제 중심/반경을 따라 링·분절·룬으로 표현하고, 연쇄탄은 실제 선택된 이전 표적→다음 표적 사이만 연결한다. 수동 고유 마법은 자동 룬탄과 구분되는 기존 이중 링이다.

새 `attack_visuals.gd`는 기존 BattleView의 읽기 전용 그리기 helper다. 발사/범위 표시를 실제 적중·처치·수집과 혼동하지 않는다. 기존 CombatCues의 성공 결과 표시와 탄환64/효과32 상한·수명·정지/초기화를 보존한다. 새 원화·노드/타이머·피해 공식·추가 난수는 없다. 실제 화면에서의 최종 가독성 검수는 남아 있다.

기존 시작 경로 `project.godot → scenes/main.tscn → mobile_main.gd → main.gd/RunState`를 유지한다. 출격→이동/자동사격→처치/XP→3선택/전후 비교→수동마법→이탈/패배→결과/최종 성장 현황→대기/재출격. PC WASD/방향키·F, 모바일 왼쪽 이동/오른쪽 마법 버튼 구조다.

18종/기본3선택/모든 이름 `[임시]`/요구XP3배/드롭5/임시 공격4·패시브4/서포터2+2 빈칸 유지. 비야 원화·3D·리그·코스튬은 보류다.

## 검증

이전 사용자 정상 확인은 USER_REPORTED_OK로 보존하며 새 기능까지 자동 검수 완료로 확대하지 않는다. 이번 변경6개 소스 구조·원본 보존 대조와 기존 전장 표시 소스 검사(잘못된 소스11종 거절)는 Python에서 PASS다. **실제 Godot 구문/타입·런타임·렌더·모바일과 전체 회귀는 미검증/미실행이다.** [이번 검사 범위·해시](docs/validation/GAME007_SOURCE_REPORT.json).

```sh
python tools/check_combat_cues.py
python tools/check_project.py --godot /actual/path/to/Godot
# 새 공격표현 회귀는 기존 전장 피드백 네이티브 시험 안에서 호출:
Godot --headless --path . --script res://tests/test_combat_cues.gd
```

새 네이티브 사례는 실제 발사/중심/반경/연쇄끝점·상한·정지/초기화·RNG/XP/자원 불변·F5 View 읽기를 다룬다. 작성만 한 시험을 PASS라고 보고하지 않는다. 같은 엔진 설치 차단을 반복하거나 사용자 수동 패치·매회 Pull/로그를 기본 작업으로 넘기지 않는다.
