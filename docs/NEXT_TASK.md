# VIYA — 다음 단일 제작 작업

## GAME070 — 보행 타이밍 참조로 SW 한 주기 확보

[현재 상태](CURRENT_WORK.md) · [입력 수정안](../tools/higgsfield/requests/game070/INPUT_STRATEGY.md) · [실제 SW11 기준](validation/GAME070_SW_BASELINE.mp4) · [S17 타이밍 참조](validation/GAME070_S_TIMING_REFERENCE.mp4)

기획세션에서 준비한 입력 ZIP의 두 SW 이미지와 S17 타이밍 영상, 프롬프트를 사용한다. SW 이미지는 왼쪽 아래 시점과 외형을, S17 원천 34~50번은 양발 교대와 리듬을 지정한다. 현재 모델의 참조 역할과 견적을 확인한 뒤 적용 가능한 제작 범위에서 진행한다. 직전 GAME070 제작의 제출 2회는 이미 사용했다. [패키지 재현](../tools/higgsfield/requests/game070/INPUT_STRATEGY.md) · [검증된 입력 명세](../tools/higgsfield/requests/game070/READY_PACKET.json)

같은 다리의 지지 자세가 다시 오기까지 반대 다리가 한 번 지지하는 연속 주기와 마지막→첫 이음을 검수한다. 유효한 주기가 확보되면 SW11만 대체하고 기존 다른 34클립·331프레임을 보존한다. 독립 총구, 발 위상, 실제 시간표와 고정 등록을 납품받고 `main.tscn`에서 이번 SW11 기준과 비교한다.

현재 게임은 GAME069 35클립·342프레임이며 교체용 원화 대기 중이다. 이번 Linux X11 실행은 기존 SW11의 재생과 전투 상태를 검증했다. 저장·전투 규칙과 기존 작업 브랜치 지침은 계속 적용한다.
