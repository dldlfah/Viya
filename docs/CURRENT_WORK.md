# VIYA — 현재 작업 상태

2026-11-27 (KST) · `work/viya-turnaround-qa-20261117` · [누적 개발현황 8.77](DEVELOPMENT_STATUS.md#877-game070--입력-패키지-실검증과-현재-견적) · [다음 작업](NEXT_TASK.md) · [후속 계획](PLANNED_WORK.md)

## GAME070 — SW 기준 검수와 입력 수정

현재 연결된 Higgsfield에서 입력 패키지를 실검증했다. 지정 ZIP이 이 환경에 없어 저장소 빌더로 같은 경로에 복원했고 SHA-256 `4d882207c75685f04f27dc8bf246795ce3b75d0c34578c354f1d1e34d53a8a2c`가 READY_PACKET과 일치했다. 5개 구성파일 해시·ZIP CRC·타이밍 영상102프레임/24fps/4.25초 전체 디코딩과 이미지/보행 순서를 확인했다.

현재 Seedance2.5는 이미지 참조2개/영상 참조1개·omni_reference/4초/720p/3:4/무음/후보1개를 지원한다. 세 업로드의 바이트 해시와 확인 응답을 확보했고 현재 견적은 **28크레딧**, 현재 잔액은 **514**다. 이전 SDK 인증 부재는 당시 실행기의 기록이며 현재 커넥터는 연결돼 있다. [실제 조회/입력/견적 기록](../tools/higgsfield/requests/game070/evidence/packet_9927fcd/preflight.json).

이번 새 유료 제출/차감은0이다. 기존 GAME070은2회/56크레딧을 사용해 제출횟수2회를 이미 소진했고 잔여4도 이번28 견적에 부족하다. 준비된 새 입력1건을 실제 제출하려면 **추가1건/28크레딧**을 기존 한도 밖에서 별도로 정해야 한다. 이를 새 작업이라는 이름으로 자동 초기화하지 않는다. 허용 시 누적3회/84크레딧이며 추가 후보를 자동 제출하지 않는다.

직전 제작세션(8.76)에서 기획세션용 ZIP을 준비했다. 세로 3:4의 SW 외형 이미지 두 장, S 타이밍 영상, 프롬프트와 입력 역할 명세가 들어 있다. ZIP 재현, 이미지 여백과 원본 불투명 픽셀, 영상 102프레임의 전체 디코딩을 검증했다. 당시 공식 SDK는 `MISSING_CREDENTIALS`를 반환했다. 새 작업 제출과 추가 차감은 0이다. [패키지 생성·실행 근거](../tools/higgsfield/requests/game070/READY_PACKET.json) · [기획세션 지시](../tools/higgsfield/requests/game070/PACKET_README.md)

원격 `d5f7dfd59926f01199e2496e5c1cb51dc50b0b18`의 두 후보는 교체용 원화 미채택 상태다. 저장소의 확대 시트에서 후보 1의 43→44 자세 급변과 후보 2의 가까운 다리 지지 반복을 확인했다. 원본 ZIP 다운로드는 403으로 차단되어 원본 전체를 독립 재생하지 못했다. 이전 전체 검수와 비용은 그때의 기록으로 보존한다. [후보 기록](../tools/higgsfield/requests/game070/README.md)

현재 게임의 SW11은 실제 `main.tscn`에서 842개 검사와 136회 그리기를 통과했다. 전체 11장, 마지막→첫 2회, S↔SW 왕복, 정지, 프레임별 총구, 실제 자동사격 4발, 후진 조준, 서서 사격, 피격 우선, 일시정지를 확인했다. 실제 구현 기준은 GAME069 `9fe051c41ac8c92c021a7452021d064e635b4e1c`다. 현행 표시 경로에서 교체를 요구하는 오류는 재현되지 않았다. [SW 실제 게임 영상](validation/GAME070_SW_BASELINE.mp4) · [이동 사격 화면](validation/GAME070_SW_BASELINE_FIRE.png) · [검증 보고서](validation/GAME070_BASELINE_REPORT.json)

활성 리소스는 `res://assets/characters/pilot_32/game069_s_run_fire/viya_game069_frames.tres`의 35클립·342프레임이다. SW11을 교체할 유효한 원화가 아직 없다. 이번 검수의 신규 생성과 차감은 0이며 이전 2건과 56크레딧은 당시 제작 기록이다. 실행 검수는 Linux X11의 고정 업데이트와 Godot 입력 이벤트 기준이다. Windows·모바일, 실시간 성능, 물리 접지와 프로듀서 최종 아트 승인은 미검증이다.

다음 제작용으로 기존 SW 이미지의 시점과 외형, 검증된 S17 원천 영상의 보행 타이밍을 별도로 제공하도록 입력을 수정했다. S 타이밍 영상은 기존 원천 34~50번을 24fps로 반복한 102프레임이며, 새 SW 원화는 아직 없다. [입력 수정안](../tools/higgsfield/requests/game070/INPUT_STRATEGY.md) · [타이밍 참조](validation/GAME070_S_TIMING_REFERENCE.mp4)
