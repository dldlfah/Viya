# 플랜B 비야 — 몸체 후보01, 로컬 수정용

**게임에 연결하지 않은 아트 초안**이다. 기존2D36클립363과 플랜B 임시 시범은 보존한다. 정식 비야·완성 리그/동작 납품이나 프로듀서 승인이 아니다.

- 원본: [viya_body_raw.glb](source/viya_body_raw.glb), SHA-256 `cfac2cefc38525d7c0778e2eb3dae023146c0d28b83579f5b735444a6d125bdb`.
- 원출력에서 그대로 추출한 [색상텍스처](source/basecolor_0.jpg).
- 원래 재질/패킹 텍스처와 리그를 유지한 [편집용 검토 장면](review/viya_body_review.blend).
- [구조/공통 등록/뼈 목록](review/structure_report.json), [원본 명세](source_manifest.json), [전체 해시](CHECKSUMS.sha256).
- [정면](review/front.png) · [후면](review/back.png) · [좌측](review/left.png) · [우측](review/right.png) · [고각55도](review/game_high_angle.png) · [변형 정면](review/skin_stress_front.png) · [변형 측면](review/skin_stress_side.png).

몸체45,064삼각형·24관절·2048²색상텍스처1개다. 원본은 요청20,000/quad와 다르며 실제 모바일 성능은 아직 측정하지 않았다. 모든 몸체 정점에 가중치가 있지만 팔/머리와 다리/천의 부적절한 연결이 눈에 보인다. 손가락·머리/천 전용 뼈와 원래 룬 총기·Muzzle/왼손 지지점, 전용 액션은 미납품이다. 단일 bind-pose 표본은 달리기/사격이 아니다.

색상 비교는 원출력 텍스처를 그대로 emission 셰이더로 표시해 조명에 의한 탈색을 분리했다. 원래 서비스 셰이더는 .blend에서 복원했다. 머리색·후면 천과 얼굴/의상 일치 및 스키닝을 로컬에서 보완한 뒤 다시 검수해야 한다. `candidate_registration`은 전체에 적용한 공통 변환이며 임포터 뼈 표시 도형은 몸체 치수/정점 검수에서 제외했다. 변형 사진은 진단용 자세이며 납품 액션이 아니다.

[모델/입력·설정·작업ID·비용과 채택 판단](../../../../tools/higgsfield/requests/plan_b/b03/candidate_01/README.md). 유료1건/실차감35, 계정397→362→362. 원본 유지/추가생성0. 제작세션은 정식 비야 납품 전 대기하고 이 후보를 활성 게임 자산으로 교체하지 않는다.
