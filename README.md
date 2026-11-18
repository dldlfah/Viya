# Viya — 모바일 서바이버 게임

기존 BREAKERS와 독립된 프로젝트. **비야 ART-001 승인 시안 이후 원화·3D는 보류하고 게임 기능을 먼저 제작한다.**

## 다음 세션 필수 문서

**[CURRENT_WORK](docs/CURRENT_WORK.md)와 [누적 DEVELOPMENT_STATUS](docs/DEVELOPMENT_STATUS.md)를 함께 읽는다.** [PLANNED_WORK](docs/PLANNED_WORK.md) · [NEXT_TASK](docs/NEXT_TASK.md) · [AGENTS](AGENTS.md) · [제작 스킬](.agents/skills/viya-game-production/SKILL.md). 수집/성급은 PLANNED6절, 계정 특성7절, 비야 전이/챕터1 기획8절, 이번 추가 생성9절이다.

활성 브랜치 `work/viya-turnaround-qa-20261117`, GAME-015 코드 기준 **`317bc40fae659e81c5d6bcf6737867323985b425`**. 문서 커밋과 원격 HEAD를 별도로 확인한다. main 자동 병합은 하지 않는다.

## 이번 추가 —30마리 산개 무리

기존 웨이브·원거리·정예/보스·확률형30비행은 그대로 등장한다. 여기에 **12초마다 일반 → 고속 → 고체력 → 비행을30마리씩** 추가한다. 종류별48초 순환이며6분에29개 무리/870개체가 추가된다. 추가 무리에는 원거리·정예·보스를 넣지 않는다.

6열×5행의 넓은 대형에 개별 좌표 흔들림을 주고 지상은 추적, 비행은 기존 직선 이동/밀기를 따른다. 추가 개체가 기존 지상160개체와 보스 예약 자리를 차지하지 않으며 별도 난수·시간/순서를 저장한다. 간격/산개 폭/접근 거리는 `data/stages.json`의 임시 조정값이다. 화면 밖 생성과 모바일 성능은 보장하지 않는다.

전투 저장7은 이전1~6의 기존 특성·HP/MP·적·보상을 보존한다. 이전 전투에 새 무리를 소급 생성하지 않고12초부터 시작한다. 실제 처치·XP·금화 정산을 그대로 사용한다.

## 유지하는 게임 흐름

임시 로비→계정18종·각3단계(54회 구매)/같은 레벨 선행 잠금→6분 전투/전투18후보·3선택→2/4분 저장·5분 보스→클리어·금화→로비다. 계정3의 기존 가격과 효과, 마나 필살기·요구XP3배/기본5XP·공격/패시브 두 줄·서포터2+2 빈칸을 유지한다. 새 출격은 최신 계정, 이어하기는 출격 당시 특성을 적용한다. PC WASD/방향키·F, 모바일 왼쪽 이동/오른쪽 마법이다.

시작 경로는 `project.godot → scenes/main.tscn → mobile_main.gd → main.gd/단일 RunState`다. 챕터1/프롤로그/맵 확대·컷신·수집/성급은 기획이며 이번에 제작하지 않았다.

## 검증

Godot4.7.2 소스/임포트·기존7묶음 **2,305 checks**·부트와 Python12는 PASS다.6분 생성 대조·1,059개체 저장/로드·이전1~6/새7의 별도 프로세스 복원·일반/compact 렌더를 확인했다. [버전과 실제 근거](docs/validation/GAME015_REPORT.json).

```sh
python3 tools/check_project.py --godot /actual/path/to/Godot
Godot --headless --path . --script res://tests/test_combat_cues.gd
# none / roots / full: 현재 모두 기존 성장 목표 초과로 종료1
Godot --headless --path . --script res://tests/measure_campaign.gd -- --talents=none
```

같은5시드에서 무강화3클리어/1패배/1시간 초과, 기존6종 최대/18종 최대 각5클리어였다. 선택21~28회로10~12목표 **FAIL**이며 XP 수식은 유지했다. 모바일·Windows F5·FPS/발열·사람의 난도/경제 균형은 미검증이다. 다음 단일 게임 작업은 실제 공세 접근 표시다.
