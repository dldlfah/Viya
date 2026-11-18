# Viya — 모바일 서바이버 게임

기존 BREAKERS와 독립된 프로젝트. **현재 UI와 챕터1 전장 기반은 임시 그래픽이며, ART-001 이후 정식 원화·3D 제작은 보류**한다.

## 세션 필수 문서

[CURRENT_WORK](docs/CURRENT_WORK.md)와 **[누적 DEVELOPMENT_STATUS](docs/DEVELOPMENT_STATUS.md)**를 함께 읽는다. [PLANNED_WORK](docs/PLANNED_WORK.md) · [NEXT_TASK](docs/NEXT_TASK.md) · [AGENTS](AGENTS.md) · [제작 스킬](.agents/skills/viya-game-production/SKILL.md). GAME-017 코드 **`b62474925244e08cb2e731b6c2218056519ac53f`**, 브랜치 `work/viya-turnaround-qa-20261117`. 문서 HEAD는 코드 뒤에 오며 main 자동 병합은 하지 않는다.

## 실제 플레이 경로

도시 로비 → 챕터/스테이지 선택 → 출격 →6분 전투/3선택/필살기 →2·4분 저장·이어하기 →5분 보스 →클리어/금화·결과 →로비/다음 전장이다. 기존 계정18종·54구매/선행 잠금은 유지하며 수집·뽑기·도시·원정은 **준비 중**이다.

| 전장 | 시험 크기 | 실제 차이 |
| --- | --- | --- |
| 프롤로그 성벽 |5000×3200 | 충돌 성벽/성문·폐허·전이 위치·진격로. 초기 정면→2분 첫 측면→4분 양 측면 |
| 도시 외곽 시험 지역 |4200×2800 | 별도 폐허/다방향 생성·일반 전투 |

`maps.json`이 맵 ID/크기/시작/이동·카메라 범위/장애물/생성 구역·시간·비중을, `stages.json`이 스테이지 맵/6분/적 수치를 관리한다. 카메라는 경계에서 멈추고 지상 적은 장애물을 우회하며 투사체는 지형에서 차단된다. 비행은 지형 위 직선 이동/적 밀기, 기존 범위 마법 판정은 유지한다. 새 맵 생성은 화면/지형 밖 유효 지점을 요구하며30무리를 부분 생성하지 않는다.

실제 보스 HP·등장 안내·둔화·HP/MP/반응·두 줄 스킬·서포터2+2 빈칸·터치 이동/필살기·안전영역/compact를 연결했다. 빈 `presentation_slots.json`에 나중에 텍스처/프레임·아이콘을 연결한다. 임시 도형은 최종 비야/몬스터 디자인이 아니다.

저장9는 이전1~8의 진행·좌표·자원·특성·보상을 보존해 기존 맵/좌표에서 이어간다(1~7은1800×1200,8은저장 맵 유지). 이전 전투에는 구조물을 소급 지급하지 않으며 신규 출격부터 적용한다. 기존3인자 `RunState.start`는 레거시 호환용이며 실제 UI는 스테이지 맵 ID를 넘긴다. 실행은 기존 `main.tscn → mobile_main/main → 단일 RunState`다.

두 맵에 상자/항아리/잔해 **각32개**를 자동 공격·스킬로 파괴할 수 있다. 매 파괴20%로1개 아이템: 성공 후HP40%/MP40%/전체 자석10%/보스 제외 제거10%다. 회복은 임시 최대치30%, 자석은 맵 전체XP/금화, 제거는 정예까지 기존 처치 보상·보스 면역이다. **파괴45초 후 재생성**하며 비활성 시간은 멈춘다. 이전 드롭과 새 회차 아이템/남은 시간·독립 난수를 저장한다. 소형 물체는 이동 비충돌이며 기존 성벽·성문 충돌을 유지한다.

## 검증

Godot4.7.2 소스/임포트·기존7묶음 **2450 checks**·부트와 Python12는 PASS다. 실제 저장1~8/새9의 별도 프로세스·실제 로비/선택/두 전장/경계·일반/compact 렌더를 확인했다. [정확한 소스와 근거](docs/validation/GAME017_REPORT.json).

```sh
python3 tools/check_project.py --godot /actual/path/to/Godot
Godot --headless --path . --script res://tests/test_combat_cues.gd
# map: prologue_wall / outskirts_trial / legacy_arena; talents: none / roots / full
Godot --headless --path . --script res://tests/measure_campaign.gd -- --map=prologue_wall --talents=none
```

두 새 맵·무강화/전체강화·5시드의20회는16클리어/2시간 초과/2패배였다. 선택22~28회로10~12목표 **FAIL**이며 XP/가격은 유지했다. 모바일·Windows F5·성능·사람의 난도/경제는 미검증이다. 다음 작업은 두 전장의 공세/성장 밸런스다. 전체 챕터/컷신/정식 아트·수집/성급·철수/장시간 모드는 후속이다.
