# Viya — 모바일 서바이버 게임

기존 BREAKERS와 독립된 프로젝트. **비야는 ART-001 승인 시안 확정 단계에서 보류하고 게임 기능을 먼저 제작한다.**

## 다음 세션 필수 문서

**[메인 작업문서 CURRENT_WORK](docs/CURRENT_WORK.md)와 [누적 개발현황 DEVELOPMENT_STATUS](docs/DEVELOPMENT_STATUS.md)를 함께 읽는다.** [통합 예정 PLANNED_WORK](docs/PLANNED_WORK.md) · [다음 실행 NEXT_TASK](docs/NEXT_TASK.md) · [AGENTS](AGENTS.md) · [제작 스킬](.agents/skills/viya-game-production/SKILL.md).

활성 브랜치 `work/viya-turnaround-qa-20261117`, GAME-012 코드 기준 **`5e896326bfa02779b7ce666fd555c210fb41b876`**. 문서 커밋은 뒤에 오므로 원격 HEAD를 다시 확인한다. main은 이전 기획본이며 게임 코드를 자동 병합하지 않는다.

## 이번 추가 — 임시 메인 로비와 계정 공통 특성

시작 시 메인 로비에서 출격/이어하기·골드·계정 특성을 확인한다. 특성창은 **공격·방어·회복** 탭이며 방어/회복 내용은 빈칸이다. 공격만 순서대로3단계를 구매한다.

| 단계 | 골드 비용 | 임시 누적 공격력 증가 |
| --- | ---: | ---: |
| 1 | 1,000 | +5% |
| 2 | 50,000 | +10% |
| 3 | 1,000,000 | +15% |

모든 캐릭터의 새 전투에 공통 적용하며 골드와 강화 단계는 기존 계정 파일에 함께 저장한다. 현재는 로컬 계정 기준이다. 이어하기는 출격 당시 특성을 유지하며 새 출격/확인 후 재시작부터 최신 단계가 적용된다. 기존 골드 파일과 전투 저장1·2·3을 보존해 변환한다. 신규 계정은0골드/0단계다.

기본6분·2/4분 저장·5분 보스, 정예1600/보스3200·웨이브2/4/6·원거리/고속/고체력·비행30 즉시 생성과 밀어내기를 유지한다. 필살기는 기본 피해100·반경460·강화30/36, MP40·초당1 회복·쿨타임0이다.

시작 경로는 `project.godot → scenes/main.tscn → mobile_main.gd → main.gd/기존 RunState`다. 로비/계정 특성→출격→전투/XP→3선택/전후 비교→필살기→체크포인트/중단/이어하기→결과/금화 정산→로비. PC WASD/방향키·F, 모바일 왼쪽 이동/오른쪽 마법 버튼 구조다.

18종/기본3선택/이름 `[임시]`/요구XP3배/드롭5/임시 공격4·패시브4/서포터2+2 빈칸 유지. 비야 원화·3D·리그·코스튬은 보류다.

## 검증

Godot4.7.2 임포트·기존 네이티브7묶음 **2,020 checks**·시작 장면, Python 실행기12시험은 PASS다. 실제 저장1·2·3 변환, 계정 강화/새 출격/사용 후 프로세스 재실행, 일반/compact Linux 렌더를 확인했다. 모바일·Windows F5·FPS·강화별 밸런스는 미검증이다. [실제 버전과 결과](docs/validation/GAME012_REPORT.json).

```sh
python tools/check_project.py --godot /actual/path/to/Godot
Godot --headless --path . --script res://tests/test_combat_cues.gd
# 기존 무강화 계정의 성장/완주 측정 도구
Godot --headless --path . --script res://tests/measure_campaign.gd
```

GAME-011의14~17선택/이전10~12목표 초과 FAIL은 과거 근거로 보존한다. 이번 단위에서6분 측정을 새로 실행하지 않았다. 다음 단일 작업은 실제 원거리·비행 접근의 모바일 표시다. 방어/회복 내용·추가 금화 사용처·경제 조정·철수 보상·장시간 모드는 후속 계획이다.
