# VIYA — 현재 작업 상태 / 메인 작업문서

기록일 **2026-11-27 (KST)**. 브랜치 **`work/viya-turnaround-qa-20261117`**. [누적 DEVELOPMENT_STATUS](DEVELOPMENT_STATUS.md) · [PLANNED_WORK](PLANNED_WORK.md) · [NEXT_TASK](NEXT_TASK.md).

## 최신 — GAME066 SE 달리기 검수 마감 → GAME067 SE 이동사격

사용자의 완료본 확인·필요한 수정·다음 진행 지시에 따라 원격 **`b42b7ed819e907810774cedd98f929d572d816ac`**의 SE18 게임 연결을 확인했다. 현재 검수 코드 기준은 **`f1998d280a03403d7022fd926a4f1e04ce52d247`**이며,원화 제작/게임 적용 커밋 b42b7ed와 이후 검증·인계 문서 커밋을 구분한다. [누적8.66](DEVELOPMENT_STATUS.md) · [검수 보고서](validation/GAME066_REVIEW_REPORT.json).

현재 활성 리소스는 `assets/characters/pilot_32/game066_se_run/viya_game066_frames.tres`다. SE run11→18의 파생물을 사용해 **33클립·298프레임**이며,다른32클립/280프레임의 경로·시간/루프와 기존 E47/E이동사격47·원본208/ARTFIX001을 보존한다. **200×248·표시69×85.56·pivot(100,248),이동235/stride155**와 명목660ms/거리주기659.574468ms·기존SE원점3/11을 유지한다.

**수정한 검수 연결:** 현재 SE 리소스를 따라오지 않은 보존 해시/변조 입력을 갱신하고 SE 전용 변조5개를 추가했다. 검사 코드의 동적/디렉터리 리소스 문자열2곳은 실제 첫PNG에서 경로를 구성하도록 수정했다. 전체 회귀에서 발견한 지도 검사2곳의 이전 GAME065 슬롯 기대값도 현재 GAME066으로 바꿨다. 다른 슬롯의 빈칸·기존 조건·오류/누수/120초 판정은 유지했다. SE 제작 기록 CSV가 번역 파일5개로 임포트되는 문제도 기존 E폴더와 같은 provenance/.gdignore·빌더 설정으로 막았다. 시간표의 원본 읽기는 유지하며 실제 게임/저장 코드나 원화는 변경하지 않았다.

**확정 PASS:** 기존10명령/7네이티브 묶음 **4,531검사**(23+70+122+57+1336+465+2458),각120초·엄격실패판정 유지. Python20·최종187소스/623참조·6계약/변이141거부. 빌더는 격리한 입력에서 재실행해 SpriteFrames/manifest/motion/slot4개 출력이 납품본과 바이트 동일함을 확인했다. 초기 회귀의 지도 슬롯2실패는 보존하고 최종 전체10명령을 다시 통과했다. 이후 제작 기록 임포트 설정만 추가한 뒤 정상 editor import와 관련465검사를 재통과했고 번역파일이 생성되지 않음을 확인했다.

**실제 전투 화면 PASS:** 별도 Xorg:100/Linux X11/Mesa llvmpipe OpenGL4.5·Dummy에서 생산 `main.tscn`을 **1,793검사/379그리기**로 확인했다. SE18전체/4회 반복·E↔SE 4왕복·입력 해제와 발 정지·기존 SE실발사8회·후진 조준48단계·정지공격·일시정지를 확인했다. 모든 그리기 전후 Snapshot/cues는 같다. [실제 전투 화면](validation/GAME066_REVIEW_IN_GAME.png) · [실제 SE 이동 영상](validation/GAME066_REVIEW_GAMEPLAY.mp4) · [로그](validation/GAME066_REVIEW_RUNTIME.log). 고정시간 갱신/주입한 Godot 키 이벤트의 검증으로 실시간FPS·물리 입력·사용자 Windows/모바일 검증과 구분한다.

추가 원화 수정을 요하는 구체적 결함은 찾지 못해 SE18을 유지했다. 공통 거리 위상/고정 root는 확인했으나 숫자3/11 보존을 카메라 간 완전한 족저 접지/무미끄러짐의 증명으로 삼지 않는다. [원화 위상 비교](validation/GAME066_REVIEW_PHASES.png)는 실제 게임 캡처와 별도다. 최종 아트는 프로듀서 판단이며 **NOT_VERIFIED**다. 과거 RGB 원출력 URL은 현재 네트워크403으로 독립 재다운로드하지 못했고,기존 RGBA/메타데이터·해시를 검증했다.

**보존:** 출발b42b7ed 대비 게임/저장 scripts와 기존 assets/data1272추적파일은 바이트 동일하고 새 파일은 제작 기록 임포트 제외용 .gdignore 하나뿐이다. SAVEFIX001·저장22/7난수·스폰/AI/피해/HP·MP/보상·6분 캠페인/3분 던전을 유지한다. 이번 생성/크레딧/결제0이다. GAME066 제작 당시58크레딧/마지막815.25는 과거 기록이며 이번 잔액 조회가 아니다. [현재 자산 등록](ASSET_MANIFEST.md)을 보완했다.

## 다음 한 단위 — GAME067 SE 전용 전신 이동사격

기획/Higgsfield 세션용 [한글 지시](../tools/higgsfield/requests/game067/PROMPT_KO.txt)·[영문 프롬프트](../tools/higgsfield/requests/game067/PROMPT_EN.txt)·참조 해시와 [SE18 기준 영상](validation/GAME067_SE_RUN_REFERENCE.mp4)을 준비했다. 영상은 현재 채택 달리기를600×744/60fps·198프레임·명목5주기로 재생한 참조이며 새 사격 원화가 아니다. 예전 GAME066_SE_RUN_REFERENCE는 교체 전11장 영상으로 보존한다.

**새 SE 이동사격 원화/게임 연결은 아직0**이다. 현재 이동 중 SE 실발사는 SE달리기18과 측정 총구로 표현하며 전용 사격 클립 선택은 E에만 있다. 새 출력이 오면 선택적run_fire_se·독립 총구/위상 메타데이터·같은 위상 SE달리기 폴백을 기존 표시 경로에 연결한다. 실제 발사/즉시 명중·벽 소비/해제·전후진·정지/피격·일시정지까지 확인한다. 다른 방향·적·초상화로 확대하지 않는다.

남은 범위는 최종 아트·Windows/모바일·실시간FPS/발열/실제 오디오·1540과부하·경제·과거 무효파일 자동복구·1스테이지 한 판 마감이다. 원본/기존게임 보존,main자동병합/force push/유료Actions 금지,3D/리그/코스튬 보류·지원2+2를 유지한다. 누적 이력과 당시 상태는 [DEVELOPMENT_STATUS](DEVELOPMENT_STATUS.md)에 보존한다.
