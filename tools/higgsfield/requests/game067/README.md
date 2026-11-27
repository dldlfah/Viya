# GAME067 — SE 전용 전신 이동사격

완료된 GAME066 SE18을 실제 전투에서 검수한 뒤 진행하는 한 방향의 제작 인계다. **새 SE 이동사격 원화/게임 연결은 아직 없다.** 현재 SE 이동 중 실발사는 기존 SE 달리기18과 측정 총구로 표시하며,전용 사격 클립 선택은 E에만 구현돼 있다.

- [한글 제작/연결 기준](PROMPT_KO.txt), [Higgsfield 영문 프롬프트](PROMPT_EN.txt), `request_plan.json`의 참조 해시를 사용한다. API 제출 스키마가 아니다.
- [현재 SE18 재생 영상](../../../../docs/validation/GAME067_SE_RUN_REFERENCE.mp4)은 기존 채택 달리기를 중성 회색에 그대로 재생한600×744/60fps/명목660ms·5주기 참조다. 새 사격/보간 프레임이나 FPS 측정이 아니다. 예전 GAME066_SE_RUN_REFERENCE는 교체 전11장 영상이므로 이번 입력과 혼동하지 않는다.
- 재현: 실제 디스플레이에서 `tools/export_viya_run_reference.gd -- --direction=se --output=res://.local_validation/GAME067_REFERENCE`를 실행하고 캡처를60fps로 인코딩한다. 원본 PNG는 변경하지 않는다.

원화는 사용자 지정 기획/Higgsfield 세션에서 제작한다. 실행 시 현재 기능/입력/비용·잔액을 다시 확인한다. 새 이미지가 오면 선택적SE사격/메타데이터와 폴백을 기존 표시 경로에 연결하고 생산 main.tscn에서 확인한다. SE/E 원본·SAVEFIX001·저장22/7난수·전투 규칙은 유지한다. 생성·기술 채택·게임 적용·실기·프로듀서 최종 승인은 구분한다.
