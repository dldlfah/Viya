# B-03-03 — 눈꺼풀·코·입술의 되돌릴 수 있는 국소 형태 수정

2026-11-28 KST · 기획·아트 · 기준 원격 `3960e5f4e078b5e786e8d11d166c90c690b1dfaf`

**상태: B-03-03 진행, 원화 형태 자체 검수 미통과.** 기존 머리 초안을 직접 수정한 결과이며 정식 비야 얼굴/모델 납품이 아니다. 이번 유료 제출·실차감0, 잔액 재조회 없음. 기존 누적3건100/마지막 관측297은 과거 기록이다.

- [원화와 현재 무채색 형태](review/reference_vs_refinement.png)
- [정면: 이전 → 첫 국소 수정 → 눈꺼풀 재수정](review/front_comparison.png)
- [같은 조건의 다섯 시점 전후](review/multiview_comparison.png)
- 편집 원본: `viya_head_refinement.blend`
- [검수 판단과 다음 수정](review_result.json) · [재개방](reopen_result.json) · [원본/픽셀 보존](pixel_preservation_result.json)

## 실제 수정

입력은 `../head_shape_v1/cc0_topology_trial/cc0_head_topology_study.blend` 하나다. 기존 성인 기본형·비율 제어, UV와 토폴로지·원본 정점 인덱스를 유지하고 `REFINE_Eyelids`, `REFINE_Nose`, `REFINE_Lips`의 독립 Shape Key를 추가했다. 각 새 Key는 기존 `VIYA_reference_proportion_STUDY`를 상대 기준으로 하며 값0으로 해당 수정만 되돌린다. 기존 비율 Key 값은1을 유지한다.

공식 MPFB 눈 변위 자료10개의 원본 바이트/Git blob을 조회·검증하고 보존했다. 실제 정점 위치로 corner1이 바깥 눈꼬리, corner2가 안쪽임을 확인했다. 이름만 보고 역할을 정하지 않았다. 사용한 것은 양쪽 scale/height2/corner1 세 쌍이며 height1/corner2는 조사만 했고 가중치0이다. 새 자료/출처는 `source_registry.json`, 사용 가중치와 실제 해시는 `build_result.json`에 있다. 사용권 원문은 이전 패킷에 보존된 동일 CC0 자료 고지를 따른다. 애드온 코드·이전 생성 캐릭터는 불러오지 않았다.

첫 국소 수정에서 눈의 변화가 너무 작아 같은 해부학 제어의 scale/height2를 각각0.30/0.40에서1.0, 바깥 눈꼬리를0.35에서0.55로 조정했다. 첫 설정·편집 파일/빌드 결과·대표 렌더는 `initial_trial/`에 남겼다. 이는 유료 후보 재생성이 아니라 원인이 확인된 로컬 형태 수정이다. 코/입술 설정은 첫 수정과 같다. 수치는 원본 그림에서 추출한3D 정답이나 닮음 점수가 아니다.

## 확인 범위와 남은 차이

머리/목 피부4,311정점·4,286면과 눈 두 개 각72정점·70면을 그대로 유지했다. 피부2,626정점에 수정이 있고 합산 최대변위는 약4.942mm다. 제어 메시의 팬 삼각형에서 새 방향 반전0·0면적0을 확인했다. 이 검사는 자기 교차/전신 접합/리그 변형 검사가 아니다.

정면·양측면·사선과 기존55도 진단을 직접 확인했다. 눈 개구가 커지고 코 돌출/입술 볼륨이 줄었다. 해당 렌더에서 눈알 주변의 큰 틈은 보이지 않았으나 눈알 메시 자체는 바꾸지 않았고 수치적 접촉/변형 검사는 하지 않았다. 눈꺼풀 주름과 눈확·콧방울은 여전히 원화보다 사실적으로 읽힌다. 눈의 가로 윤곽/눈꼬리와 입선·턱 인상도 추가 조정이 필요하다. 홍채/눈썹·머리카락이 없다는 사실과 이 형태 차이를 구분한다. 색칠로 형태 결함을 가리는04 진입은 하지 않는다.

다음은 이 파일에서 눈꺼풀 경계와 주변 눈확을 국소 조절하고 콧방울/비주 밑면·닫힌 입선을 단순화하는03 작업이다. 정면의 성숙한 눈 인상과 양측면의 코/입/턱을 함께 확인하고 반대 시점에서 새로운 돌출/함몰이 없는지 본다. 전체 머리 재생성이나 이미 실패한 절차적 곡면 재사용은 하지 않는다. B-03-05 얼굴 프로듀서 판단 전이다.

## 재현·보존

저장소 루트에서 Blender4.3.2를 사용한다.

```bash
blender -b --python tools/higgsfield/requests/plan_b/b03/head_refinement_v1/refine_head.py -- inspect
blender -b --python tools/higgsfield/requests/plan_b/b03/head_refinement_v1/refine_head.py -- build
blender -b --python tools/higgsfield/requests/plan_b/b03/head_refinement_v1/refine_head.py -- verify
python tools/higgsfield/requests/plan_b/b03/head_refinement_v1/make_review.py
```

동일 설정은 Cycles32샘플/seed13·512×640·ORTHO0.335m·Standard·denoise off다. 독립 프로세스로 저장본의 모든 Shape Key 좌표/값/상대 기준·UV/원래 구조가 같은지 확인했으며 재렌더한RGBA 픽셀도 같았다. 원래 입력.blend와 첨부4장의SHA-256도 불변이다. 외부.blend 라이브러리/리그0이다. 첫 저장본의 독립 재개방은 이번 확인 범위가 아니며 현재 수정본만 확인했다.

이 폴더는 `.gdignore`로 게임 임포트에서 제외한다. 기존2D36클립363프레임·임시3D·실행 코드/전투/저장 규칙은 변경하지 않았다. 원화 형태/UV색·몸/의상/총기·리그·Godot 연결·Windows/S20+실기·최종 승인은 모두 미완료다. 전체완료1/8, 제작세션은 정식 자산 대기다.
