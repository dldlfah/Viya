# GAME069 제작세션 인계 — 원화18장, 아직 게임 미연결

브랜치 `work/viya-turnaround-qa-20261117`. 출발872cc92, 기존 GAME068 게임 구현3fc25db·원화93e11ed. 이 변경은 GAME069 기획/원화 납품 커밋이며 게임 구현 커밋이 아니다. 실제 최신 HEAD와 CURRENT/NEXT를 다시 확인한다.

- `assets/characters/pilot_32/game069_s_run_fire/frames/viya_run_fire_s_000.png~017.png`와 `provenance/clip_metadata.json`·`frame_timing.csv`·`muzzle_coordinates.csv`·`foot_landmarks.csv`·`phase_alignment.json`·`source_registration.json`·`qa_report.json`을 검수한다. 원본/제작비/전체 해시는 README·manifest.json·CHECKSUMS.sha256를 따른다.
- 현재 활성 `res://assets/characters/pilot_32/game068_s_run/viya_game068_frames.tres`의 **34클립/324프레임 전부를 보존**해 선택적 `run_fire_s`18장만 추가한다. 완성 예상35클립/342프레임. 기존E/SE·S17·208원본/ARTFIX001/GAME064~068을 덮어쓰지 않는다. 현재 게임 선택은E/SE뿐이며 S 코드는 후속 구현이다.
- 전체 공통 캔버스200×248/root(100,248)/표시69×85.56·속도235/stride155·명목660ms/기본659.574468ms. 원천750ms와 게임 시간표를 구분하고 프레임별 원천 정수µs 비율을 지킨다. 기존 GAME068의 가중치/속도 구현을 참고하되 검사를 완화하지 않는다.
- 새 총구18개는 화면 정면으로 단축 투영된 **총열 구멍 중심**이다. 우측 알파 끝이나 S17의 긴 대각선 총구를 복사하지 않는다. 새 run_fire_phase_origin=**0.8510092121212124**, S17 origin=0.4572192098143875. local=global+origin(mod1). 반대 지지발2쌍 오차±0.014706주기이며 발 위치는 픽셀 일치가 아니다.
- 없거나 무효인 클립/메타데이터/총구/시간표/위상은 **동일한 전역 거리 위상 run_s17**로 복귀한다. 발사마다 gait 초기화, idle 폴백, 게임 속도/피해/발사 간격 변경은 하지 않는다.
- 실제main.tscn에서 on/off·즉시 명중/벽 소멸·SE↔S·후진 조준·정지사격·피격 우선·pause·18장전체/끝→첫·크기/총구/보행을 검증한다. 현 사격 관측 경로를 확장하고 매 실탄과 반동1:1동기화를 원화만으로 완료했다고 하지 않는다.
- PNG 임포트는 lossless와 fix_alpha_border=false로 RGBA 일치를 확인하고, 기록 CSV/검토이미지는 provenance/.gdignore로 자동임포트에서 제외한다. 이번에는 새SpriteFrames/슬롯/게임코드를 만들지 않았다.

Pillow/ffmpeg art_review.mp4는 같은 거리 위상/69×85.56의 원화 분석이다. 게임 캡처나 FPS 증거가 아니다. 휴대↔조준에서 상체 윤곽이 변하고 새 발 위치도 일부 다르므로 실제 전환 외관을 확인한다. 머리카락/작은 문양·무기 원근/최종 비주얼 승인은 프로듀서가 판단한다.

저장22/7난수/SAVEFIX001·스폰/AI/피해·HP/MP/보상·전투속도는 보존한다.1540과부하/경제/과거 무효 저장 자동복구/Windows·모바일/FPS/발열·최종아트/한판마감은 별도다. 다른 방향/몬스터/초상화로 확대하지 않으며 main병합/force push/유료Actions0·3D/리그/코스튬 보류·서포터2+2빈칸을 유지한다.
