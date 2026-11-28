# 플랜B B-03-04 — R5 흰자·하단 경계톤 보완

2026-11-29 KST · 기획·아트 · 기준 원격 `b719dad51b89335f0635554c9de39c3831198aba`

현재 작업 파일은 **`viya_eye_surface.blend`**다. 입력 R5를 변경하지 않고 별도 파생물에 눈 색상 맵 두 장만 교체했다. `.gdignore`로 게임 임포트에서 제외한다. 국소 색 보완은 이후 얼굴 검수의 작업 기반으로 수용하며, **전체 얼굴 자체 검수·프로듀서 얼굴 수용은 전**이다. B-03 진행/전체완료1/8, 제작세션은 정식 자산 수령 대기다.

- [원화·전후](review/source_before_after.png)
- [눈 확대](review/eye_details.png) · [같은 세 시점 전후](review/paired_views.png)
- [여섯 시점](review/surface_views.png) · [무조명](review/unlit_views.png)
- [실제 원본 색 표본](review/source_patches.png)
- [판단·다음 작업](review_result.json) · [보존 검증](preservation_result.json)

## 관찰과 편집

이전 흰자 바탕은 sRGB(247,226,211)의 일정한 색이었다. 원본 정면의 보이는 밝은 영역을 직접 확인하고 좌우를 별도로 취했다. 왼쪽16개 원천 픽셀의 중앙값은(234.5,194,183.5), 오른쪽12개는(233.5,191,189)다. 작은 수동 영역 내 R>220/G>170/B>165 조건을 사용했다. 이는 그림의 색 관찰이며 물리적으로 보정된 흰자 알베도가 아니다. 오른쪽 바깥 어두운 영역은 홍채·머리카락/그림자와 구분이 모호해 흰자 바탕으로 쓰지 않았다.

각 눈의 하단 경계 원본색을 별도로 취해 최대18%의 완만한 하단 혼합을 작성했다. 이 혼합률/분포는 아트 작성값이다. 원본 그림의 그림자를 반대쪽/가려진 부위로 복사하지 않았다. 모델/원화의 좌우 반전도 없다. 실제 코드·표본 좌표·색·설정은 `paint_eye_maps.py`, `parameters.json`, `paint_result.json`에 있다.

눈별256² 맵에서 **기존 홍채2,028픽셀은 바이트 동일**하게 보호했고, 나머지63,508픽셀을 수정했다. 숨은 뒷면을 포함한 맵 전체 바탕 변경 수이며 보이는 흰자 픽셀 수가 아니다. 두 새 PNG 전체 해시는 달라진다. 홍채 위치/반경/UV·기하 경계는 유지했으며 색상 경계의 선형 보간 때문에 렌더 경계 대비는 달라질 수 있다. 13×13 원천 홍채에서 새 세부를 복원하지 않았다.

## 경계·홍채 노출 진단

색을 바꾸기 전 같은 R5 모델을 임시 오브젝트 색으로 구분해 밝은 하단 표본의 소유 표면을 확인했다. 정면3/사선3/반대 사선0개의 밝은 하단 표본 중 관측된6개는 눈 도움 메시였다. 소수의 보수적인 임계 표본이며 전체 경계가 모두 같은 원인이라는 증명이나 눈 접촉/교차 검사가 아니다. `visible_edge_diagnosis.json`과 `make_review.py`에 재현 규칙이 있다.

원래 홍채 UV 영역을 녹색, 흰자를 청색으로 렌더해 정면/양 사선에서 노출을 확인했다. 정면의 임계 분류 눈 표면은 왼쪽712/오른쪽713px, 그중 홍채334/335px다. 사선별 값은 `iris_exposure.json`에 있다. 혼합/AA 경계를 제외한 진단 수치이며 원화 닮음/보정된 노출 비율/합격 점수가 아니다. 원본의 가림과 투영이 다르므로 이 숫자로 홍채를 임의 이동·확대하지 않았다.

## 파일 보존·재현

