# Viya — 모바일 서바이버 게임

기존 BREAKERS와 독립된 프로젝트. **비야는 ART-001 승인 시안 확정 단계에서 보류하고 게임 기능을 먼저 제작한다.**

## 다음 세션 필수 문서

**[CURRENT_WORK](docs/CURRENT_WORK.md)와 [누적 DEVELOPMENT_STATUS](docs/DEVELOPMENT_STATUS.md)를 함께 읽는다.** [PLANNED_WORK](docs/PLANNED_WORK.md) · [NEXT_TASK](docs/NEXT_TASK.md) · [AGENTS](AGENTS.md) · [제작 스킬](.agents/skills/viya-game-production/SKILL.md). 캐릭터 수집/성급의 확정·잠정 기획은 PLANNED6절이며 실제 계정 특성과 구분한다.

활성 브랜치 `work/viya-turnaround-qa-20261117`, GAME-013 코드 기준 **`f7ae9dbd0eace9d82ac4f0b610c500fb80ac9348`**. 문서 커밋은 뒤에 오므로 원격 HEAD를 다시 확인한다. main 자동 병합은 하지 않는다.

## 이번 추가 — 계정 공통6종 특성

임시 메인 로비→계정 특성에서 공격/방어/회복 각2종을 독립적으로3단계 구매한다. 표의 값은 누적값이다.

| 분류 | 특성 | 1단계 | 2단계 | 3단계 |
| --- | --- | ---: | ---: | ---: |
| 공격 | 공격력 | +5% | +10% | +15% |
| 공격 | 공격 속도 | +2% | +4% | +6% |
| 방어 | 최대HP | +5% | +10% | +15% |
| 방어 | 받는 피해 감소 | 1% | 2% | 3% |
| 회복 | 초당HP 회복 | +0.05 | +0.10 | +0.15 |
| 회복 | 초당MP 회복 | +0.05 | +0.10 | +0.15 |

특성별 단계 비용은 기존과 같은1,000/50,000/1,000,000골드다. 골드와6종 단계를 기존 로컬 계정 파일에 함께 저장하고 모든 캐릭터의 새 전투에 공통 적용한다. 이어하기는 출격 당시6종과 소수 회복/피해감소 누적을 유지한다. 새 출격/확인 후 재시작부터 최신 계정을 적용한다. 기존 공격력 구매와 전투 저장1~4를 보존해 변환하며 신규 계정은0골드다.

6분·2/4분 저장·5분 보스, 정예1600/보스3200·웨이브2/4/6·원거리/고속/고체력·비행30/밀기를 유지한다. 필살기는 피해100·반경460·강화30/36·MP40·쿨타임0, 기본MP회복1에 계정 보너스를 더한다.18종/기본3선택/이름 `[임시]`/요구XP3배/기본5XP·공격4/패시브4·서포터2+2 빈칸과 아트 보류를 보존한다.

시작 경로는 `project.godot → scenes/main.tscn → mobile_main.gd → main.gd/기존 RunState`다. 로비/계정 특성→전투/XP/3선택/필살기→저장/이어하기→결과/금화→로비. PC WASD/방향키·F, 모바일 왼쪽 이동/오른쪽 마법이다.

## 검증

Godot4.7.2 임포트·기존7묶음 **2,112 checks**·시작 장면과 Python12시험은 PASS다. 실제6종 구매/전투 효과·저장1~4 호환·새 프로세스/소수 누적·3탭 일반/compact 렌더를 확인했다. 모바일·Windows F5·FPS·특성별6분 밸런스는 미검증이다. [버전과 실제 결과](docs/validation/GAME013_REPORT.json).

```sh
python tools/check_project.py --godot /actual/path/to/Godot
Godot --headless --path . --script res://tests/test_combat_cues.gd
# 별도 성장/완주 측정 도구
Godot --headless --path . --script res://tests/measure_campaign.gd
```

GAME-011의14~17선택/이전10~12목표 초과 FAIL은 과거 근거이며 이번6분 측정은 실행하지 않았다. 다음 단일 작업은 실제 원거리·비행 접근 모바일 표시다. 추가 경제 조정·철수 보상·장시간 모드·성급/수집 콘텐츠는 후속 계획이다.
