# Viya — 모바일 서바이버 게임

기존 BREAKERS와 독립된 신규 프로젝트. **비야는 ART-001 승인 시안 확정 단계에서 보류하고 게임 기능을 먼저 제작한다.**

## 다음 세션 필수 문서

**[메인 작업문서 CURRENT_WORK](docs/CURRENT_WORK.md)와 [누적 개발현황 DEVELOPMENT_STATUS](docs/DEVELOPMENT_STATUS.md)를 함께 읽는다.** [통합 예정 PLANNED_WORK](docs/PLANNED_WORK.md) · [다음 실행 NEXT_TASK](docs/NEXT_TASK.md) · [AGENTS](AGENTS.md) · [제작 스킬](.agents/skills/viya-game-production/SKILL.md).

활성 브랜치 `work/viya-turnaround-qa-20261117`, GAME-010 코드 기준 **`6202c4bd4f1ccea118c0e02042931ac0ae4bcf27`**. 문서 커밋은 뒤에 오므로 원격 HEAD를 다시 확인한다. main은 이전 기획본이며 게임 코드를 자동 병합하지 않는다.

## 이번 추가 — 강한 정예·2배 공세와 새 몬스터

두 정예는 기존 보스 수준의1600HP, 최종 보스는3200HP다. 웨이브는 같은 간격에2/4/6마리로 이전의2배를 생성한다. 원거리 예고/탄·고속1.7배·일반HP2배/속도0.55배 적과20개체 비행 대형을 추가했다. 비행은 임시로20초마다20% 확률이다. 종류별 혼합과 공격 수치는 `data/stages.json`에서 조정한다.

기본6분·2/4분 저장·5분 보스를 유지한다. 저장2는 새 적/적 탄/대형/예약과 별도 난수를 보존한다. 표준 GAME-009 저장은 진행·이미 살아 있는 적의 실제 피해를 보존해 변환하며 새 생성부터 새 수치를 적용한다.

기존 시작 경로 `project.godot → scenes/main.tscn → mobile_main.gd → main.gd/RunState`를 유지한다. 출격→이동/자동사격→처치/XP→3선택/전후 비교→수동마법→체크포인트/중단/이어하기→클리어/시간 초과/이탈/패배→금화 정산/결과/최종 성장 현황→대기/재출격. PC WASD/방향키·F, 모바일 왼쪽 이동/오른쪽 마법 버튼 구조다.

18종/기본3선택/모든 이름 `[임시]`/요구XP3배/드롭5/임시 공격4·패시브4/서포터2+2 빈칸 유지. 비야 원화·3D·리그·코스튬은 보류다.

## 검증

이전 사용자 정상 확인은 USER_REPORTED_OK로 보존한다. 이번 Godot4.7.2 전체 임포트·기존 네이티브7묶음1,913 checks·시작 장면과 Python 실행기12시험은 PASS다. 실제 이전 저장 변환·새 적 상태의 별도 프로세스 복원과 Linux 렌더를 확인했다. 모바일 기기·Windows F5·FPS·실제 난도 승인은 미검증이다. [실제 버전과 결과](docs/validation/GAME010_REPORT.json).

회피를 포함한5시드 측정은4클리어·1시간 초과,566~613처치·16~17선택이다. 이전10~12회 성장 목표 검사는 초과로 FAIL이다. XP 수식과 기본5XP를 유지했으며 목표 판정/종료코드를 완화하지 않았다. 원래 자동 조작의5회 중도 패배 결과도 보고서에 보존했다.

```sh
python tools/check_project.py --godot /actual/path/to/Godot
Godot --headless --path . --script res://tests/test_combat_cues.gd
# 현재10~12회 목표를 초과해 종료1을 반환하는 실제 측정
Godot --headless --path . --script res://tests/measure_campaign.gd
```

다음 단일 작업은 원거리·비행 접근의 모바일 회피 경고다. 성장 빈도/금화 공급 조정, 철수20% 비교안과15~20분/무한/특별 보스는 PLANNED에 둔다. 철수 보상과 금화 사용처·상점·영구 성장은 미구현이다.