| 항목 | SHA-256 / 결과 |
| --- | --- |
| 입력 `../eye_refinement_v1/viya_eye_refinement.blend` | `aaeb5e4e62ce36be76525d2e531d8effafbb13130af1e054293d752ddeca6fb1` / 불변 |
| 출력 `viya_eye_surface.blend` | `97b8a658207b0f27af355c32c37bfd645f57addaa8230770e657bdb92c4b6c05` |
| 기존 머리색1024² | `3642fabc7315233130d9017613856064b7b8bafb46b4d9054fa6d46a5c5261de` / 불변 |
| 새 화면왼쪽 눈256² | `8e668a8ef983b782ec13cbd3fabc36217066d3936d5f34dd7ce3b739db1d3016` |
| 새 화면오른쪽 눈256² | `5cc1264fae220bb2f18d088d44d6d1cd014a32234137172adfd72dd2ce8a1b6f` |

4,455정점/4,426면·평가 제어 좌표/모든 기존 키·R5/R4·코0.55·원본/별도UV는 입력 스냅샷과 동일하다. 머리색과 원본4장/이전 파일도 그대로다. 현재 모델은 사용 색 맵을 패킹하며 기존 눈 재질도 되돌릴 수 있게 보존했다. 전체 형상 보존은 새로운 접촉/교차·리그 합격을 뜻하지 않는다. 머리 표면 베이크/옛R4 위치 래스터 재사용은 하지 않았다.

Blender4.3.2/Cycles32샘플·seed13/512×640/정사영0.335m와 기존 검수 셰이더를 유지했다. 정면/양 사선·양측면/고각6장, 머리/양 눈 모두 무조명3장을 실제 렌더했다. 별도 프로세스 재개방의 모든 형상/키/UV·활성 패킹 이미지 해시, 이전 재질 유지와 사선 디코딩RGBA 동일을 확인했다. 외부.blend 의존/리그0이다.

저장소 루트에서 실행한다.

```sh
python tools/higgsfield/requests/plan_b/b03/eye_surface_v1/paint_eye_maps.py
blender -b -t 2 --python tools/higgsfield/requests/plan_b/b03/eye_surface_v1/tune_eye_surface.py -- diagnose
blender -b -t 2 --python tools/higgsfield/requests/plan_b/b03/eye_surface_v1/tune_eye_surface.py -- diagnose_iris
blender -b -t 2 --python tools/higgsfield/requests/plan_b/b03/eye_surface_v1/tune_eye_surface.py -- build
blender -b -t 2 --python tools/higgsfield/requests/plan_b/b03/eye_surface_v1/tune_eye_surface.py -- verify
python tools/higgsfield/requests/plan_b/b03/eye_surface_v1/make_review.py
```

Blender 재저장으로 모델 바이트는 달라질 수 있다. 위 해시는 이번 납품 바이트의 식별값이며 재생성 뒤에도 같다는 보장은 아니다.

## 판단과 다음

과하게 하얀 강조는 줄었으나 원화의 눈·눈썹 표정, 눈 세부, 입/턱의 전체 인상 차이는 남는다. 머리카락/가림은 미제작이며 전체 얼굴 닮음/프로듀서 승인을 통과한 것으로 세지 않는다.

다음 한 작업은 **B-03-04 전체 얼굴 자체 검수**다. 현재 파일과 원화 정면/양측면을 기존 카메라·무조명·표시 크기에서 대조해05 진입 가능 여부를 구체적으로 판단한다. 미통과면 원인 부위의03/04만 돌아간다. 미세한 색 보완을 근거 없이 반복하지 않고 전체 불합격점을 분리한다.05 승인 전 몸/총기/리그 추가·전체 머리 재생성·유료생성은 하지 않는다.

이번 유료 제출/차감0·잔액 재조회0·아트서비스 호출0이다. 새 유료 예산은 없다. 과거3건100/마지막 관측297은 현재 잔액이 아니다. 원본208/ARTFIX001/GAME064~076/SAVEFIX001·기존2D36클립363/임시3D·게임 코드/전투·저장 규칙은 변경하지 않았다. 게임 연결·실행/Windows/S20+실기·얼굴05/전체 외형07/최종B-08 승인은 수행하지 않았다.
