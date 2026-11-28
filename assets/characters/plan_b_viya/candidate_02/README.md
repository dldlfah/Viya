# 플랜B 비야 — 첨부 정면·후면 후보02

**로컬 수정 기반으로 추천하는 아트 초안이며 게임 미적용**이다. 후면 천의 분리 형태는 후보01보다 개선됐지만 머리/천 스키닝과 얼굴·색/세부는 미완성이다. 정식 비야·리그/동작 납품이나 프로듀서 승인이 아니다.

- [원본GLB](source/viya_body_raw.glb):6,877,492바이트/SHA-256 `d9e022805f30fbb6c3216873928b8330da280d88f0e569c74fbe03721ba47187`.
- [원본에서 그대로 추출한 색상JPEG](source/basecolor_0.jpg), [편집용 .blend](review/viya_body_review.blend), [구조/등록/뼈 목록](review/structure_report.json), [전체해시](CHECKSUMS.sha256).
- [이전후보01 대비표](review/candidate_01_vs_02.jpg), [흑/백/회색](review/background_review.jpg), [정면](review/front.png) · [후면](review/back.png) · [좌측](review/left.png) · [우측](review/right.png) · [고각55도](review/game_high_angle.png) · [진단변형 정면](review/skin_stress_front.png) · [진단변형 측면](review/skin_stress_side.png).
- 첨부 바이트 원본: [정면](references/front.png) · [후면](references/back.png) · [화면왼쪽측면](references/screen_left_profile.png) · [화면오른쪽측면](references/screen_right_profile.png). 생성에는 정면/후면2장을 썼고 측면2장은 비교용이다. 자세/복장이 완벽히 일치하는 턴어라운드로 승격하지 않는다.

몸체44,833삼각형·24관절·2048²색상텍스처1/재질1이다. 요청20,000/quad와 다르며 기기 성능은 미검증이다. 단일bind-pose는 달리기/사격 액션이 아니다. 원래 서비스 재질/패킹 텍스처는 .blend에서 유지했고 색상 비교만 원본텍스처emission으로 표시했다. 공통 등록은 한 번의 전체 변환이며 프레임별/팔다리별 재정렬을 하지 않았다. 진단자세는 저장 전 복원했다. 편집본은Blender4.3.2로 다시 열어24뼈/패킹텍스처를 확인했다.

후면 천이 좌우로 갈라지고 반바지·다리가 드러나 실제 첨부 후면에 가까워졌다. 반면 일부 머리가 팔을 따라 끌리고 천이 다리에 과하게 따라간다. 붉은 머리색/평평한 머리 표면과 얼굴·의상 정합도 보완이 필요하다. 머리/천 전용 제어·손가락·원래 룬 총기/왼손 지지/Muzzle·독립 액션은 아직 없다. 제작세션은 이 후보로 정식 자산 대기를 해제하지 않는다.

[모델·입력/옵션·작업ID·원가·채택 판단](../../../../tools/higgsfield/requests/plan_b/b03/candidate_02/README.md). 이번추가1건35·계정362→327→327, 플랜B누적2건70이다. 자동세번째/유료추가출력/충전없음. 기존후보01/게임36클립363·전투/저장 규칙은 보존한다.
