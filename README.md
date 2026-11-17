# Viya — 모바일 서바이버 게임

기존 BREAKERS와 독립된 프로젝트. **비야 ART-001은 승인 시안 단계에서 보류하고 게임 기능과 실제 실행 검증을 우선한다.**

## 세션 시작

**[메인 작업문서](docs/CURRENT_WORK.md)와 [누적 개발현황·인수인계](docs/DEVELOPMENT_STATUS.md)를 함께 읽는다.** [통합 계획](docs/PLANNED_WORK.md) · [다음 작업](docs/NEXT_TASK.md) · [작업원칙](AGENTS.md) · [제작 스킬](.agents/skills/viya-game-production/SKILL.md) · [게임 기획](docs/GAME_DESIGN_BASELINE.md) · [승인 아트](docs/ART_APPROVAL.md).

활성 브랜치는 **`work/viya-turnaround-qa-20261117`**다. 이전 원격 기준 `83ca47e4d391` 뒤에 미반영 통합 수정 코드 `bd76bac7c4ca1547f24de397d080ba180b826269`와 후속 기록/환경 준비 코드가 이어진다. **과거 로컬 PENDING.patch를 다시 적용하지 않는다.** main은 이전 기획본으로 유지되어 게임 코드가 아직 병합되지 않았다.

## 현재 코드 경로

`project.godot → scenes/main.tscn → scripts/ui/mobile_main.gd (main.gd 상속) → RunState 하나`.

출격 → 이동·자동사격 → 실제 처치/XP 수집 → 무작위3선택·강화 → 수동 마법 → 피드백 → 패배 또는 확인 후 포기 → 결과 → 대기/재출격. PC WASD/방향키, 이동 드래그, 마법 버튼/F, 보유 스킬칸의 읽기 전용 상세창을 작성했다. 좁은 HUD·카드 스크롤·확인/취소·상태 보존을 포함하지만 **전체의 실제 Godot 실행은 아직 미검증**이다.

이번 통합 수정은 상세창 닫기의 오래된 콜백 차단과 기존 소스 검사6종의 통합 실행이다. 18종 구성, 스킬명 `[임시]`, 요구XP3배, 기본 드롭5XP, 임시 장착4+4와 서포터 빈칸2+2는 변경하지 않았다. 임시 도형·문구는 최종 비야 아트가 아니다.

## 개발 실행환경 지침

아래 명령은 개발 에이전트가 전체 체크아웃에서 실행한다. 사용자에게 수동 패치나 PC 로그 제출을 요구하는 절차가 아니다.

```sh
# Python 실행기 자체 시험: 위임 검사/엔진은 테스트용 mock, 게임 검사와 별개
python -m unittest discover -s tests -p test_check_project.py -v

# Linux x86_64 개발환경: 공식 Godot 4.7.2 ZIP 체크섬 검증/캐시 준비 후 실제 검사
python tools/bootstrap_godot.py --check

# 엔진이 이미 준비된 환경: 기존 소스/데이터 + 네이티브 7종 시험 + 시작 장면
python tools/check_project.py --godot /actual/path/to/Godot
```

bootstrap은 계정/Codex 환경을 생성하지 않는다. 별도 root 권한·유료 CI·사용자 PC 변경 없이 실행용 바이너리를 개발환경 캐시에 준비하는 스크립트다. 공식 ZIP을 이미 갖춘 환경에서는 `--archive`를 사용할 수 있다.

## 실제 결과와 미검증

Python 실행기 단위시험 **12개 PASS**, bootstrap 구문/도움말 PASS. 실제 다운로드 시도는 DNS 오류로 종료2, **Godot 설치·네이티브 검사·화면·모바일 NOT_VERIFIED, 최신 전체 프로젝트 회귀 NOT_RUN, Codex 클라우드 환경 NOT_CREATED**다. [최종 검사 보고서](docs/validation/GAME004_INTEGRATION_RECOVERY_REPORT.json) · [환경 시도 로그](docs/validation/GAME004_ENVIRONMENT_ATTEMPT.log).

새 기능·캐릭터·연출 단계를 계속 늘리지 않고 기존 기본 루프의 실제 실행과 첫 오류 수정을 다음 단위로 유지한다. main 병합·배포·유료 Actions는 별도 승인 없이 수행하지 않는다.
