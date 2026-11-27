# GAME068 — 비야 S 일반 달리기17장 원화 납품

**원화 기술 채택 / 게임 미연결 / 최종 아트 NOT_VERIFIED**. 기존 GAME067의34클립·318프레임은 그대로다. 제작세션이 run_s11만 이17장으로 교체하면34클립·324프레임이 된다. 나머지33클립·307프레임과 E/SE 동작을 보존해야 한다.

| 항목 | 실제 납품 |
| --- | --- |
| RGBA PNG | frames/viya_run_s_000.png~016.png,200×248 |
| 원출력 | [candidate_01.mp4](../../../../tools/higgsfield/requests/game068/evidence/candidate_01.mp4),RGB H264/864×1072/24fps·97장/4.041667초·음성0 |
| 원출력 SHA-256 | 3a3e265b86320f21ed1970587c7faf2c997393a994127c68fa757cdac43007e1 |
| 작업 | Seedance2.5 omni_reference / 3a872c40-f3fc-4180-b143-13001f789f44 |
| 실제 선택 | 0기준 원천34~50 연속17장; 다음 대응51은 제외 |
| 원천 주기 | 1.416667~2.125000초,708.333ms |
| 게임용 시간표 | [frame_timing.csv](provenance/frame_timing.csv),명목660ms/기본235·stride155에서659.574468ms |
| 총구 | [muzzle_coordinates.csv](provenance/muzzle_coordinates.csv),새 원화에서 독립 측정17개 |
| 발 위상 | [phase_alignment.json](provenance/phase_alignment.json),권고0.4572192098143875 |
| 발 근거 | [foot_landmarks.csv](provenance/foot_landmarks.csv),새3/원천37과 새11/원천45의 반대쪽 지지·회복 자세 |
| 공통 등록 | scale0.22916666666666666=0.99×200/864,translation(1,0.3),root(100,248),표시69×85.56 |
| 실제 비용 | 유료 제출1/최대2건,실차감28/한도60,남은 예산32;조회잔액657→629,새 결제/충전0 |

전체97프레임의 S 정면 고각·성인 얼굴/의상·총기/양손 접촉·천 비대칭과 교대 보행을 순서대로 확인했다. 가운데 완전한 한 주기를 선택했고 새17장 전체를 흑/백/회색과 총구/발 랜드마크 표에서 확인했다. 사격·반동·구운 총구 효과는 요청하지 않았고 결과에서도 발견하지 못했다. 이전 S11 재생 영상이나 E/SE는 생성 구동 입력에 넣지 않았다. 실제 입력은 S00 시작/S05 보조 두 이미지뿐이다. S대기는 준비/업로드했지만 제출하지 않았다.

RGB 녹색 배경에서 별도 RGBA를 추출했다. 경계 배경색을 측정하고 녹색/청록 축과 불투명 내부색을 이용해 혼합 경계를 분리했다. 얇은 경계는 인접한 실제 내부색으로 복원하며 네이티브 알파라고 부르지 않는다. 한 고정 변환을 전체 프레임에 적용했고 프레임별 bbox 바닥 정렬·팔다리 조립·변형·가짜 중간 자세·핑퐁·끝 복제를 사용하지 않았다. [등록/개별 해시](provenance/source_registration.json) · [제작/비용](provenance/production.json) · [실제 채택 검토](../../../../tools/higgsfield/requests/game068/evidence/candidate_01_review.json).

[아트 비교 영상](provenance/art_review.mp4)은 기존 S11/신규S17/SE18을 같은 거리 위상에서 비교하는 Pillow/ffmpeg 분석물이다.69×85.56 목표는 영상에서69×86 정수 픽셀로 표시한다. **main.tscn 캡처나 FPS 검증이 아니다.** [전체 그림](provenance/contact_sheet.png) · [총구/발](provenance/landmark_review.png) · [끝→첫](provenance/seam_review.png). 마지막→첫 body MAE6.047은 내부 중앙값5.456과 함께 참고했으며,수치나 해시만으로 정상 보행을 판정하지 않았다.

새 위상은 기존 S00/05와 새3/11의 실제 반대쪽 지지/회복 자세를 비교해 원형 오프셋을 계산했다. 기존3/11을 그대로 복사하지 않았다. 두 앵커의 잔차는 약0.00802주기다. 다리 순서의2D 대응이며 물리 바닥·힘·무미끄러짐 증명이 아니다. 기존SE와 발 위치/카메라 투영 차이와 미세 의상/룬 픽셀 차이는 남는다. 실제 SE↔S/총구·정지/피격 전환은 제작세션이 검수하고 최종 아트는 프로듀서가 판단한다.

원본208/ARTFIX001/GAME064~067/SAVEFIX001과 게임/데이터/기존 자산1,405파일은 그대로다. 이번 게임 연결·main 실행0이며 이전GAME067 검증을 신규S 검증으로 재사용하지 않는다. [제작세션 인계](../../../../tools/higgsfield/requests/game068/DELIVERY_HANDOFF.md) · [재현 명령](provenance/REPRODUCE.md).
