# VIYA — 다음 단일 제작 작업

## Windows Godot에서 1스테이지 3~5분 전투 확인

GAME074를 적용한 작업 브랜치에서 3:00, 3:30, 4:00, 5:00 구간의 프레임 간격과 이동 입력을 확인한다. Linux 계측에서 프레임이 느렸던 3:30과 적이 가장 많이 쌓인 5:00을 우선 비교한다. Windows에서도 끊김이 반복되면 발생 구간의 위치·시야·적 수를 기준으로 재현 장면을 좁힌다.

[현재 상태](CURRENT_WORK.md) · [GAME074 비교 측정](validation/GAME074_REPORT.json)

GAME075는사용자의최신 “적용해”로추가후보03의SW전용이동사격15장을연결했다. 기존35클립348을보존해36클립363이며선택불가/무효메타는같은거리위상SW17로복귀한다. 실제Linuxmain.tscn1,648검사49그리기43발·7네이티브4,740검사PASS다. 최초120초회귀TIMEOUT과별도480초제한전투표현2,469PASS를구분한다. 전환몸/발차이·최종아트/접지와Windows/모바일/FPS는별도검수다. 위Windows단일NEXT를유지한다. 연결추가지출0/제작누적3건89·자동4차없음. [실제화면/검증](validation/GAME075_INTEGRATION_REPORT.json) · [적용자산](../assets/characters/pilot_32/game075_sw_run_fire_candidate03/README.md).
