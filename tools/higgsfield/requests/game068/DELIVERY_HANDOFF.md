# GAME068 — 제작세션에 인계

원화는 assets/characters/pilot_32/game068_s_run이다. **기술 채택17장/게임 연결0**. 기존 active는 GAME067의34클립/318프레임이다. 최신 생산 원출력/작업/비용과 반려하지 않은 이유는evidence/candidate_01_review.json,개별 해시는납품manifest/CHECKSUMS를 따른다. 새 생성은 반복하지 않는다.

1. 기존34클립 중run_s11만 신규17장으로 바꾼 파생 리소스를 만든다. 예상34클립/324프레임이며 나머지33클립/307프레임 경로·시간·loop/speed와 E47/E사격47/SE18/SE사격20을 보존한다. 이번 납품에는 게임 SpriteFrames/연결 코드를 만들지 않았다.
2. provenance/clip_metadata.json·frame_timing.csv·muzzle_coordinates.csv·foot_landmarks.csv·phase_alignment.json·source_registration.json을 읽는다. 명목660ms/거리659.574468ms·위상0.4572192098143875·새 총구17개를 쓴다. 기존3/11이나E/SE총구를 복사하지 않는다. Godot duration의float32 오차를 피하도록 GAME067의 원천 정수µs 가중치 방식도 참고하되 기존1µs 검사를 완화하지 않는다.
3.200×248/root(100,248)·69×85.56·이동235/stride155를 유지하고 PNG 재매트/alpha border 보정을 피한다. provenance/.gdignore로 CSV/QA 이미지를 자동 임포트에서 제외하되 원본CSV 읽기를 확인한다. 프레임별 알파bbox를 바닥에 정렬하거나 몸/팔다리를 변형하지 않는다.
4. 생산main.tscn에서 S 여러 주기/마지막→첫·SE↔S·입력 해제/정지·기존 일반 달리기 중 실제 자동 사격/총구·후진·피격 우선/pause·크기를 확인한다. S 전용 이동사격은 만들지 않는다. 원화분석영상을 실제게임 검증으로 쓰지 않는다.

새S와 기존SE의 발 위치/투영 차이와 미세 접지는 남는다.2D위상은 실제 전환/무미끄러짐/최종 아트 승인이 아니다. 원본208/ARTFIX001/GAME064~067/SAVEFIX001·저장22/7난수·스폰/AI·피해/보상/HP·MP·전투 속도를 보존한다. Windows/모바일/FPS/발열·최종아트/1540부하·경제/한 판 마감은 별도다. main자동병합/force push/유료Actions 금지·3D보류·지원2+2 빈칸을 유지한다.
