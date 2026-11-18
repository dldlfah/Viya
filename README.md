# Viya — 모바일 서바이버 게임

기존 BREAKERS와 독립된 신규 프로젝트. **비야는 ART-001 승인 시안 확정 단계에서 보류하고 게임 기능을 먼저 제작한다.**

## 다음 세션 필수 문서

**[메인 작업문서 CURRENT_WORK](docs/CURRENT_WORK.md)와 [누적 개발현황 DEVELOPMENT_STATUS](docs/DEVELOPMENT_STATUS.md)를 함께 읽는다.** [통합 예정 PLANNED_WORK](docs/PLANNED_WORK.md) · [다음 실행 NEXT_TASK](docs/NEXT_TASK.md) · [AGENTS](AGENTS.md) · [제작 스킬](.agents/skills/viya-game-production/SKILL.md).

활성 브랜치 `work/viya-turnaround-qa-20261117`, GAME-008 코드 기준 **`1f0a89ed1022527572927b7ab76d20e6c2b76ecb`**. 문서 커밋은 뒤에 오므로 원격 HEAD를 다시 확인한다. main은 이전 기획본이며 게임 코드를 자동 병합하지 않는다.

## 이번 추가 — 금화 드롭·클리어 정산과 표시 설정

일반 몬스터는 10~50, 정예·보스는 100~1,000금화를 무작위 드롭한다. 확률30%와 클리어 기본100금화는 임시값이다. 검증용 스테이지는90초 후 보스 처치로 클리어하며, 바닥 금화까지 회수해 기본 보상과 합산한다. 보유량과 다음 스테이지는 저장되고 실패/포기는 미지급이다. 금화 사용처는 보류다.

기존 환경설정에 피해 숫자·XP 문구·공격 장식 간소화를 연결했다. 표시만 바꾸며 실제 전투/범위·연쇄 연결·자원·후보는 유지한다. 기존 음량 설정과 함께 저장한다.

기존 시작 경로 `project.godot → scenes/main.tscn → mobile_main.gd → main.gd/RunState`를 유지한다. 출격→이동/자동사격→처치/XP→3선택/전후 비교→수동마법→클리어/이탈/패배→금화 정산/결과/최종 성장 현황→대기/재출격. PC WASD/방향키·F, 모바일 왼쪽 이동/오른쪽 마법 버튼 구조다.

18종/기본3선택/모든 이름 `[임시]`/요구XP3배/드롭5/임시 공격4·패시브4/서포터2+2 빈칸 유지. 비야 원화·3D·리그·코스튬은 보류다.

## 검증

이전 사용자 정상 확인은 USER_REPORTED_OK로 보존한다. 이번 Godot4.7.2 전체 임포트·기존 네이티브7묶음 1,826 checks·시작장면 부트와 Python 실행기12시험은 PASS다. Linux 전장·설정·클리어 결과를 실제 렌더했다. Android/iOS·Windows F5·모바일 성능과 전체 스테이지 밸런스는 미검증이다. [버전·실제 결과](docs/validation/GAME008_REPORT.json).

```sh
python tools/check_combat_cues.py
python tools/check_project.py --godot /actual/path/to/Godot
# 공격표현·금화·표시 설정 회귀도 기존 전장 피드백 시험에서 호출
Godot --headless --path . --script res://tests/test_combat_cues.gd
```

네이티브 사례는 기존 공격 표현과 전투/성장/선택 보존에 더해 금화 범위·확률·중복 처치/수집/정산·상한 보존·저장 실패/재시도·재로드·이전 설정 호환·실제 결과 UI를 다룬다. 다음 단일 작업은 기존 HUD의 스테이지 목표·정예/보스 등장 안내다.
