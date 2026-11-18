# Viya — 모바일 서바이버 게임

기존 BREAKERS와 독립된 신규 프로젝트. **비야는 ART-001 승인 시안 확정 단계에서 보류하고 게임 기능을 먼저 제작한다.**

## 다음 세션 필수 문서

**[메인 작업문서 CURRENT_WORK](docs/CURRENT_WORK.md)와 [누적 개발현황 DEVELOPMENT_STATUS](docs/DEVELOPMENT_STATUS.md)를 함께 읽는다.** [통합 예정 PLANNED_WORK](docs/PLANNED_WORK.md) · [다음 실행 NEXT_TASK](docs/NEXT_TASK.md) · [AGENTS](AGENTS.md) · [제작 스킬](.agents/skills/viya-game-production/SKILL.md).

활성 브랜치 `work/viya-turnaround-qa-20261117`, GAME-009 코드 기준 **`b1ede7df1692a026aee1cdf60b7f80a2c3723de5`**. 문서 커밋은 뒤에 오므로 원격 HEAD를 다시 확인한다. main은 이전 기획본이며 게임 코드를 자동 병합하지 않는다.

## 이번 추가 — 6분 캠페인과 중단 후 이어하기

기본360초,2/4분 자동 체크포인트,5분 보스를 적용했다. 보스 조기 처치 후에도6분까지 생존해야 하며,6분에 보스가 남으면 시간 초과로 종료한다. 정예 시각·웨이브/체력/속도는 `data/stages.json`에서 조정한다.

HP/MP·스킬/XP·기존 선택 후보·RNG·적/탄환/픽업·타이머·금화를 저장한다. 설정에서 저장 후 출격 대기로 돌아갔다가 이어할 수 있으며 재실행 복원은 정지 화면에서 시작한다. 종료 결과 저장 후 기존 금화를 정산해 중복 지급과 지급된 스테이지의 과거 저장 재사용을 막는다. 기존 금화10~50/100~1000과 기본100·확률30%는 유지한다.

기존 시작 경로 `project.godot → scenes/main.tscn → mobile_main.gd → main.gd/RunState`를 유지한다. 출격→이동/자동사격→처치/XP→3선택/전후 비교→수동마법→체크포인트/중단/이어하기→클리어/시간 초과/이탈/패배→금화 정산/결과/최종 성장 현황→대기/재출격. PC WASD/방향키·F, 모바일 왼쪽 이동/오른쪽 마법 버튼 구조다.

18종/기본3선택/모든 이름 `[임시]`/요구XP3배/드롭5/임시 공격4·패시브4/서포터2+2 빈칸 유지. 비야 원화·3D·리그·코스튬은 보류다.

## 검증

이전 사용자 정상 확인은 USER_REPORTED_OK로 보존한다. 이번 Godot4.7.2 전체 임포트·기존 네이티브7묶음 1,870 checks·시작장면 부트와 Python 실행기12시험은 PASS다. 실제5시드에서10~12선택,4클리어·1패배를 측정했다. 별도 프로세스4회 저장/복원/정산 재실행과 Linux 렌더를 확인했다. 모바일 기기·Windows F5·OS 중단 동작·성능·재미 검수는 미검증이다. [실제 버전과 결과](docs/validation/GAME009_REPORT.json).

```sh
python tools/check_project.py --godot /actual/path/to/Godot
Godot --headless --path . --script res://tests/test_combat_cues.gd
Godot --headless --path . --script res://tests/measure_campaign.gd
```

철수 보상은 설계 검토 상태다.20% 비교안은 미확정이며, 현재 전투 포기는0금화다. 지급 원장을 갖춘 후속 시제품과15~20분/무한/특별 보스 계획은 PLANNED에 둔다. 금화 사용처와 상점·영구 성장은 별도 기획이다.
