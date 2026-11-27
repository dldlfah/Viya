# VIYA — 현재 작업 상태 / 메인 작업문서

기록일 **2026-11-27 (KST)**. 브랜치 **`work/viya-turnaround-qa-20261117`**. [누적 DEVELOPMENT_STATUS](DEVELOPMENT_STATUS.md) · [PLANNED_WORK](PLANNED_WORK.md) · [NEXT_TASK](NEXT_TASK.md).

## 최신 — GAME067 실제 전투 화면 검수 마감 → GAME068 S 달리기

사용자의 완료본 확인·필요 수정·다음 진행 지시에 따라 원격 **`ce7e77939fb076f18352552262a6dcecb690c2b1`**을 받아 검수했다. 원화 납품은31b80cc, 게임 연결은ce7e779, 이번 검수 도구 코드는 **`30058bb31894d56ef5fdffe1446ac0b38ab73342`**다. [누적8.69](DEVELOPMENT_STATUS.md) · [검수 보고서](validation/GAME067_REVIEW_REPORT.json).

활성 리소스는 `res://assets/characters/pilot_32/game067_se_run_fire/viya_game067_frames.tres`다. **34클립·318프레임**으로 E 달리기47/E 이동사격47/SE 달리기18/SE 이동사격20을 사용한다.200×248·표시69×85.56·pivot(100,248), 이동235/stride155·명목660ms/거리659.574468ms·SE 사격 독립 위상0.819949494949495를 유지한다.

**실제 화면 PASS:** 이번 환경은 일반 sandbox에서 별도 Xorg:100이 정상 시작됐다. 이전 세션의 소켓 제한/자동 승인 거절은 당시 이력이며, 이번에는 제한 해제나 사용자 설정 변경 없이 검수했다. Linux X11/Mesa25.0.7 llvmpipe/OpenGL4.5·Dummy의 생산 `main.tscn`에서 **2,473검사·444회 그리기·실제43발·실패0**을 확인했다. SE18 전체/4위상 반복·SE 사격20 전체/끝→첫2회·사격on/off·E↔SE·후진48·정지사격·즉시 명중/벽 소멸·실제 접촉 피격100→88/hurt 우선·pause를 확인했다.444회 그리기 전후 Snapshot/cues는 같다. [사격과 해제 영상](validation/GAME067_REVIEW_MOVING_FIRE.mp4) · [전체 검수 영상](validation/GAME067_REVIEW_GAMEPLAY.mp4) · [실제 화면](validation/GAME067_REVIEW_IN_GAME.png) · [실행 로그](validation/GAME067_REVIEW_RUNTIME.log).

검수 도구에 격리 출력 인자·연속 캡처·전환 기록과 명시적 사격 루프 검사를 추가했다. 구체적 추가 원화/게임 오류는 발견하지 못해 **출발ce7e779의 assets/scripts/data1,405개 추적 파일 모두 바이트 동일**하다. 납품 CHECKSUMS36개와 저장된 RGB 원출력 해시도 일치하고, 격리 빌더4출력도 동일하다. 원본208/ARTFIX001/GAME064~067/SAVEFIX001·저장22/7난수·스폰/AI/피해/보상·전투 속도를 보존했다. 이번 생성/크레딧/결제는0이다.

**전체 회귀 PASS:** Godot4.7.2 기존10명령/7묶음 **4,558=23+70+122+57+1336+492+2458**, Python20·189소스/629참조·6계약/변이177거부(전투144). 기존 오류/누수·명령당120초와 runner 해시를 유지했다. 이번 전체 실행 근거이며 과거 검증 숫자의 재사용이 아니다.

영상은 고정1/60초 갱신·주입 Godot 키 이벤트의 캡처 재생이다. 전체 영상은 QA 장면 전환을 포함하며 실시간FPS/연속 플레이 시간의 증명이 아니다. VSync 미지원 경고/Dummy 오디오 환경이고 Windows/모바일·물리키/터치·발열·실제 오디오·최종 아트는 NOT_VERIFIED다. SE18/SE 사격20의 발 위치 차이와 미세 접지 한계는 남아 있다. 수치 위상/화면 검수를 무미끄러짐·프로듀서 최종 승인으로 확대하지 않는다.

## 다음 한 단위 — GAME068 남쪽(S) 일반 달리기

완료한 SE의 인접 S는 아직 기존11장이다. 한 방향 일반 보행부터 진행하도록 [기획/Higgsfield 패킷](../tools/higgsfield/requests/game068/README.md)·[한글 지시](../tools/higgsfield/requests/game068/PROMPT_KO.txt)·[기존 S11 기준 영상](validation/GAME068_S_RUN_REFERENCE.mp4)을 준비했다. 기준 영상은 현재 자산을600×744/60fps·198장·명목5주기로 실제 Godot 재생한 참조다. **새 S 원화/교체 연결은 아직0**이다.

현재34클립/318에서run_s11만 대체하고 나머지33클립/307프레임은 보존한다. 새 총구/발 위상은 독립 측정하며 S 전용 이동사격/다른 방향은 이번에 생성하지 않는다. 원화는 기획/Higgsfield 세션이 현재 입력·모델/알파·가격/잔액을 확인해 제작하고, 제작 세션이 게임 연결·검증한다. 이전657잔액은 과거 기록이다.

후속은 필요한 방향→고블린1종→전투 표시/아이콘→초상화4종→1스테이지 마감이다.1540과부하·경제·과거 무효 저장 자동 복구·실기/최종 아트는 별도다. SAVEFIX001의 극소 비행 수명 결함은 수정 완료다. main 자동 병합/force push/유료 Actions 금지·3D/리그/코스튬 보류·서포터2+2 빈칸을 유지한다.
