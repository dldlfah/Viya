# VIYA — 현재 작업 상태

2026-11-27 (KST) · `work/viya-turnaround-qa-20261117` · [누적 개발현황 8.75](DEVELOPMENT_STATUS.md#875-game070--sw-기준-검수와-입력-수정) · [다음 작업](NEXT_TASK.md) · [후속 계획](PLANNED_WORK.md)

## GAME070 — SW 기준 검수와 입력 수정

원격 `d5f7dfd59926f01199e2496e5c1cb51dc50b0b18`의 두 후보는 교체용 원화 미채택 상태다. 저장소의 확대 시트에서 후보 1의 43→44 자세 급변과 후보 2의 가까운 다리 지지 반복을 확인했다. 원본 ZIP 다운로드는 403으로 차단되어 원본 전체를 독립 재생하지 못했다. 이전 전체 검수와 비용은 그때의 기록으로 보존한다. [후보 기록](../tools/higgsfield/requests/game070/README.md)

현재 게임의 SW11은 실제 `main.tscn`에서 842개 검사와 136회 그리기를 통과했다. 전체 11장, 마지막→첫 2회, S↔SW 왕복, 정지, 프레임별 총구, 실제 자동사격 4발, 후진 조준, 서서 사격, 피격 우선, 일시정지를 확인했다. 실제 구현 기준은 GAME069 `9fe051c41ac8c92c021a7452021d064e635b4e1c`다. 현행 표시 경로에서 교체를 요구하는 오류는 재현되지 않았다. [SW 실제 게임 영상](validation/GAME070_SW_BASELINE.mp4) · [이동 사격 화면](validation/GAME070_SW_BASELINE_FIRE.png) · [검증 보고서](validation/GAME070_BASELINE_REPORT.json)

활성 리소스는 `res://assets/characters/pilot_32/game069_s_run_fire/viya_game069_frames.tres`의 35클립·342프레임이다. SW11을 교체할 유효한 원화가 아직 없다. 이번 검수의 신규 생성과 차감은 0이며 이전 2건과 56크레딧은 당시 제작 기록이다. 실행 검수는 Linux X11의 고정 업데이트와 Godot 입력 이벤트 기준이다. Windows·모바일, 실시간 성능, 물리 접지와 프로듀서 최종 아트 승인은 미검증이다.

다음 제작용으로 기존 SW 이미지의 시점과 외형, 검증된 S17 원천 영상의 보행 타이밍을 별도로 제공하도록 입력을 수정했다. S 타이밍 영상은 기존 원천 34~50번을 24fps로 반복한 102프레임이며, 새 SW 원화는 아직 없다. [입력 수정안](../tools/higgsfield/requests/game070/INPUT_STRATEGY.md) · [타이밍 참조](validation/GAME070_S_TIMING_REFERENCE.mp4)
